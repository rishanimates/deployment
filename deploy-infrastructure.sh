#!/bin/bash

# LetzGo Infrastructure Deployment Script
# This script deploys all databases and installs required schemas
# Usage: ./deploy-infrastructure.sh [--force-rebuild]

set -e

# Configuration
DEPLOY_PATH="/opt/letzgo"
COMPOSE_FILE="$DEPLOY_PATH/docker-compose.infrastructure.yml"
ENV_FILE="$DEPLOY_PATH/.env"

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

# Generate secure environment
generate_environment() {
    log_step "🔐 Generating secure environment configuration..."
    
    local postgres_pass=$(openssl rand -hex 20)
    local mongodb_pass=$(openssl rand -hex 20)
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

# Other Settings
DB_SCHEMA=public
STORAGE_PROVIDER=local
EOF
    
    chmod 600 "$ENV_FILE"
    log_success "Environment configuration generated"
}

# Create database schemas - will be continued in next message due to length
create_database_schemas() {
    log_step "📊 Creating database schemas..."
    
    # PostgreSQL schema
    cat > "$DEPLOY_PATH/database/init/01-init-postgres.sql" << 'EOF'
-- LetzGo PostgreSQL Database Initialization
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "timescaledb" CASCADE;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    bio TEXT,
    avatar_url VARCHAR(500),
    birth_date DATE,
    is_email_verified BOOLEAN DEFAULT FALSE,
    is_phone_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Groups table
CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    avatar_url VARCHAR(500),
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Group memberships
CREATE TABLE IF NOT EXISTS group_memberships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, group_id)
);

-- Events table
CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    location VARCHAR(500),
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    created_by UUID REFERENCES users(id),
    group_id UUID REFERENCES groups(id),
    max_participants INTEGER,
    is_public BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Event participants
CREATE TABLE IF NOT EXISTS event_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'going',
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(event_id, user_id)
);

-- Expenses table
CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',
    paid_by UUID REFERENCES users(id),
    group_id UUID REFERENCES groups(id),
    event_id UUID REFERENCES events(id),
    category VARCHAR(50),
    receipt_url VARCHAR(500),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Expense splits
CREATE TABLE IF NOT EXISTS expense_splits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    expense_id UUID REFERENCES expenses(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    is_paid BOOLEAN DEFAULT FALSE,
    paid_at TIMESTAMPTZ,
    UNIQUE(expense_id, user_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_group_memberships_user_id ON group_memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_events_created_by ON events(created_by);
CREATE INDEX IF NOT EXISTS idx_expenses_paid_by ON expenses(paid_by);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;
EOF

    # MongoDB schema
    cat > "$DEPLOY_PATH/database/init/01-init-mongodb.js" << 'EOF'
// LetzGo MongoDB Database Initialization
print('🚀 Starting LetzGo MongoDB initialization...');

db = db.getSiblingDB('letzgo');

// Chat rooms collection
db.createCollection('chat_rooms', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['name', 'type', 'created_by', 'created_at'],
      properties: {
        name: { bsonType: 'string', maxLength: 100 },
        type: { enum: ['group', 'event', 'direct'] },
        description: { bsonType: 'string', maxLength: 500 },
        participants: { bsonType: 'array', items: { bsonType: 'string' } },
        created_by: { bsonType: 'string' },
        created_at: { bsonType: 'date' }
      }
    }
  }
});

// Expenses collection
db.createCollection('expenses', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['title', 'amount', 'currency', 'paid_by', 'group_id', 'created_at'],
      properties: {
        title: { bsonType: 'string', maxLength: 200 },
        amount: { bsonType: 'number', minimum: 0 },
        currency: { bsonType: 'string', pattern: '^[A-Z]{3}$' },
        paid_by: { bsonType: 'string' },
        group_id: { bsonType: 'string' },
        created_at: { bsonType: 'date' }
      }
    }
  }
});

// Create indexes
db.chat_rooms.createIndex({ 'created_at': -1 });
db.expenses.createIndex({ 'group_id': 1, 'created_at': -1 });

print('✅ LetzGo MongoDB initialization completed!');
EOF

    log_success "Database schemas created"
}

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
      - ./database/init:/docker-entrypoint-initdb.d:ro
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
      - ./database/init:/docker-entrypoint-initdb.d:ro
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
    generate_environment
    create_database_schemas
    create_docker_compose
    
    if [ "$force_rebuild" = true ]; then
        cleanup_existing
    fi
    
    deploy_infrastructure
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
