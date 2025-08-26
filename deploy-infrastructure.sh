#!/bin/bash

# ==============================================================================
# LetzGo Infrastructure Deployment Script
# Deploys only databases and messaging services (no Node.js applications)
# ==============================================================================

set -e

# --- Colors for logging ---
C_BLUE="\033[0;34m"
C_GREEN="\033[0;32m"g
C_RED="\033[0;31m"
C_YELLOW="\033[0;33m"
C_RESET="\033[0m"

# --- Configuration ---
DEPLOY_DIR="/opt/letzgo"
BACKUP_DIR="/opt/letzgo/backups"
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

# --- Create necessary directories ---
setup_directories() {
    log_info "Setting up infrastructure directories..."
    
    mkdir -p "$DEPLOY_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "/opt/letzgo/logs"
    mkdir -p "/opt/letzgo/uploads"
    mkdir -p "/opt/letzgo/ssl"
    mkdir -p "/opt/letzgo/config"
    mkdir -p "/opt/letzgo/schemas"
    
    # Set proper permissions for container access (non-root user 1001:1001)
    log_info "Setting container permissions for logs and uploads..."
    chown -R 1001:1001 "/opt/letzgo/logs" "/opt/letzgo/uploads" 2>/dev/null || true
    chmod -R 755 "/opt/letzgo/logs" "/opt/letzgo/uploads" 2>/dev/null || true
    
    log_success "Directories created successfully with proper container permissions"
}

# --- Setup environment file ---
setup_environment_file() {
    log_info "Setting up environment file..."
    
    if [ -f "/opt/letzgo/.env" ]; then
        log_info "Environment file already exists"
        return 0
    fi
    
    if [ ! -f "env.template" ]; then
        log_error "env.template not found. Please ensure it's included in the deployment package."
        return 1
    fi
    
    log_info "Creating .env file from template with generated passwords..."
    
    # Generate secure passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    MONGODB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    RABBITMQ_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    JWT_SECRET=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-32)
    SERVICE_API_KEY=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-32)
    
    # Create .env file with generated values
    cat > /opt/letzgo/.env << EOF
# ==============================================================================
# LetzGo Staging Environment Configuration
# ==============================================================================
# Auto-generated on $(date)

# --- Environment ---
NODE_ENV=staging

# --- Database Passwords ---
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
MONGODB_PASSWORD=$MONGODB_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD

# --- Application Secrets ---
JWT_SECRET=$JWT_SECRET
SERVICE_API_KEY=$SERVICE_API_KEY

# --- Payment Gateway (Razorpay) ---
RAZORPAY_KEY_ID=rzp_test_your_key_id_here
RAZORPAY_KEY_SECRET=your_razorpay_key_secret_here

# --- Storage Configuration ---
STORAGE_PROVIDER=local

# --- Domain Configuration ---
DOMAIN_NAME=103.168.19.241
API_DOMAIN=103.168.19.241

# --- Database Connection URLs ---
POSTGRES_URL=postgresql://postgres:$POSTGRES_PASSWORD@letzgo-postgres:5432/letzgo_db
MONGODB_URL=mongodb://admin:$MONGODB_PASSWORD@letzgo-mongodb:27017/letzgo_db?authSource=admin
MONGODB_URI=mongodb://admin:$MONGODB_PASSWORD@letzgo-mongodb:27017/letzgo_db?authSource=admin
REDIS_URL=redis://:$REDIS_PASSWORD@letzgo-redis:6379
RABBITMQ_URL=amqp://admin:$RABBITMQ_PASSWORD@letzgo-rabbitmq:5672

# --- Individual Database Connection Parameters ---
# MongoDB
MONGODB_HOST=letzgo-mongodb
MONGODB_PORT=27017
MONGODB_DATABASE=letzgo_db
MONGODB_USERNAME=admin

# Redis  
REDIS_HOST=letzgo-redis
REDIS_PORT=6379

# PostgreSQL
POSTGRES_HOST=letzgo-postgres
POSTGRES_PORT=5432
POSTGRES_DATABASE=letzgo_db
POSTGRES_USERNAME=postgres

