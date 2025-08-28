#!/bin/bash

# LetzGo Infrastructure Deployment Script
# This script deploys all databases and installs required schemas
# Usage: ./deploy-infrastructure.sh [--force-rebuild]

set -e

# Configuration
DEPLOY_PATH="/opt/letzgo"
COMPOSE_FILE="$DEPLOY_PATH/docker-compose.infrastructure.yml"
ENV_FILE="$DEPLOY_PATH/.env.staging"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }

# Print banner
print_banner() {
    echo -e "${CYAN}"
    echo "============================================================================"
    echo "🏗️  LetzGo Infrastructure Deployment"
    echo "============================================================================"
    echo -e "${NC}"
    echo "📅 Started: $(date)"
    echo "👤 User: $(whoami)"
    echo "📁 Deploy Path: $DEPLOY_PATH"
    echo ""
}

# Check system requirements
check_requirements() {
    log_step "🔍 Checking system requirements..."
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed"
        return 1
    elif ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        return 1
    else
        log_info "✅ Docker: $(docker --version | cut -d' ' -f3)"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "Docker Compose is not installed"
        return 1
    else
        log_info "✅ Docker Compose: $(docker-compose --version | cut -d' ' -f3)"
    fi
    
    log_success "All system requirements met"
    return 0
}

# Setup directories
setup_directories() {
    log_step "📁 Setting up directory structure..."
    
    sudo mkdir -p "$DEPLOY_PATH"
    sudo chown -R $(whoami):$(whoami) "$DEPLOY_PATH" 2>/dev/null || true
    mkdir -p "$DEPLOY_PATH"/{logs,uploads,database/init,nginx/conf.d,ssl}
    chmod -R 755 "$DEPLOY_PATH"
    
    log_success "Directory structure created"
}

# Open firewall ports if UFW is available
open_firewall_ports() {
    log_step "🔥 Configuring firewall for external access (if UFW available)..."

    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow 5432/tcp >/dev/null 2>&1 || true  # PostgreSQL
        # Optional: open others if needed externally
        # sudo ufw allow 27017/tcp >/dev/null 2>&1 || true # MongoDB
        # sudo ufw allow 6379/tcp  >/dev/null 2>&1 || true # Redis
        # sudo ufw allow 15672/tcp >/dev/null 2>&1 || true # RabbitMQ UI
        log_success "UFW rules updated for PostgreSQL (5432)"
    else
        log_warning "UFW not installed; skipping firewall configuration"
    fi
}

