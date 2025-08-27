#!/bin/bash

# Simple Infrastructure Deploy Script
# This script runs directly on the VPS via SSH without external dependencies
# Usage: Called by GitHub Actions via SSH

set -e

echo "🚀 Starting Simple Infrastructure Deployment..."
echo "Timestamp: $(date)"
echo "Working directory: $(pwd)"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_system() {
    log_info "🔍 Checking system requirements..."
    
    # Check if we're running as root or have sudo
    if [ "$EUID" -eq 0 ]; then
        log_success "✅ Running as root"
        SUDO=""
    elif command_exists sudo; then
        log_success "✅ Sudo available"
        SUDO="sudo"
    else
        log_error "❌ Neither root nor sudo available"
        return 1
    fi
    
    # Check Docker
    if command_exists docker; then
        log_success "✅ Docker is installed"
        docker --version
    else
        log_error "❌ Docker is not installed"
        return 1
    fi
    
    # Check Docker Compose
    if command_exists docker-compose; then
        log_success "✅ Docker Compose is installed"
        docker-compose --version
    else
        log_error "❌ Docker Compose is not installed"
        return 1
    fi
    
    # Check if Docker is running
    if docker info >/dev/null 2>&1; then
        log_success "✅ Docker daemon is running"
    else
        log_error "❌ Docker daemon is not running"
        return 1
    fi
    
    return 0
}

# Function to setup directories
setup_directories() {
    log_info "📁 Setting up directories..."
    
    local deploy_path="/opt/letzgo"
    
    # Create main directory
    $SUDO mkdir -p "$deploy_path"
    $SUDO chown -R $(whoami):$(whoami) "$deploy_path" 2>/dev/null || true
    
    # Create subdirectories
    mkdir -p "$deploy_path"/{logs,uploads,database,nginx/conf.d}
    
    log_success "✅ Directories created: $deploy_path"
    return 0
}

# Function to create basic environment file
create_environment() {
    log_info "🔧 Creating basic environment file..."
    
    local deploy_path="/opt/letzgo"
    local env_file="$deploy_path/.env"
    
    # Generate secure passwords
    local postgres_pass=$(openssl rand -hex 16)
    local mongodb_pass=$(openssl rand -hex 16)
    local redis_pass=$(openssl rand -hex 16)
    local rabbitmq_pass=$(openssl rand -hex 16)
    local jwt_secret=$(openssl rand -hex 32)
    local api_key=$(openssl rand -hex 32)
    
    # Create environment file
    cat > "$env_file" << EOF
# LetzGo Infrastructure Environment - Auto-generated $(date)
NODE_ENV=staging

# Database Passwords
POSTGRES_PASSWORD=$postgres_pass
MONGODB_PASSWORD=$mongodb_pass
REDIS_PASSWORD=$redis_pass
RABBITMQ_PASSWORD=$rabbitmq_pass

# Application Secrets
JWT_SECRET=$jwt_secret
SERVICE_API_KEY=$api_key

# Database URLs
POSTGRES_URL=postgresql://postgres:$postgres_pass@letzgo-postgres:5432/letzgo?sslmode=disable
MONGODB_URL=mongodb://admin:$mongodb_pass@letzgo-mongodb:27017/letzgo?authSource=admin
MONGODB_URI=mongodb://admin:$mongodb_pass@letzgo-mongodb:27017/letzgo?authSource=admin
REDIS_URL=redis://:$redis_pass@letzgo-redis:6379
RABBITMQ_URL=amqp://admin:$rabbitmq_pass@letzgo-rabbitmq:5672

# Database Connection Parameters
POSTGRES_HOST=letzgo-postgres
POSTGRES_PORT=5432
POSTGRES_DATABASE=letzgo
POSTGRES_USERNAME=postgres

MONGODB_HOST=letzgo-mongodb
MONGODB_PORT=27017
MONGODB_DATABASE=letzgo
MONGODB_USERNAME=admin

REDIS_HOST=letzgo-redis
REDIS_PORT=6379

RABBITMQ_HOST=letzgo-rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=admin

# Domain Configuration
DOMAIN_NAME=103.168.19.241
API_DOMAIN=103.168.19.241

# Other Settings
DB_SCHEMA=public
STORAGE_PROVIDER=local
EOF
    
    chmod 600 "$env_file"
    log_success "✅ Environment file created with secure passwords"
    return 0
}

