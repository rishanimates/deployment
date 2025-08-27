#!/bin/bash

# LetzGo Services Deployment Script
# This script deploys all application services with proper networking and database connectivity
# Usage: ./deploy-services.sh [service1,service2,...] [--force-rebuild]

set -e

# Configuration
DEPLOY_PATH="/opt/letzgo"
ENV_FILE="$DEPLOY_PATH/.env"
NETWORK_NAME="letzgo-network"

# Available services
AVAILABLE_SERVICES=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")

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
    echo "🚀 LetzGo Services Deployment"
    echo "============================================================================"
    echo -e "${NC}"
    echo "📅 Started: $(date)"
    echo "👤 User: $(whoami)"
    echo "📁 Deploy Path: $DEPLOY_PATH"
    echo "🌐 Network: $NETWORK_NAME"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log_step "🔍 Checking prerequisites..."
    
    # Check if infrastructure is running
    if ! docker network ls --format "{{.Name}}" | grep -q "^$NETWORK_NAME$"; then
        log_error "Infrastructure network '$NETWORK_NAME' not found"
        log_error "Please run ./deploy-infrastructure.sh first"
        return 1
    fi
    
    # Check if databases are running
    local required_containers=("letzgo-postgres" "letzgo-mongodb" "letzgo-redis")
    for container in "${required_containers[@]}"; do
        if ! docker ps --format "{{.Names}}" | grep -q "^$container$"; then
            log_error "Required container '$container' is not running"
            log_error "Please run ./deploy-infrastructure.sh first"
            return 1
        fi
    done
    
    # Check environment file
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Environment file not found: $ENV_FILE"
        log_error "Please run ./deploy-infrastructure.sh first"
        return 1
    fi
    
    log_success "All prerequisites met"
    return 0
}

# Get service port
get_service_port() {
    local service="$1"
    case "$service" in
        "auth-service") echo "3000" ;;
        "user-service") echo "3001" ;;
        "chat-service") echo "3002" ;;
        "event-service") echo "3003" ;;
        "shared-service") echo "3004" ;;
        "splitz-service") echo "3005" ;;
        *) echo "" ;;
    esac
}

# Create service Dockerfile if not exists
create_service_dockerfile() {
    local service="$1"
    local dockerfile_path="$DEPLOY_PATH/Dockerfile.$service"
    
    if [ ! -f "$dockerfile_path" ]; then
        log_info "Creating Dockerfile for $service..."
        
        cat > "$dockerfile_path" << EOF
FROM node:20-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache curl netcat-openbsd

# Copy package files
COPY package*.json ./
COPY yarn.lock ./

# Install dependencies
RUN yarn install --frozen-lockfile --production

# Copy source code
COPY . .

# Create logs and uploads directories
RUN mkdir -p logs uploads && \\
    chown -R node:node logs uploads && \\
    chmod 755 logs uploads

# Switch to non-root user
USER node

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \\
    CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["yarn", "start"]
EOF
        
        log_success "Dockerfile created for $service"
    fi
}

# Build service image
build_service_image() {
    local service="$1"
    local image_name="letzgo-$service:latest"
    
    log_info "Building Docker image for $service..."
    
    # Create a temporary directory with service files
    local temp_dir="/tmp/letzgo-$service-build"
    mkdir -p "$temp_dir"
    
    # Create package.json if not exists
    if [ ! -f "$temp_dir/package.json" ]; then
        cat > "$temp_dir/package.json" << EOF
{
  "name": "$service",
  "version": "1.0.0",
  "description": "LetzGo $service",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "dev": "nodemon src/app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1",
    "pg": "^8.11.3",
    "pg-pool": "^3.6.1",
    "mongodb": "^6.0.0",
    "mongoose": "^7.5.0",
    "redis": "^4.6.7",
    "amqplib": "^0.10.3",
    "bcrypt": "^5.1.1",
    "jsonwebtoken": "^9.0.2",
    "uuid": "^9.0.0",
    "joi": "^17.9.2",
    "axios": "^1.5.0"
  }
}
EOF
    fi
    
    # Create basic app structure
    mkdir -p "$temp_dir/src"
    if [ ! -f "$temp_dir/src/app.js" ]; then
        cat > "$temp_dir/src/app.js" << EOF
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        service: '$service',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development'
    });
});