# Generate secure environment
generate_environment() {
    log_step "🔐 Generating secure environment configuration..."
    
    # Preserve existing secrets if env file already exists
    local existing_postgres_pass=""
    local existing_mongodb_pass=""
    if [ -f "$ENV_FILE" ]; then
        existing_postgres_pass=$(grep -E '^POSTGRES_PASSWORD=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r')
        existing_mongodb_pass=$(grep -E '^MONGODB_PASSWORD=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r')
    fi

    local postgres_pass=${existing_postgres_pass:-$(openssl rand -hex 20)}
    local mongodb_pass=${existing_mongodb_pass:-$(openssl rand -hex 20)}
    local redis_pass=$(openssl rand -hex 20)
    local rabbitmq_pass=$(openssl rand -hex 20)
    local jwt_secret=$(openssl rand -hex 32)
    local service_api_key=$(openssl rand -hex 32)
    
    cat > "$ENV_FILE" << EOF
# LetzGo Infrastructure Environment - Auto-generated $(date)
NODE_ENV=staging
ENVIRONMENT=staging

# Database Passwords
POSTGRES_PASSWORD=$postgres_pass
MONGODB_PASSWORD=$mongodb_pass
REDIS_PASSWORD=$redis_pass
RABBITMQ_PASSWORD=$rabbitmq_pass

# Application Secrets
JWT_SECRET=$jwt_secret
SERVICE_API_KEY=$service_api_key

# PostgreSQL Configuration
POSTGRES_HOST=letzgo-postgres
POSTGRES_PORT=5432
POSTGRES_USERNAME=postgres
POSTGRES_DATABASE=letzgo
POSTGRES_URL=postgresql://postgres:$postgres_pass@letzgo-postgres:5432/letzgo?sslmode=disable

# MongoDB Configuration
MONGODB_HOST=letzgo-mongodb
MONGODB_PORT=27017
MONGODB_USERNAME=admin
MONGODB_DATABASE=letzgo
MONGODB_URL=mongodb://admin:$mongodb_pass@letzgo-mongodb:27017/letzgo?authSource=admin
MONGODB_URI=mongodb://admin:$mongodb_pass@letzgo-mongodb:27017/letzgo?authSource=admin

# Event Service (Mongo) - for plugin/lifecycle data
EVENTS_MONGODB_DATABASE=letzgo_events
EVENTS_MONGODB_URI=mongodb://admin:$mongodb_pass@letzgo-mongodb:27017/letzgo_events?authSource=admin

# Redis Configuration
REDIS_HOST=letzgo-redis
REDIS_PORT=6379
REDIS_URL=redis://:$redis_pass@letzgo-redis:6379

# RabbitMQ Configuration
RABBITMQ_HOST=letzgo-rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=admin
RABBITMQ_URL=amqp://admin:$rabbitmq_pass@letzgo-rabbitmq:5672

# Domain Configuration
DOMAIN_NAME=103.168.19.241
API_DOMAIN=103.168.19.241

# Service Ports
AUTH_SERVICE_PORT=3000
USER_SERVICE_PORT=3001
CHAT_SERVICE_PORT=3002
EVENT_SERVICE_PORT=3003
SHARED_SERVICE_PORT=3004
SPLITZ_SERVICE_PORT=3005

# Service URLs (for inter-service communication)
AUTH_SERVICE_URL=http://letzgo-auth-service:3000
USER_SERVICE_URL=http://letzgo-user-service:3001
CHAT_SERVICE_URL=http://letzgo-chat-service:3002
EVENT_SERVICE_URL=http://letzgo-event-service:3003
SHARED_SERVICE_URL=http://letzgo-shared-service:3004
SPLITZ_SERVICE_URL=http://letzgo-splitz-service:3005

# External Service URLs (for external access)
AUTH_SERVICE_EXTERNAL_URL=http://103.168.19.241:3000
USER_SERVICE_EXTERNAL_URL=http://103.168.19.241:3001
CHAT_SERVICE_EXTERNAL_URL=http://103.168.19.241:3002
EVENT_SERVICE_EXTERNAL_URL=http://103.168.19.241:3003
SHARED_SERVICE_EXTERNAL_URL=http://103.168.19.241:3004
SPLITZ_SERVICE_EXTERNAL_URL=http://103.168.19.241:3005

# CORS Configuration
CORS_ORIGIN=http://103.168.19.241:*,http://localhost:*

# Other Settings
STORAGE_PROVIDER=local

# Docker Network
DOCKER_NETWORK=letzgo-network
EOF
    
    chmod 600 "$ENV_FILE"
    log_success "Environment configuration generated"
}

## Skipping database schema creation here.
## Each service will own its schema and migrate on startup.

# Create Docker Compose configuration
create_docker_compose() {
    log_step "🐳 Creating Docker Compose configuration..."
    
    cat > "$COMPOSE_FILE" << 'EOF'
version: '3.8'

networks:
  letzgo-network:
    driver: bridge
    name: letzgo-network

volumes:
  letzgo-postgres-data:
  letzgo-mongodb-data:
  letzgo-redis-data:
  letzgo-rabbitmq-data:

services:
  postgres:
    image: timescale/timescaledb:latest-pg14
    container_name: letzgo-postgres
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=letzgo
      - TIMESCALEDB_TELEMETRY=off
    ports:
      - "5432:5432"
    volumes:
      - letzgo-postgres-data:/var/lib/postgresql/data
    networks:
      - letzgo-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d letzgo"]
      interval: 10s
      timeout: 5s
      retries: 5

  mongodb:
    image: mongo:6.0
    container_name: letzgo-mongodb
    environment:
      - MONGO_INITDB_ROOT_USERNAME=admin
      - MONGO_INITDB_ROOT_PASSWORD=${MONGODB_PASSWORD}
      - MONGO_INITDB_DATABASE=letzgo
    ports:
      - "27017:27017"
    volumes:
      - letzgo-mongodb-data:/data/db
    networks:
      - letzgo-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mongosh", "--quiet", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: letzgo-redis
    command: redis-server --requirepass ${REDIS_PASSWORD}
    ports:
      - "6379:6379"
    volumes:
      - letzgo-redis-data:/data
    networks:
      - letzgo-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "--no-auth-warning", "auth", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: letzgo-rabbitmq
    environment:
      - RABBITMQ_DEFAULT_USER=admin
      - RABBITMQ_DEFAULT_PASS=${RABBITMQ_PASSWORD}
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - letzgo-rabbitmq-data:/var/lib/rabbitmq
    networks:
      - letzgo-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
EOF

    log_success "Docker Compose configuration created"
}