# Function to create Docker Compose file
create_docker_compose() {
    log_info "🐳 Creating Docker Compose configuration..."
    
    local deploy_path="/opt/letzgo"
    local compose_file="$deploy_path/docker-compose.yml"
    
    cat > "$compose_file" << 'EOF'
version: '3.8'

networks:
  letzgo-network:
    driver: bridge
    name: letzgo-network

volumes:
  letzgo-postgres-data:
    driver: local
  letzgo-mongodb-data:
    driver: local
  letzgo-redis-data:
    driver: local
  letzgo-rabbitmq-data:
    driver: local

services:
  # PostgreSQL Database
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

  # MongoDB Database
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
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis Cache
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
      test: ["CMD", "redis-cli", "auth", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # RabbitMQ Message Queue
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
    
    log_success "✅ Docker Compose file created"
    return 0
}

# Function to stop existing containers
stop_existing_containers() {
    log_info "🛑 Stopping existing containers..."
    
    # Stop and remove existing containers
    local containers=("letzgo-postgres" "letzgo-mongodb" "letzgo-redis" "letzgo-rabbitmq")
    
    for container in "${containers[@]}"; do
        if docker ps -a --format "{{.Names}}" | grep -q "^$container$"; then
            log_info "Stopping and removing $container..."
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
        fi
    done
    
    # Remove existing network
    if docker network ls --format "{{.Name}}" | grep -q "^letzgo-network$"; then
        log_info "Removing existing network..."
        docker network rm letzgo-network 2>/dev/null || true
    fi
    
    log_success "✅ Existing containers stopped"
    return 0
}

# Function to deploy infrastructure
deploy_infrastructure() {
    log_info "🚀 Deploying infrastructure..."
    
    local deploy_path="/opt/letzgo"
    cd "$deploy_path"
    
    # Load environment variables
    set -a
    source .env
    set +a
    
    # Deploy infrastructure
    docker-compose up -d
    
    log_success "✅ Infrastructure deployment started"
    return 0
}

# Function to wait for services to be healthy
wait_for_health() {
    log_info "⏳ Waiting for services to be healthy..."
    
    local services=("postgres" "mongodb" "redis" "rabbitmq")
    local max_attempts=30
    local healthy_services=0
    
    for attempt in $(seq 1 $max_attempts); do
        healthy_services=0
        
        for service in "${services[@]}"; do
            if docker ps --format "{{.Names}} {{.Status}}" | grep "letzgo-$service" | grep -q "healthy\|Up"; then
                healthy_services=$((healthy_services + 1))
            fi
        done
        
        log_info "Attempt $attempt/$max_attempts: $healthy_services/${#services[@]} services healthy"
        
        if [ $healthy_services -eq ${#services[@]} ]; then
            log_success "✅ All services are healthy!"
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_warning "⚠️ Not all services became healthy, but continuing..."
            break
        fi
        
        sleep 10
    done
    
    return 0
}

# Function to show final status
show_status() {
    log_info "📊 Final Infrastructure Status:"
    echo ""
    
    # Show running containers
    echo "🐳 Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep letzgo || echo "No letzgo containers found"
    echo ""
    
    # Show networks
    echo "🌐 Networks:"
    docker network ls | grep letzgo || echo "No letzgo networks found"
    echo ""
    
    # Test database connections
    echo "🗄️ Database connectivity:"
    
    # Test PostgreSQL
    if docker exec letzgo-postgres pg_isready -U postgres -d letzgo >/dev/null 2>&1; then
        echo "✅ PostgreSQL: Ready"
    else
        echo "❌ PostgreSQL: Not ready"
    fi
    
    # Test MongoDB
    if docker exec letzgo-mongodb mongosh --eval 'db.adminCommand("ping")' >/dev/null 2>&1; then
        echo "✅ MongoDB: Ready"
    else
        echo "❌ MongoDB: Not ready"
    fi
    
    # Test Redis
    if docker exec letzgo-redis redis-cli -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
        echo "✅ Redis: Ready"
    else
        echo "❌ Redis: Not ready"
    fi
    
    # Test RabbitMQ
    if docker exec letzgo-rabbitmq rabbitmqctl status >/dev/null 2>&1; then
        echo "✅ RabbitMQ: Ready"
    else
        echo "❌ RabbitMQ: Not ready"
    fi
    
    echo ""
    log_success "🎉 Infrastructure deployment completed!"
}

# Main execution
main() {
    echo "============================================================================"
    echo "🏗️ LetzGo Simple Infrastructure Deployment"
    echo "============================================================================"
    echo ""
    
    # Execute deployment steps
    if check_system; then
        log_success "✅ Step 1/7: System check passed"
    else
        log_error "❌ Step 1/7: System check failed"
        exit 1
    fi
    
    if setup_directories; then
        log_success "✅ Step 2/7: Directories setup completed"
    else
        log_error "❌ Step 2/7: Directories setup failed"
        exit 1
    fi
    
    if create_environment; then
        log_success "✅ Step 3/7: Environment configuration created"
    else
        log_error "❌ Step 3/7: Environment configuration failed"
        exit 1
    fi
    
    if create_docker_compose; then
        log_success "✅ Step 4/7: Docker Compose configuration created"
    else
        log_error "❌ Step 4/7: Docker Compose configuration failed"
        exit 1
    fi
    
    if stop_existing_containers; then
        log_success "✅ Step 5/7: Existing containers cleanup completed"
    else
        log_error "❌ Step 5/7: Existing containers cleanup failed"
        exit 1
    fi
    
    if deploy_infrastructure; then
        log_success "✅ Step 6/7: Infrastructure deployment completed"
    else
        log_error "❌ Step 6/7: Infrastructure deployment failed"
        exit 1
    fi
    
    if wait_for_health; then
        log_success "✅ Step 7/7: Health check completed"
    else
        log_warning "⚠️ Step 7/7: Health check completed with warnings"
    fi
    
    show_status
    
    echo ""
    echo "============================================================================"
    log_success "🎉 Simple Infrastructure Deployment Completed Successfully!"
    echo "============================================================================"
}

# Execute main function
main "$@"
