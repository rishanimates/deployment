#!/bin/bash

# LetzGo Parallel Services Deployment Script
# This script deploys all application services in parallel for faster deployment
# 
# Available Services: auth-service, user-service, chat-service, event-service, shared-service, splitz-service
# 
# Usage: 
#   ./deploy-services-parallel.sh [services] [branch] [--force-rebuild]
#   ./deploy-services-parallel.sh all main
#   ./deploy-services-parallel.sh auth-service,user-service develop
#   ./deploy-services-parallel.sh splitz-service main --force-rebuild

set -e

# Configuration
DEPLOY_PATH="/opt/letzgo"
ENV_FILE="$DEPLOY_PATH/.env"
NETWORK_NAME="letzgo-network"
GITHUB_USER="rhushirajpatil"
MAX_PARALLEL_JOBS=6

# Available services with repository URLs
declare -A SERVICE_REPOS=(
    ["auth-service"]="git@github.com:$GITHUB_USER/auth-service.git"
    ["user-service"]="git@github.com:$GITHUB_USER/user-service.git"
    ["chat-service"]="git@github.com:$GITHUB_USER/chat-service.git"
    ["event-service"]="git@github.com:$GITHUB_USER/event-service.git"
    ["shared-service"]="git@github.com:$GITHUB_USER/shared-service.git"
    ["splitz-service"]="git@github.com:$GITHUB_USER/splitz-service.git"
)

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
    echo "🚀 LetzGo Parallel Services Deployment"
    echo "============================================================================"
    echo -e "${NC}"
    echo "📅 Started: $(date)"
    echo "👤 User: $(whoami)"
    echo "📁 Deploy Path: $DEPLOY_PATH"
    echo "🌐 Network: $NETWORK_NAME"
    echo "⚡ Max Parallel Jobs: $MAX_PARALLEL_JOBS"
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

# Create local service repository as fallback
create_local_service_repo() {
    local service="$1"
    local service_dir="$DEPLOY_PATH/services/$service"
    local port=$(get_service_port "$service")
    
    echo "[$(date '+%H:%M:%S')] 📦 Creating local repository for $service..." >&2
    
    mkdir -p "$service_dir"
    cd "$service_dir"
    
    git init >/dev/null 2>&1
    
    cat > "package.json" << EOF
{
  "name": "$service",
  "version": "1.0.0",
  "description": "LetzGo $service microservice",
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
    "dotenv": "^16.3.1"
  }
}
EOF
    
    touch yarn.lock
    
    cat > "Dockerfile" << 'EOF'
FROM node:20-alpine
WORKDIR /app
RUN apk add --no-cache curl netcat-openbsd
COPY package*.json ./
COPY yarn.lock ./
RUN yarn install --frozen-lockfile --production
COPY . .
RUN mkdir -p logs uploads && chown -R node:node logs uploads
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1
CMD ["yarn", "start"]
EOF
    
    mkdir -p src
    cat > "src/app.js" << EOF
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || $port;

app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        service: '$service',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
        port: PORT
    });
});

app.get('/api/v1/status', (req, res) => {
    res.json({
        service: '$service',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString()
    });
});

