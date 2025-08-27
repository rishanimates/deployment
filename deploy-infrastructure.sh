#!/bin/bash

# ==============================================================================
# Fresh Infrastructure Deployment Script
# ==============================================================================
# This script completely removes old infrastructure and deploys fresh
# with proper database initialization and schema validation
# ==============================================================================

set -e

# --- Colors for logging ---
C_BLUE="\033[0;34m"
C_GREEN="\033[0;32m"
C_RED="\033[0;31m"
C_YELLOW="\033[0;33m"
C_PURPLE="\033[0;35m"
C_CYAN="\033[0;36m"
C_RESET="\033[0m"

# --- Configuration ---
DEPLOY_DIR="/opt/letzgo"
LOG_FILE="/opt/letzgo/logs/infrastructure-deployment.log"

# --- Helper Functions ---
log_info() {
    echo -e "${C_BLUE}[INFO] $1${C_RESET}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${C_GREEN}[SUCCESS] $1${C_RESET}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${C_YELLOW}[WARNING] $1${C_RESET}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${C_RED}[ERROR] $1${C_RESET}" | tee -a "$LOG_FILE"
    exit 1
}

# --- Clean Old Infrastructure ---
cleanup_old_infrastructure() {
    log_info "🗑️ Cleaning up old infrastructure..."
    
    # Stop and remove all containers
    cd "$DEPLOY_DIR" 2>/dev/null || true
    docker-compose -f docker-compose.prod.yml down --volumes --remove-orphans 2>/dev/null || true
    
    # Remove all letzgo containers
    docker ps -a | grep letzgo | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
    
    # Remove all letzgo images
    docker images | grep letzgo | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true
    
    # Remove all letzgo volumes
    docker volume ls | grep letzgo | awk '{print $2}' | xargs -r docker volume rm 2>/dev/null || true
    
    # Clean up networks
    docker network rm letzgo-network 2>/dev/null || true
    
    # Clean up directories
    rm -rf "$DEPLOY_DIR/logs/"* "$DEPLOY_DIR/uploads/"* 2>/dev/null || true
    
    log_success "✅ Old infrastructure cleaned"
}

# --- Setup Directories ---
setup_directories() {
    log_info "📁 Setting up deployment directories..."
    
    mkdir -p "$DEPLOY_DIR"
    mkdir -p "/opt/letzgo/logs"
    mkdir -p "/opt/letzgo/uploads"
    mkdir -p "/opt/letzgo/ssl"
    mkdir -p "/opt/letzgo/database"
    mkdir -p "/opt/letzgo/nginx/conf.d"
    
    # Set proper permissions for container access
    chown -R 1001:1001 "/opt/letzgo/logs" "/opt/letzgo/uploads"
    chmod -R 755 "/opt/letzgo/logs" "/opt/letzgo/uploads"
    
    # Create log file
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    log_success "✅ Directories configured"
}

# --- Generate Environment File ---
setup_environment_file() {
    log_info "🔧 Generating secure environment configuration..."
    
    cd "$DEPLOY_DIR"
    
    if [ ! -f "env.template" ]; then
        log_error "env.template not found in $DEPLOY_DIR"
    fi
    
    # Generate secure passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | head -c 32)
    MONGODB_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | head -c 32)
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | head -c 32)
    RABBITMQ_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | head -c 32)
    JWT_SECRET=$(openssl rand -base64 64 | tr -d '=+/' | head -c 64)
    SERVICE_API_KEY=$(openssl rand -hex 32)
    
    # Create .env file from template
    cp env.template .env
    
    # Replace placeholder values with generated secrets
    sed -i "s/your_secure_postgres_password_here/$POSTGRES_PASSWORD/g" .env
    sed -i "s/your_secure_mongodb_password_here/$MONGODB_PASSWORD/g" .env
    sed -i "s/your_secure_redis_password_here/$REDIS_PASSWORD/g" .env
    sed -i "s/your_secure_rabbitmq_password_here/$RABBITMQ_PASSWORD/g" .env
    sed -i "s/your_jwt_secret_key_here_at_least_32_characters_long/$JWT_SECRET/g" .env
    sed -i "s/your_service_api_key_here_at_least_32_characters_long/$SERVICE_API_KEY/g" .env
    
    # Fix database connection URLs and names
    sed -i "s/letzgo_db/letzgo/g" .env
    sed -i "s/letzgo-postgres/postgres/g" .env
    sed -i "s/letzgo-mongodb/mongodb/g" .env
    sed -i "s/letzgo-redis/redis/g" .env
    sed -i "s/letzgo-rabbitmq/rabbitmq/g" .env
    
    # Set proper permissions
    chmod 600 .env
    
    log_success "✅ Environment configuration generated with secure passwords"
}