# RabbitMQ
RABBITMQ_HOST=letzgo-rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=admin

# --- Service Ports ---
AUTH_SERVICE_PORT=3000
USER_SERVICE_PORT=3001
CHAT_SERVICE_PORT=3002
EVENT_SERVICE_PORT=3003
SHARED_SERVICE_PORT=3004
SPLITZ_SERVICE_PORT=3005

# --- External Service URLs ---
AUTH_SERVICE_URL=http://letzgo-auth-service:3000
USER_SERVICE_URL=http://letzgo-user-service:3001
CHAT_SERVICE_URL=http://letzgo-chat-service:3002
EVENT_SERVICE_URL=http://letzgo-event-service:3003
SHARED_SERVICE_URL=http://letzgo-shared-service:3004
SPLITZ_SERVICE_URL=http://letzgo-splitz-service:3005
EOF
    
    # Set secure permissions
    chmod 600 /opt/letzgo/.env
    
    log_success "Environment file created successfully"
    log_info "Generated passwords: PostgreSQL, MongoDB, Redis, RabbitMQ, JWT Secret, API Key"
}

# --- Backup current infrastructure ---
backup_current_infrastructure() {
    log_info "Creating backup of current infrastructure..."
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_PATH="$BACKUP_DIR/infrastructure_backup_$TIMESTAMP"
    
    if [ -f "$DEPLOY_DIR/docker-compose.yml" ] || [ -f "$DEPLOY_DIR/docker-compose.prod.yml" ]; then
        mkdir -p "$BACKUP_PATH"
        cp "$DEPLOY_DIR"/*.yml "$BACKUP_PATH/" 2>/dev/null || true
        cp "$DEPLOY_DIR/.env" "$BACKUP_PATH/" 2>/dev/null || true
        cp -r "$DEPLOY_DIR/nginx" "$BACKUP_PATH/" 2>/dev/null || true
        log_success "Infrastructure backup created at $BACKUP_PATH"
    else
        log_warning "No existing infrastructure found to backup"
    fi
    
    # Keep only last 5 backups
    cd "$BACKUP_DIR"
    ls -t | grep "infrastructure_backup" | tail -n +6 | xargs -r rm -rf
}

# --- Stop running infrastructure ---
stop_infrastructure() {
    log_info "Stopping running infrastructure..."
    
    cd "$DEPLOY_DIR"
    
    # Stop production infrastructure if it exists
    if [ -f "docker-compose.prod.yml" ]; then
        docker-compose -f docker-compose.prod.yml down || true
        log_success "Production infrastructure stopped"
    fi
    
    # Stop development infrastructure if it exists
    if [ -f "docker-compose.yml" ]; then
        docker-compose -f docker-compose.yml down || true
        log_success "Development infrastructure stopped"
    fi
    
    # Stop infrastructure-only compose if it exists
    if [ -f "docker-compose.infrastructure.yml" ]; then
        docker-compose -f docker-compose.infrastructure.yml down || true
        log_success "Infrastructure-only services stopped"
    fi
    
    # Remove any orphaned containers
    docker container prune -f || true
}

# --- Clean up conflicting services ---
cleanup_conflicting_services() {
    log_info "Cleaning up conflicting services..."
    
    # Run port cleanup if script exists
    if [ -f "$DEPLOY_DIR/cleanup-ports.sh" ]; then
        log_info "Running port cleanup script..."
        bash "$DEPLOY_DIR/cleanup-ports.sh" || true
    else
        # Basic cleanup if script doesn't exist
        log_info "Stopping any containers using required ports..."
        
        # Stop containers using our ports
        docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "5432|27017|6379|5672" | awk '{print $1}' | grep -v NAMES | xargs -r docker stop || true
        
        # Kill processes using ports
        for port in 5432 27017 6379 5672 15672; do
            lsof -ti:$port 2>/dev/null | xargs -r kill -9 2>/dev/null || true
        done
    fi
    
    log_success "Conflicting services cleanup completed"
}

# --- Load environment variables ---
load_environment() {
    log_info "Loading environment variables..."
    
    if [ -f "$DEPLOY_DIR/.env" ]; then
        set -a
        source "$DEPLOY_DIR/.env"
        set +a
        log_success "Environment variables loaded"
    else
        log_error "Environment file not found at $DEPLOY_DIR/.env"
    fi
}

# --- Pull latest Docker images ---
pull_images() {
    log_info "Pulling latest infrastructure Docker images..."
    
    docker pull timescale/timescaledb-ha:pg14-latest
    docker pull mongo:6.0
    docker pull redis:7.2-alpine
    docker pull rabbitmq:3-management-alpine
    docker pull nginx:alpine
    
    log_success "Infrastructure Docker images pulled"
}

# --- Create infrastructure-only docker-compose ---
create_infrastructure_compose() {
    log_info "Creating infrastructure-only docker-compose..."
    
    cat > "$DEPLOY_DIR/docker-compose.infrastructure.yml" << 'EOF'
version: '3.8'

networks:
  letzgo-network:
    driver: bridge

services:
  # ===========================================================================
  # Databases
  # ===========================================================================
  postgres:
    image: timescale/timescaledb-ha:pg14-latest
    container_name: letzgo-postgres
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - TIMESCALEDB_TELEMETRY=off
    volumes:
      - letzgo-postgres-data:/var/lib/postgresql/data
      - ./00-init-dbs.sh:/docker-entrypoint-initdb.d/00-init-dbs.sh
      - ./schemas/user-schema.sql:/docker-entrypoint-initdb.d/01-user-schema.sql:ro
      - ./schemas/user-stories.sql:/docker-entrypoint-initdb.d/01b-user-stories.sql:ro
      - ./schemas/event-schema.sql:/docker-entrypoint-initdb.d/02-event-schema.sql:ro
      - ./02-create-hypertable.sql:/docker-entrypoint-initdb.d/03-create-hypertable.sql
    networks:
      - letzgo-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  mongodb:
    image: mongo:6.0
    container_name: letzgo-mongodb
    ports:
      - "27017:27017"
    environment:
      - MONGO_INITDB_ROOT_USERNAME=admin
      - MONGO_INITDB_ROOT_PASSWORD=${MONGODB_PASSWORD}
    volumes:
      - letzgo-mongodb-data:/data/db
    networks:
      - letzgo-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7.2-alpine
    container_name: letzgo-redis
    ports:
      - "6379:6379"
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - letzgo-redis-data:/data
    networks:
      - letzgo-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: letzgo-rabbitmq
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      - RABBITMQ_DEFAULT_USER=admin
      - RABBITMQ_DEFAULT_PASS=${RABBITMQ_PASSWORD}
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

volumes:
  letzgo-postgres-data:
    driver: local
  letzgo-mongodb-data:
    driver: local
  letzgo-redis-data:
    driver: local
  letzgo-rabbitmq-data:
    driver: local
EOF
    
    log_success "Infrastructure docker-compose created"
}

# --- Start infrastructure services ---
start_infrastructure() {
    log_info "Starting infrastructure services..."
    
    cd "$DEPLOY_DIR"
    docker-compose -f docker-compose.infrastructure.yml up -d
    
    log_success "Infrastructure services started"
}

# --- Wait for services to be healthy ---
wait_for_infrastructure() {
    log_info "Waiting for infrastructure services to be healthy..."
    
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Health check attempt $attempt/$max_attempts"
        
        # Check if all infrastructure services are healthy
        unhealthy_services=$(docker-compose -f "$DEPLOY_DIR/docker-compose.infrastructure.yml" ps | grep "unhealthy\|starting" || true)
        
        if [ -z "$unhealthy_services" ]; then
            log_success "All infrastructure services are healthy"
            return 0
        else
            log_info "Infrastructure services still starting... waiting 10 seconds"
            
            # Show current status for debugging
            if [ $attempt -eq 1 ] || [ $((attempt % 10)) -eq 0 ]; then
                log_info "Current service status:"
                docker-compose -f "$DEPLOY_DIR/docker-compose.infrastructure.yml" ps || true
            fi
            
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    # Final status check before failing
    log_error "Infrastructure services failed to become healthy within timeout"
    log_info "Final service status:"
    docker-compose -f "$DEPLOY_DIR/docker-compose.infrastructure.yml" ps || true
    
    log_info "Container logs for debugging:"
    docker-compose -f "$DEPLOY_DIR/docker-compose.infrastructure.yml" logs --tail=20 || true
    
    return 1
}

# --- Initialize databases ---
initialize_databases() {
    log_info "Initializing databases..."
    
    # Wait a bit more for PostgreSQL to be fully ready
    sleep 10
    
    # Test PostgreSQL connection
    if docker exec letzgo-postgres psql -U postgres -d letzgo_db -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "PostgreSQL database initialized successfully"
    else
        log_warning "PostgreSQL database may not be fully initialized yet"
    fi
    
    # Test MongoDB connection
    if docker exec letzgo-mongodb mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        log_success "MongoDB database initialized successfully"
    else
        log_warning "MongoDB database may not be fully initialized yet"
    fi
    
    # Test Redis connection
    if docker exec letzgo-redis redis-cli ping > /dev/null 2>&1; then
        log_success "Redis cache initialized successfully"
    else
        log_warning "Redis cache may not be fully initialized yet"
    fi
    
    log_success "Database initialization completed"
}

# --- Verify infrastructure deployment ---
verify_infrastructure() {
    log_info "Verifying infrastructure deployment..."
    
    local services=("letzgo-postgres:5432" "letzgo-mongodb:27017" "letzgo-redis:6379" "letzgo-rabbitmq:5672")
    local healthy_services=0
    
    for service in "${services[@]}"; do
        local name=$(echo $service | cut -d: -f1)
        local port=$(echo $service | cut -d: -f2)
        
        if docker ps | grep -q "$name"; then
            log_success "$name is running"
            healthy_services=$((healthy_services + 1))
        else
            log_warning "$name is not running"
        fi
    done
    
    # Show infrastructure status
    echo -e "\n${C_YELLOW}Infrastructure Status:${C_RESET}"
    docker-compose -f "$DEPLOY_DIR/docker-compose.infrastructure.yml" ps
    
    if [ $healthy_services -ge 3 ]; then
        log_success "Infrastructure verification passed"
    else
        log_error "Infrastructure verification failed - not enough services are running"
    fi
}

# --- Cleanup ---
cleanup() {
    log_info "Cleaning up..."
    
    # Remove unused Docker images
    docker image prune -f
    
    log_success "Cleanup completed"
}

# --- Main deployment function ---
main() {
    echo -e "${C_BLUE}===================================================${C_RESET}"
    echo -e "${C_BLUE}    LetzGo Infrastructure Deployment${C_RESET}"
    echo -e "${C_BLUE}===================================================${C_RESET}"
    
    log_info "Starting infrastructure deployment at $(date)"
    
    setup_directories
    setup_environment_file
    backup_current_infrastructure
    stop_infrastructure
    cleanup_conflicting_services
    load_environment
    pull_images
    create_infrastructure_compose
    start_infrastructure
    wait_for_infrastructure
    initialize_databases
    verify_infrastructure
    cleanup
    
    log_success "Infrastructure deployment completed successfully at $(date)"
    
    echo -e "\n${C_GREEN}===================================================${C_RESET}"
    echo -e "${C_GREEN}    Infrastructure Deployment Summary${C_RESET}"
    echo -e "${C_GREEN}===================================================${C_RESET}"
    echo -e "${C_GREEN}✅ Database services deployed and running${C_RESET}"
    echo -e "${C_GREEN}✅ PostgreSQL: localhost:5432${C_RESET}"
    echo -e "${C_GREEN}✅ MongoDB: localhost:27017${C_RESET}"
    echo -e "${C_GREEN}✅ Redis: localhost:6379${C_RESET}"
    echo -e "${C_GREEN}✅ RabbitMQ: localhost:5672 (Management: 15672)${C_RESET}"
    echo -e "${C_GREEN}✅ Logs: $LOG_FILE${C_RESET}"
    echo -e "${C_YELLOW}📝 Next: Deploy individual Node.js services${C_RESET}"
    echo -e "${C_GREEN}===================================================${C_RESET}"
}

# Execute main function
main "$@"