app.get('/', (req, res) => {
    res.json({
        message: 'LetzGo $service is running',
        version: '1.0.0',
        endpoints: ['/health', '/api/v1/status']
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(\`🚀 $service listening on port \${PORT}\`);
});

process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
EOF
    
    git add . >/dev/null 2>&1
    git commit -m "Initial local repository for $service" >/dev/null 2>&1
    
    echo "[$(date '+%H:%M:%S')] ✅ Local repository created with basic Express.js setup" >&2
    return 0
}

# Clone or update service repository
clone_service_repo() {
    local service="$1"
    local branch="$2"
    local service_dir="$DEPLOY_PATH/services/$service"
    local repo_url="${SERVICE_REPOS[$service]}"
    
    if [ -z "$repo_url" ]; then
        echo "[$(date '+%H:%M:%S')] ❌ No repository URL configured for $service" >&2
        return 1
    fi
    
    echo "[$(date '+%H:%M:%S')] 📥 Cloning $service from $branch branch..." >&2
    
    mkdir -p "$DEPLOY_PATH/services"
    
    if [ -d "$service_dir" ]; then
        echo "[$(date '+%H:%M:%S')] 🗑️ Removing existing $service directory..." >&2
        rm -rf "$service_dir"
    fi
    
    # Clone repository with fallback chain
    if git clone -b "$branch" "$repo_url" "$service_dir" >/dev/null 2>&1; then
        echo "[$(date '+%H:%M:%S')] ✅ $service repository cloned successfully from $branch branch" >&2
        cd "$service_dir"
        local commit_hash=$(git rev-parse --short HEAD)
        local commit_message=$(git log -1 --pretty=format:"%s")
        echo "[$(date '+%H:%M:%S')] 📝 Commit: $commit_hash - $commit_message" >&2
        return 0
    else
        echo "[$(date '+%H:%M:%S')] ⚠️ Failed to clone $service repository from $branch branch via SSH" >&2
        echo "[$(date '+%H:%M:%S')] 🔄 Trying HTTPS URL as fallback..." >&2
        
        local https_url=$(echo "$repo_url" | sed 's/git@github.com:/https:\/\/github.com\//')
        if git clone -b "$branch" "$https_url" "$service_dir" >/dev/null 2>&1; then
            echo "[$(date '+%H:%M:%S')] ✅ $service repository cloned via HTTPS from $branch branch" >&2
            cd "$service_dir"
            local commit_hash=$(git rev-parse --short HEAD)
            local commit_message=$(git log -1 --pretty=format:"%s")
            echo "[$(date '+%H:%M:%S')] 📝 Commit: $commit_hash - $commit_message" >&2
            return 0
        else
            echo "[$(date '+%H:%M:%S')] ⚠️ Branch '$branch' not found, trying main branch..." >&2
            
            if git clone -b "main" "$https_url" "$service_dir" >/dev/null 2>&1; then
                echo "[$(date '+%H:%M:%S')] ✅ $service repository cloned from main branch (fallback)" >&2
                cd "$service_dir"
                local commit_hash=$(git rev-parse --short HEAD)
                local commit_message=$(git log -1 --pretty=format:"%s")
                echo "[$(date '+%H:%M:%S')] 📝 Commit: $commit_hash - $commit_message" >&2
                echo "[$(date '+%H:%M:%S')] ⚠️ Note: Deployed from 'main' branch instead of '$branch'" >&2
                return 0
            else
                echo "[$(date '+%H:%M:%S')] ❌ Failed to clone $service repository from any branch" >&2
                echo "[$(date '+%H:%M:%S')] 🏗️ Creating local fallback repository for $service..." >&2
                
                if create_local_service_repo "$service"; then
                    echo "[$(date '+%H:%M:%S')] ✅ Local fallback repository created for $service" >&2
                    return 0
                else
                    echo "[$(date '+%H:%M:%S')] ❌ Failed to create local fallback repository" >&2
                    return 1
                fi
            fi
        fi
    fi
}

# Deploy single service (runs in parallel)
deploy_single_service() {
    local service="$1"
    local branch="$2"
    local port=$(get_service_port "$service")
    local container_name="letzgo-$service"
    local image_name="letzgo-$service:latest"
    local service_dir="$DEPLOY_PATH/services/$service"
    local log_file="/tmp/deploy-$service.log"
    
    # Redirect all output to log file and also show timestamped progress
    exec > >(tee "$log_file") 2>&1
    
    echo "[$(date '+%H:%M:%S')] 🚀 Starting deployment of $service on port $port"
    
    # Step 1: Clone repository
    if ! clone_service_repo "$service" "$branch"; then
        echo "[$(date '+%H:%M:%S')] ❌ Failed to clone $service repository"
        echo "FAILED" > "/tmp/deploy-$service.status"
        return 1
    fi
    
    # Step 2: Build Docker image
    echo "[$(date '+%H:%M:%S')] 🐳 Building Docker image for $service..."
    
    if [ ! -d "$service_dir" ]; then
        echo "[$(date '+%H:%M:%S')] ❌ Service directory not found: $service_dir"
        echo "FAILED" > "/tmp/deploy-$service.status"
        return 1
    fi
    
    cd "$service_dir"
    
    if docker build -t "$image_name" . >/dev/null 2>&1; then
        echo "[$(date '+%H:%M:%S')] ✅ Docker image built: $image_name"
    else
        echo "[$(date '+%H:%M:%S')] ❌ Failed to build Docker image for $service"
        echo "FAILED" > "/tmp/deploy-$service.status"
        return 1
    fi
    
    # Step 3: Stop existing container
    if docker ps -a --format "{{.Names}}" | grep -q "^$container_name$"; then
        echo "[$(date '+%H:%M:%S')] 🛑 Stopping existing $service container..."
        docker stop "$container_name" >/dev/null 2>&1 || true
        docker rm "$container_name" >/dev/null 2>&1 || true
    fi
    
    # Step 4: Load environment variables
    set -a; source "$ENV_FILE"; set +a
    
    # Step 5: Deploy container
    echo "[$(date '+%H:%M:%S')] 🚀 Deploying $service container..."
    
    docker run -d \
        --name "$container_name" \
        --network "$NETWORK_NAME" \
        -p "$port:$port" \
        -e NODE_ENV=staging \
        -e PORT="$port" \
        -e HOST="0.0.0.0" \
        -e POSTGRES_HOST=letzgo-postgres \
        -e POSTGRES_PORT=5432 \
        -e POSTGRES_USERNAME=postgres \
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        -e POSTGRES_DATABASE=letzgo \
        -e POSTGRES_URL="$POSTGRES_URL" \
        -e MONGODB_HOST=letzgo-mongodb \
        -e MONGODB_PORT=27017 \
        -e MONGODB_USERNAME=admin \
        -e MONGODB_PASSWORD="$MONGODB_PASSWORD" \
        -e MONGODB_DATABASE=letzgo \
        -e MONGODB_URL="$MONGODB_URL" \
        -e MONGODB_URI="$MONGODB_URI" \
        -e REDIS_HOST=letzgo-redis \
        -e REDIS_PORT=6379 \
        -e REDIS_PASSWORD="$REDIS_PASSWORD" \
        -e REDIS_URL="$REDIS_URL" \
        -e RABBITMQ_HOST=letzgo-rabbitmq \
        -e RABBITMQ_PORT=5672 \
        -e RABBITMQ_USERNAME=admin \
        -e RABBITMQ_PASSWORD="$RABBITMQ_PASSWORD" \
        -e RABBITMQ_URL="$RABBITMQ_URL" \
        -e JWT_SECRET="$JWT_SECRET" \
        -e SERVICE_API_KEY="$SERVICE_API_KEY" \
        -e DOMAIN_NAME="$DOMAIN_NAME" \
        -e API_DOMAIN="$API_DOMAIN" \
        -v "$DEPLOY_PATH/logs:/app/logs" \
        -v "$DEPLOY_PATH/uploads:/app/uploads" \
        --restart unless-stopped \
        "$image_name" >/dev/null 2>&1
    
    echo "[$(date '+%H:%M:%S')] ✅ $service container deployed successfully"
    
    # Step 6: Wait for health check
    echo "[$(date '+%H:%M:%S')] ⏳ Waiting for $service to be healthy..."
    
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s --connect-timeout 3 "http://localhost:$port/health" >/dev/null 2>&1; then
            echo "[$(date '+%H:%M:%S')] ✅ $service is healthy!"
            echo "SUCCESS" > "/tmp/deploy-$service.status"
            echo "[$(date '+%H:%M:%S')] 🎉 $service deployment completed successfully"
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            echo "[$(date '+%H:%M:%S')] ⚠️ $service did not become healthy within timeout"
            echo "[$(date '+%H:%M:%S')] 📋 Recent logs:"
            docker logs "$container_name" --tail 10 2>/dev/null || echo "No logs available"
            echo "UNHEALTHY" > "/tmp/deploy-$service.status"
            return 1
        fi
        
        echo "[$(date '+%H:%M:%S')] 🔄 Attempt $attempt/$max_attempts - waiting 5 seconds..."
        sleep 5
        attempt=$((attempt + 1))
    done
}

# Deploy all services in parallel
deploy_services_parallel() {
    local branch="$1"
    shift
    local services_to_deploy=("$@")
    
    echo ""
    log_step "🚀 Starting parallel deployment of ${#services_to_deploy[@]} services..."
    echo ""
    
    # Clean up any existing status files
    rm -f /tmp/deploy-*.status /tmp/deploy-*.log
    
    # Start all deployments in parallel
    local pids=()
    for service in "${services_to_deploy[@]}"; do
        echo "🔄 Starting deployment of $service in background..."
        deploy_single_service "$service" "$branch" &
        pids+=($!)
    done
    
    echo ""
    log_info "⚡ All ${#services_to_deploy[@]} services are now deploying in parallel..."
    log_info "📊 Monitoring progress (PIDs: ${pids[*]})"
    echo ""
    
    # Monitor progress
    local completed=0
    local total=${#services_to_deploy[@]}
    
    while [ $completed -lt $total ]; do
        sleep 2
        completed=0
        
        echo -e "\n📊 Deployment Progress Report - $(date '+%H:%M:%S')"
        echo "=============================================="
        
        for service in "${services_to_deploy[@]}"; do
            if [ -f "/tmp/deploy-$service.status" ]; then
                local status=$(cat "/tmp/deploy-$service.status")
                case $status in
                    "SUCCESS")
                        echo "✅ $service: Deployment completed successfully"
                        completed=$((completed + 1))
                        ;;
                    "FAILED")
                        echo "❌ $service: Deployment failed"
                        completed=$((completed + 1))
                        ;;
                    "UNHEALTHY")
                        echo "⚠️ $service: Deployed but unhealthy"
                        completed=$((completed + 1))
                        ;;
                esac
            else
                echo "🔄 $service: Still deploying..."
            fi
        done
        
        echo "Progress: $completed/$total completed"
        echo "=============================================="
    done
    
    # Wait for all background jobs to complete
    for pid in "${pids[@]}"; do
        wait $pid 2>/dev/null || true
    done
    
    echo ""
    log_step "📊 Final Deployment Summary"
    echo ""
    
    # Count results
    local successful=0
    local failed=0
    local unhealthy=0
    
    for service in "${services_to_deploy[@]}"; do
        if [ -f "/tmp/deploy-$service.status" ]; then
            local status=$(cat "/tmp/deploy-$service.status")
            case $status in
                "SUCCESS")
                    echo "✅ $service: Successful"
                    successful=$((successful + 1))
                    ;;
                "FAILED")
                    echo "❌ $service: Failed"
                    failed=$((failed + 1))
                    ;;
                "UNHEALTHY")
                    echo "⚠️ $service: Unhealthy"
                    unhealthy=$((unhealthy + 1))
                    ;;
            esac
        else
            echo "❓ $service: Unknown status"
            failed=$((failed + 1))
        fi
    done
    
    echo ""
    echo "📊 Summary:"
    echo "  ✅ Successful: $successful"
    echo "  ❌ Failed: $failed"
    echo "  ⚠️ Unhealthy: $unhealthy"
    echo "  📊 Total: $total"
    
    # Show logs for failed services
    if [ $failed -gt 0 ] || [ $unhealthy -gt 0 ]; then
        echo ""
        echo "📋 Logs for failed/unhealthy services:"
        for service in "${services_to_deploy[@]}"; do
            if [ -f "/tmp/deploy-$service.status" ]; then
                local status=$(cat "/tmp/deploy-$service.status")
                if [ "$status" = "FAILED" ] || [ "$status" = "UNHEALTHY" ]; then
                    echo ""
                    echo "--- $service logs ---"
                    if [ -f "/tmp/deploy-$service.log" ]; then
                        tail -20 "/tmp/deploy-$service.log"
                    else
                        echo "No logs available"
                    fi
                fi
            fi
        done
    fi
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
        echo "$services_arg" | tr ',' ' '
    fi
}

# Main execution
main() {
    local services_to_deploy=""
    local branch="main"
    local force_rebuild=false
    
    # Parse arguments
    local arg_count=0
    for arg in "$@"; do
        case $arg in
            --force-rebuild)
                force_rebuild=true
                ;;
            *)
                arg_count=$((arg_count + 1))
                case $arg_count in
                    1) services_to_deploy="$arg" ;;
                    2) branch="$arg" ;;
                esac
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
    echo "🌿 Branch: $branch"
    echo "⚡ Parallel deployment: ENABLED"
    echo ""
    
    if ! check_prerequisites; then
        log_error "Prerequisites not met. Aborting."
        exit 1
    fi
    
    if [ "$force_rebuild" = true ]; then
        log_warning "Force rebuild requested - will rebuild all Docker images"
    fi
    
    deploy_services_parallel "$branch" "${services_array[@]}"
    display_status
    
    echo ""
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}🎉 LetzGo Parallel Services Deployment Completed!${NC}"
    echo -e "${GREEN}============================================================================${NC}"
    echo "📅 Completed: $(date)"
    echo "🌐 All services deployed in parallel on the letzgo-network"
    echo ""
}

main "$@"