# --- Create Docker Network ---
setup_docker_network() {
    log_info "🌐 Setting up Docker network..."
    
    # Remove existing network if it exists
    docker network rm letzgo-network 2>/dev/null || true
    
    # Create new network
    docker network create letzgo-network --driver bridge
    
    log_success "✅ Docker network 'letzgo-network' created"
}

# --- Deploy Database Infrastructure ---
deploy_database_infrastructure() {
    log_info "🏗️ Deploying database infrastructure..."
    
    cd "$DEPLOY_DIR"
    
    if [ ! -f "docker-compose.prod.yml" ]; then
        log_error "docker-compose.prod.yml not found in $DEPLOY_DIR"
    fi
    
    # Deploy only database services first
    log_info "Starting PostgreSQL with schema initialization..."
    docker-compose -f docker-compose.prod.yml up -d postgres
    
    log_info "Starting MongoDB with collection initialization..."
    docker-compose -f docker-compose.prod.yml up -d mongodb
    
    log_info "Starting Redis..."
    docker-compose -f docker-compose.prod.yml up -d redis
    
    log_info "Starting RabbitMQ..."
    docker-compose -f docker-compose.prod.yml up -d rabbitmq
    
    log_success "✅ Database infrastructure containers started"
}

# --- Wait for Database Health ---
wait_for_database_health() {
    log_info "⏳ Waiting for databases to become healthy..."
    
    cd "$DEPLOY_DIR"
    
    # Wait for PostgreSQL
    log_info "Checking PostgreSQL health..."
    for i in {1..60}; do
        if docker-compose -f docker-compose.prod.yml ps postgres | grep -q "healthy"; then
            log_success "✅ PostgreSQL is healthy"
            break
        fi
        if [ $i -eq 60 ]; then
            log_error "PostgreSQL failed to become healthy after 10 minutes"
        fi
        echo "Attempt $i/60 - PostgreSQL not ready yet, waiting 10 seconds..."
        sleep 10
    done
    
    # Wait for MongoDB
    log_info "Checking MongoDB health..."
    for i in {1..60}; do
        if docker-compose -f docker-compose.prod.yml ps mongodb | grep -q "healthy"; then
            log_success "✅ MongoDB is healthy"
            break
        fi
        if [ $i -eq 60 ]; then
            log_error "MongoDB failed to become healthy after 10 minutes"
        fi
        echo "Attempt $i/60 - MongoDB not ready yet, waiting 10 seconds..."
        sleep 10
    done
    
    # Wait for Redis
    log_info "Checking Redis health..."
    for i in {1..30}; do
        if docker-compose -f docker-compose.prod.yml ps redis | grep -q "healthy"; then
            log_success "✅ Redis is healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Redis failed to become healthy after 5 minutes"
        fi
        echo "Attempt $i/30 - Redis not ready yet, waiting 10 seconds..."
        sleep 10
    done
    
    # Wait for RabbitMQ
    log_info "Checking RabbitMQ health..."
    for i in {1..30}; do
        if docker-compose -f docker-compose.prod.yml ps rabbitmq | grep -q "healthy"; then
            log_success "✅ RabbitMQ is healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "RabbitMQ failed to become healthy after 5 minutes"
        fi
        echo "Attempt $i/30 - RabbitMQ not ready yet, waiting 10 seconds..."
        sleep 10
    done
    
    log_success "🎉 All database services are healthy!"
}