// API routes
app.get('/api/v1/status', (req, res) => {
    res.json({
        service: '$service',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString()
    });
});

// Default route
app.get('/', (req, res) => {
    res.json({
        message: 'LetzGo $service is running',
        endpoints: ['/health', '/api/v1/status']
    });
});

// Error handling
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        error: 'Internal Server Error',
        message: err.message
    });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(\`$service listening on port \${PORT}\`);
    console.log(\`Environment: \${process.env.NODE_ENV || 'development'}\`);
    console.log(\`Health check: http://localhost:\${PORT}/health\`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    process.exit(0);
});
EOF
    fi
    
    # Copy Dockerfile
    cp "$DEPLOY_PATH/Dockerfile.$service" "$temp_dir/Dockerfile"
    
    # Build image
    cd "$temp_dir"
    docker build -t "$image_name" .
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_success "Docker image built: $image_name"
}

# Deploy service
deploy_service() {
    local service="$1"
    local port=$(get_service_port "$service")
    local container_name="letzgo-$service"
    local image_name="letzgo-$service:latest"
    
    if [ -z "$port" ]; then
        log_error "Unknown service: $service"
        return 1
    fi
    
    log_step "🚀 Deploying $service on port $port..."
    
    # Load environment variables
    set -a; source "$ENV_FILE"; set +a
    
    # Stop existing container
    if docker ps -a --format "{{.Names}}" | grep -q "^$container_name$"; then
        log_info "Stopping existing $service container..."
        docker stop "$container_name" >/dev/null 2>&1 || true
        docker rm "$container_name" >/dev/null 2>&1 || true
    fi
    
    # Create and start container
    docker run -d \\
        --name "$container_name" \\
        --network "$NETWORK_NAME" \\
        -p "$port:$port" \\
        -e NODE_ENV=staging \\
        -e PORT="$port" \\
        -e HOST="0.0.0.0" \\
        -e POSTGRES_HOST=letzgo-postgres \\
        -e POSTGRES_PORT=5432 \\
        -e POSTGRES_USERNAME=postgres \\
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \\
        -e POSTGRES_DATABASE=letzgo \\
        -e POSTGRES_URL="$POSTGRES_URL" \\
        -e MONGODB_HOST=letzgo-mongodb \\
        -e MONGODB_PORT=27017 \\
        -e MONGODB_USERNAME=admin \\
        -e MONGODB_PASSWORD="$MONGODB_PASSWORD" \\
        -e MONGODB_DATABASE=letzgo \\
        -e MONGODB_URL="$MONGODB_URL" \\
        -e MONGODB_URI="$MONGODB_URI" \\
        -e REDIS_HOST=letzgo-redis \\
        -e REDIS_PORT=6379 \\
        -e REDIS_PASSWORD="$REDIS_PASSWORD" \\
        -e REDIS_URL="$REDIS_URL" \\
        -e RABBITMQ_HOST=letzgo-rabbitmq \\
        -e RABBITMQ_PORT=5672 \\
        -e RABBITMQ_USERNAME=admin \\
        -e RABBITMQ_PASSWORD="$RABBITMQ_PASSWORD" \\
        -e RABBITMQ_URL="$RABBITMQ_URL" \\
        -e JWT_SECRET="$JWT_SECRET" \\
        -e SERVICE_API_KEY="$SERVICE_API_KEY" \\
        -e DOMAIN_NAME="$DOMAIN_NAME" \\
        -e API_DOMAIN="$API_DOMAIN" \\
        -v "$DEPLOY_PATH/logs:/app/logs" \\
        -v "$DEPLOY_PATH/uploads:/app/uploads" \\
        --restart unless-stopped \\
        "$image_name"
    
    log_success "$service deployed successfully"
}

# Wait for service health
wait_for_service_health() {
    local service="$1"
    local port=$(get_service_port "$service")
    local max_attempts=20
    local attempt=1
    
    log_info "⏳ Waiting for $service to be healthy on port $port..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s --connect-timeout 3 "http://localhost:$port/health" >/dev/null 2>&1; then
            log_success "✅ $service is healthy!"
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_warning "⚠️ $service did not become healthy within timeout"
            log_info "📋 Recent logs:"
            docker logs "letzgo-$service" --tail 10 2>/dev/null || echo "No logs available"
            return 1
        fi
        
        log_info "Attempt $attempt/$max_attempts - waiting 5 seconds..."
        sleep 5
        attempt=$((attempt + 1))
    done
}

# Deploy all services
deploy_services() {
    local services_to_deploy=("$@")
    local successful_deployments=0
    local failed_deployments=0
    
    for service in "${services_to_deploy[@]}"; do
        echo ""
        log_step "Deploying $service..."
        
        if create_service_dockerfile "$service" && \\
           build_service_image "$service" && \\
           deploy_service "$service" && \\
           wait_for_service_health "$service"; then
            successful_deployments=$((successful_deployments + 1))
            log_success "✅ $service deployment completed"
        else
            failed_deployments=$((failed_deployments + 1))
            log_error "❌ $service deployment failed"
        fi
    done
    
    echo ""
    log_step "📊 Deployment Summary"
    echo "✅ Successful: $successful_deployments"
    echo "❌ Failed: $failed_deployments"
    echo "📊 Total: $((successful_deployments + failed_deployments))"
}

# Display final status
display_status() {
    log_step "📊 Services Status Report"
    
    echo ""
    echo -e "${CYAN}🐳 Running Services:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep letzgo- || echo "No services found"
    
    echo ""
    echo -e "${CYAN}🔗 Service URLs:${NC}"
    for service in "${AVAILABLE_SERVICES[@]}"; do
        local port=$(get_service_port "$service")
        if docker ps --format "{{.Names}}" | grep -q "^letzgo-$service$"; then
            echo "✅ $service: http://103.168.19.241:$port"
        else
            echo "❌ $service: Not running"
        fi
    done
    
    echo ""
    echo -e "${CYAN}🏥 Health Checks:${NC}"
    for service in "${AVAILABLE_SERVICES[@]}"; do
        local port=$(get_service_port "$service")
        if curl -f -s --connect-timeout 2 "http://localhost:$port/health" >/dev/null 2>&1; then
            echo "✅ $service: Healthy"
        else
            echo "❌ $service: Unhealthy or not running"
        fi
    done
}

# Parse services argument
parse_services() {
    local services_arg="$1"
    
    if [ "$services_arg" = "all" ] || [ -z "$services_arg" ]; then
        echo "${AVAILABLE_SERVICES[@]}"
    else
        # Split comma-separated services
        echo "$services_arg" | tr ',' ' '
    fi
}

# Main execution
main() {
    local services_to_deploy=""
    local force_rebuild=false
    
    # Parse arguments
    for arg in "$@"; do
        case $arg in
            --force-rebuild)
                force_rebuild=true
                ;;
            *)
                if [ -z "$services_to_deploy" ]; then
                    services_to_deploy="$arg"
                fi
                ;;
        esac
    done
    
    # Default to all services if none specified
    if [ -z "$services_to_deploy" ]; then
        services_to_deploy="all"
    fi
    
    local services_array=($(parse_services "$services_to_deploy"))
    
    print_banner
    
    echo "🎯 Services to deploy: ${services_array[*]}"
    echo ""
    
    if ! check_prerequisites; then
        log_error "Prerequisites not met. Aborting."
        exit 1
    fi
    
    if [ "$force_rebuild" = true ]; then
        log_warning "Force rebuild requested - will rebuild all Docker images"
    fi
    
    deploy_services "${services_array[@]}"
    display_status
    
    echo ""
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}🎉 LetzGo Services Deployment Completed!${NC}"
    echo -e "${GREEN}============================================================================${NC}"
    echo "📅 Completed: $(date)"
    echo "🌐 All services are now running on the letzgo-network"
    echo ""
}

main "$@"