# Cleanup existing infrastructure
cleanup_existing() {
    log_step "🧹 Cleaning up existing infrastructure..."
    
    local containers=("letzgo-postgres" "letzgo-mongodb" "letzgo-redis" "letzgo-rabbitmq")
    
    for container in "${containers[@]}"; do
        if docker ps -a --format "{{.Names}}" | grep -q "^$container$"; then
            log_info "Stopping and removing $container..."
            docker stop "$container" >/dev/null 2>&1 || true
            docker rm "$container" >/dev/null 2>&1 || true
        fi
    done
    
    if docker network ls --format "{{.Name}}" | grep -q "^letzgo-network$"; then
        log_info "Removing existing network..."
        docker network rm letzgo-network >/dev/null 2>&1 || true
    fi
    
    log_success "Cleanup completed"
}

# Deploy infrastructure
deploy_infrastructure() {
    log_step "🚀 Deploying infrastructure services..."
    
    cd "$DEPLOY_PATH"
    set -a; source "$ENV_FILE"; set +a
    docker-compose -f "$COMPOSE_FILE" up -d
    
    log_success "Infrastructure deployment initiated"
}

# Wait for services to be healthy
wait_for_health() {
    log_step "⏳ Waiting for services to become healthy..."
    
    local services=("postgres" "mongodb" "redis" "rabbitmq")
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local healthy_count=0
        local ready_count=0
        
        for service in "${services[@]}"; do
            local container_name="letzgo-$service"
            
            # Check if container is running
            if docker ps --format "{{.Names}}" | grep -q "^$container_name$"; then
                healthy_count=$((healthy_count + 1))
                
                # Check if service is actually ready
                case $service in
                    "postgres")
                        if docker exec $container_name pg_isready -U postgres >/dev/null 2>&1; then
                            ready_count=$((ready_count + 1))
                        fi
                        ;;
                    "mongodb")
                        if docker exec $container_name mongosh --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
                            ready_count=$((ready_count + 1))
                        fi
                        ;;
                    "redis")
                        if docker exec $container_name redis-cli --no-auth-warning -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
                            ready_count=$((ready_count + 1))
                        fi
                        ;;
                    "rabbitmq")
                        if docker exec $container_name rabbitmqctl node_health_check >/dev/null 2>&1; then
                            ready_count=$((ready_count + 1))
                        fi
                        ;;
                esac
            fi
        done
        
        log_info "Attempt $attempt/$max_attempts: $healthy_count/${#services[@]} running, $ready_count/${#services[@]} ready"
        
        if [ $ready_count -eq ${#services[@]} ]; then
            log_success "All services are running and ready!"
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_warning "Not all services became ready within timeout"
            log_info "Running services: $healthy_count/${#services[@]}"
            log_info "Ready services: $ready_count/${#services[@]}"
            break
        fi
        
        sleep 5
        attempt=$((attempt + 1))
    done
    
    return 0
}

# Align MongoDB admin user/password with .env.staging (idempotent)
align_mongodb_credentials() {
    log_step "🔐 Ensuring MongoDB admin credentials match environment..."

    set -a; source "$ENV_FILE"; set +a
    local user="${MONGODB_USERNAME:-admin}"
    local pass="$MONGODB_PASSWORD"

    if [ -z "$user" ] || [ -z "$pass" ]; then
        log_warning "Mongo credentials not found in env; skipping alignment"
        return 0
    fi

    # Determine mongo shell
    local MS
    if docker exec letzgo-mongodb sh -lc 'command -v mongosh >/dev/null 2>&1'; then
        MS=mongosh
    else
        MS=mongo
    fi

    # Try authenticating with desired credentials
    if docker exec letzgo-mongodb sh -lc "$MS --authenticationDatabase admin -u '$user' -p '$pass' --quiet --eval \"db.adminCommand('ping')\"" >/dev/null 2>&1; then
        log_success "MongoDB admin credentials already aligned"
        return 0
    fi

    log_warning "MongoDB admin auth failed; performing safe password alignment"

    # Get data volume/source for /data/db
    # Prefer named volume for /data/db to avoid host-path differences
    local VOL
    VOL=$(docker inspect -f '{{ range .Mounts }}{{ if eq .Destination "/data/db" }}{{ .Name }}{{ end }}{{ end }}' letzgo-mongodb 2>/dev/null || true)

    # Stop main Mongo container
    docker stop letzgo-mongodb >/dev/null 2>&1 || true

    # Start a temporary no-auth mongod on the same data and update/create user
    docker run --rm -d --name mongo-noauth -v "$VOL":/data/db -p 27019:27017 mongo:6 \
        mongod --dbpath /data/db --bind_ip_all --port 27017 --noauth >/dev/null

    # Use mongosh if present else mongo
    local MS2
    if docker exec mongo-noauth sh -lc 'command -v mongosh >/dev/null 2>&1'; then
        MS2=mongosh
    else
        MS2=mongo
    fi

    # Update or create admin user idempotently
    docker exec mongo-noauth sh -lc "$MS2 --quiet --eval \"try{db.getSiblingDB('admin').updateUser('$user',{pwd:'$pass'});print('UPDATED')}catch(e){db.getSiblingDB('admin').createUser({user:'$user',pwd:'$pass',roles:[{role:'root',db:'admin'}]});print('CREATED')}\"" >/dev/null 2>&1 || true

    # Stop temp and restart main
    docker stop mongo-noauth >/dev/null 2>&1 || true
    docker start letzgo-mongodb >/dev/null 2>&1 || true

    # Re-test authentication with retries to allow startup
    local ok=0
    for i in {1..10}; do
        if docker exec letzgo-mongodb sh -lc "$MS --authenticationDatabase admin -u '$user' -p '$pass' --quiet --eval \"db.adminCommand('ping')\"" >/dev/null 2>&1; then
            ok=1; break
        fi
        sleep 2
    done
    if [ "$ok" -eq 1 ]; then
        log_success "✅ MongoDB admin credentials aligned successfully"
    else
        log_warning "⚠️  MongoDB credentials alignment attempted but verification failed after retries"
    fi
}

# Verify database connectivity
verify_databases() {
    log_step "🔍 Verifying database connectivity..."
    
    # Test PostgreSQL
    if docker exec letzgo-postgres pg_isready -U postgres -d letzgo >/dev/null 2>&1; then
        log_success "✅ PostgreSQL: Connected and ready"
    else
        log_error "❌ PostgreSQL: Connection failed"
    fi
    
    # Test MongoDB
    if docker exec letzgo-mongodb mongosh --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
        log_success "✅ MongoDB: Connected and ready"
    else
        log_error "❌ MongoDB: Connection failed"
    fi
    
    # Test Redis
    if docker exec letzgo-redis redis-cli --no-auth-warning -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
        log_success "✅ Redis: Connected and ready"
    else
        log_error "❌ Redis: Connection failed"
    fi
    
    # Test RabbitMQ
    if docker exec letzgo-rabbitmq rabbitmqctl status >/dev/null 2>&1; then
        log_success "✅ RabbitMQ: Connected and ready"
    else
        log_error "❌ RabbitMQ: Connection failed"
    fi
}

# Display final status
display_status() {
    log_step "📊 Infrastructure Status Report"
    
    echo ""
    echo -e "${CYAN}🐳 Container Status:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep letzgo || echo "No containers found"
    
    echo ""
    echo -e "${CYAN}🔗 Service URLs:${NC}"
    echo "PostgreSQL: postgresql://postgres:***@103.168.19.241:5432/letzgo"
    echo "MongoDB: mongodb://admin:***@103.168.19.241:27017/letzgo"
    echo "Redis: redis://:***@103.168.19.241:6379"
    echo "RabbitMQ Management: http://103.168.19.241:15672"
    
    echo ""
    echo -e "${CYAN}📁 Files Created:${NC}"
    echo "Environment: $ENV_FILE"
    echo "Docker Compose: $COMPOSE_FILE"
}

# Main execution
main() {
    local force_rebuild=false
    
    for arg in "$@"; do
        case $arg in
            --force-rebuild) force_rebuild=true ;;
        esac
    done
    
    print_banner
    
    if ! check_requirements; then
        log_error "System requirements not met. Aborting."
        exit 1
    fi
    
    setup_directories
    open_firewall_ports
    generate_environment
    create_docker_compose
    
    if [ "$force_rebuild" = true ]; then
        cleanup_existing
    fi
    
    deploy_infrastructure
    # Align Mongo credentials before waiting on health to avoid restart loops
    align_mongodb_credentials
    wait_for_health
    verify_databases
    display_status
    
    echo ""
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}🎉 LetzGo Infrastructure Deployment Completed Successfully!${NC}"
    echo -e "${GREEN}============================================================================${NC}"
    echo "📅 Completed: $(date)"
    echo "⏱️  Next Step: Run ./deploy-services.sh to deploy application services"
    echo ""
}

main "$@"