# --- Verify Database Schemas ---
verify_database_schemas() {
    log_info "🔍 Verifying database schemas..."
    
    cd "$DEPLOY_DIR"
    
    # Check PostgreSQL tables
    log_info "Checking PostgreSQL tables..."
    POSTGRES_TABLES=$(docker exec letzgo-postgres psql -U postgres -d letzgo -t -c "
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name IN ('users', 'groups', 'events', 'expenses', 'notifications', 'chat_rooms', 'chat_messages');
    " 2>/dev/null | xargs || echo "0")
    
    if [ "$POSTGRES_TABLES" -gt 0 ]; then
        log_success "✅ PostgreSQL tables created: $POSTGRES_TABLES tables found"
        
        # List the tables
        docker exec letzgo-postgres psql -U postgres -d letzgo -c "
            SELECT table_name FROM information_schema.tables 
            WHERE table_schema = 'public' 
            ORDER BY table_name;
        " 2>/dev/null || true
    else
        log_warning "⚠️ PostgreSQL tables not found - will be created on service startup"
    fi
    
    # Check MongoDB collections
    log_info "Checking MongoDB collections..."
    MONGODB_COLLECTIONS=$(docker exec letzgo-mongodb mongosh --quiet --eval "
        db.getSiblingDB('letzgo').getCollectionNames().length
    " 2>/dev/null || echo "0")
    
    if [ "$MONGODB_COLLECTIONS" -gt 0 ]; then
        log_success "✅ MongoDB collections created: $MONGODB_COLLECTIONS collections found"
        
        # List the collections
        docker exec letzgo-mongodb mongosh --quiet --eval "
            db.getSiblingDB('letzgo').getCollectionNames()
        " 2>/dev/null || true
    else
        log_warning "⚠️ MongoDB collections not found - will be created on service startup"
    fi
    
    log_success "✅ Database schema verification completed"
}

# --- Deploy Nginx ---
deploy_nginx() {
    log_info "🌐 Deploying Nginx API Gateway..."
    
    cd "$DEPLOY_DIR"
    
    # Deploy Nginx (it will wait for services via depends_on)
    docker-compose -f docker-compose.prod.yml up -d nginx
    
    # Wait for Nginx to be ready
    for i in {1..30}; do
        if docker-compose -f docker-compose.prod.yml ps nginx | grep -q "Up"; then
            log_success "✅ Nginx is running"
            break
        fi
        if [ $i -eq 30 ]; then
            log_warning "⚠️ Nginx may not be fully ready - services not deployed yet"
            break
        fi
        echo "Attempt $i/30 - Nginx not ready yet, waiting 5 seconds..."
        sleep 5
    done
}

# --- Infrastructure Status Check ---
infrastructure_status_check() {
    log_info "📊 Infrastructure Status Check..."
    
    cd "$DEPLOY_DIR"
    
    echo ""
    echo -e "${C_PURPLE}============================================================================${C_RESET}"
    echo -e "${C_PURPLE}🏗️ INFRASTRUCTURE DEPLOYMENT STATUS${C_RESET}"
    echo -e "${C_PURPLE}============================================================================${C_RESET}"
    echo ""
    
    echo -e "${C_CYAN}📊 Container Status:${C_RESET}"
    docker-compose -f docker-compose.prod.yml ps
    echo ""
    
    echo -e "${C_CYAN}🔍 Service Health Checks:${C_RESET}"
    for service in postgres mongodb redis rabbitmq nginx; do
        status=$(docker-compose -f docker-compose.prod.yml ps $service | grep -o 'healthy\|unhealthy\|Up' | head -1 || echo "Down")
        if [[ "$status" == "healthy" ]] || [[ "$status" == "Up" ]]; then
            echo -e "✅ $service: $status"
        else
            echo -e "❌ $service: $status"
        fi
    done
    echo ""
    
    echo -e "${C_CYAN}🗄️ Database Connectivity:${C_RESET}"
    docker exec letzgo-postgres pg_isready -U postgres -d letzgo >/dev/null 2>&1 && echo "✅ PostgreSQL ready" || echo "❌ PostgreSQL not ready"
    docker exec letzgo-mongodb mongosh --eval 'db.adminCommand("ping")' >/dev/null 2>&1 && echo "✅ MongoDB ready" || echo "❌ MongoDB not ready"
    docker exec letzgo-redis redis-cli ping >/dev/null 2>&1 && echo "✅ Redis ready" || echo "❌ Redis not ready"
    docker exec letzgo-rabbitmq rabbitmq-diagnostics ping >/dev/null 2>&1 && echo "✅ RabbitMQ ready" || echo "❌ RabbitMQ not ready"
    echo ""
    
    log_success "🎉 Infrastructure deployment completed successfully!"
    log_info "📋 Next step: Deploy services using deploy-services.yml workflow"
}

# --- Main Deployment Function ---
main() {
    echo ""
    echo -e "${C_PURPLE}============================================================================${C_RESET}"
    echo -e "${C_PURPLE}🚀 STARTING FRESH INFRASTRUCTURE DEPLOYMENT${C_RESET}"
    echo -e "${C_PURPLE}============================================================================${C_RESET}"
    echo ""
    
    # Execute deployment steps
    cleanup_old_infrastructure
    setup_directories
    setup_environment_file
    setup_docker_network
    deploy_database_infrastructure
    wait_for_database_health
    verify_database_schemas
    deploy_nginx
    infrastructure_status_check
    
    echo ""
    echo -e "${C_GREEN}🎉 Fresh infrastructure deployment completed successfully!${C_RESET}"
    echo -e "${C_CYAN}📱 Ready for service deployment and mobile app testing${C_RESET}"
    echo ""
}

# --- Error Handling ---
trap 'log_error "Infrastructure deployment failed at line $LINENO"' ERR

# --- Execution ---
main "$@"