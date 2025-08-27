#!/bin/bash

# Deploy Service with Network and Database Fixes
# This script is called by GitHub Actions to deploy services with all necessary fixes
# Usage: ./deploy-service-with-fixes.sh <service_name> <repo_name> [deploy_path]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
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

# Function to load Docker image
load_docker_image() {
    local service_name="$1"
    
    log_info "📦 Loading Docker image for $service_name..."
    
    # Verify compressed tar file exists and is valid
    if [ ! -f "/tmp/letzgo-$service_name-image.tar.gz" ]; then
        log_error "❌ Error: /tmp/letzgo-$service_name-image.tar.gz not found on VPS"
        return 1
    fi
    
    log_info "📊 Archive info:"
    ls -lh "/tmp/letzgo-$service_name-image.tar.gz"
    
    # Test archive integrity
    if ! gzip -t "/tmp/letzgo-$service_name-image.tar.gz"; then
        log_error "❌ Error: Archive is corrupted"
        return 1
    fi
    
    # Load Docker image from compressed archive
    log_info "📦 Loading Docker image from compressed archive..."
    gunzip -c "/tmp/letzgo-$service_name-image.tar.gz" | docker load
    
    # Verify image was loaded
    if docker images | grep -q "letzgo-$service_name"; then
        log_success "✅ Docker image loaded successfully"
        docker images | grep "letzgo-$service_name"
    else
        log_error "❌ Error: Docker image not found after loading"
        return 1
    fi
    
    # Clean up compressed image file
    rm -f "/tmp/letzgo-$service_name-image.tar.gz"
    log_info "🗑️ Cleaned up image archive"
    
    return 0
}

# Function to ensure correct network setup
setup_network() {
    log_info "🌐 Setting up Docker network..."
    
    # Always use letzgo-network (same as infrastructure)
    NETWORK_NAME="letzgo-network"
    
    if ! docker network ls --format "{{.Name}}" | grep -q "^letzgo-network$"; then
        log_info "🔗 Creating letzgo-network..."
        docker network create letzgo-network
    fi
    
    log_info "🔍 Infrastructure containers network status:"
    if docker ps --format "table {{.Names}}\t{{.Networks}}" | grep -E "(postgres|mongodb|redis|rabbitmq)"; then
        log_success "✅ Infrastructure containers found on network"
    else
        log_warning "⚠️ No infrastructure containers found - they should be deployed first"
    fi
    
    # Verify chosen network is accessible
    if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        log_error "❌ Error: network '$NETWORK_NAME' not accessible"
        log_info "📋 Available networks:"
        docker network ls
        return 1
    fi
    
    log_success "✅ Using network: $NETWORK_NAME"
    export NETWORK_NAME
    return 0
}

# Function to prepare environment with corrected database URLs
prepare_environment() {
    local deploy_path="$1"
    
    log_info "🔧 Preparing environment with corrected database URLs..."
    
    cd "$deploy_path"
    
    # Load environment variables
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
        log_success "✅ Environment variables loaded"
    else
        log_error "❌ Environment file not found!"
        return 1
    fi
    
    # Override database connection URLs with correct hostnames
    export POSTGRES_URL="postgresql://postgres:${POSTGRES_PASSWORD}@letzgo-postgres:5432/letzgo?sslmode=disable"
    export MONGODB_URL="mongodb://admin:${MONGODB_PASSWORD}@letzgo-mongodb:27017/letzgo?authSource=admin"
    export MONGODB_URI="mongodb://admin:${MONGODB_PASSWORD}@letzgo-mongodb:27017/letzgo?authSource=admin"
    export REDIS_URL="redis://:${REDIS_PASSWORD}@letzgo-redis:6379"
    export RABBITMQ_URL="amqp://admin:${RABBITMQ_PASSWORD}@letzgo-rabbitmq:5672"
    
    log_info "🔍 Database URLs prepared:"
    echo "POSTGRES_URL: $POSTGRES_URL"
    echo "MONGODB_URL: $MONGODB_URL"
    
    # Ensure proper permissions for container volumes
    log_info "🔧 Setting container permissions for logs and uploads..."
    mkdir -p logs uploads
    chown -R 1001:1001 logs/ uploads/ 2>/dev/null || true
    chmod -R 755 logs/ uploads/ 2>/dev/null || true
    
    log_success "✅ Environment prepared with corrected database URLs"
    return 0
}

# Function to deploy service with all fixes applied
deploy_service() {
    local service_name="$1"
    local repo_name="$2"
    
    log_info "🚀 Deploying $service_name from repository $repo_name with network fixes..."
    
    # Determine service port
    case "$service_name" in
        "auth-service") PORT=3000 ;;
        "user-service") PORT=3001 ;;
        "chat-service") PORT=3002 ;;
        "event-service") PORT=3003 ;;
        "shared-service") PORT=3004 ;;
        "splitz-service") PORT=3005 ;;
        *) 
            log_error "Unknown service: $service_name"
            return 1
            ;;
    esac
    
    # Stop existing container if running
    log_info "🛑 Stopping existing container..."
    docker stop "letzgo-$service_name" 2>/dev/null || true
    docker rm "letzgo-$service_name" 2>/dev/null || true
    
    log_info "📊 Deployment parameters:"
    echo "SERVICE_NAME: $service_name"
    echo "PORT: $PORT"
    echo "NETWORK_NAME: $NETWORK_NAME"
    echo "REPO_NAME: $repo_name"
    
    # Run new container with all fixes applied
    log_info "🚀 Starting container with network and database fixes..."
    docker run -d \
        --name "letzgo-$service_name" \
        --network "$NETWORK_NAME" \
        -p "$PORT:$PORT" \
        -e NODE_ENV=staging \
        -e PORT="$PORT" \
        -e HOST="0.0.0.0" \
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        -e MONGODB_PASSWORD="$MONGODB_PASSWORD" \
        -e REDIS_PASSWORD="$REDIS_PASSWORD" \
        -e RABBITMQ_PASSWORD="$RABBITMQ_PASSWORD" \
        -e JWT_SECRET="$JWT_SECRET" \
        -e SERVICE_API_KEY="$SERVICE_API_KEY" \
        -e POSTGRES_URL="$POSTGRES_URL" \
        -e MONGODB_URL="$MONGODB_URL" \
        -e MONGODB_URI="$MONGODB_URI" \
        -e REDIS_URL="$REDIS_URL" \
        -e RABBITMQ_URL="$RABBITMQ_URL" \
        -e POSTGRES_HOST=letzgo-postgres \
        -e MONGODB_HOST=letzgo-mongodb \
        -e REDIS_HOST=letzgo-redis \
        -e RABBITMQ_HOST=letzgo-rabbitmq \
        -e POSTGRES_PORT=5432 \
        -e MONGODB_PORT=27017 \
        -e REDIS_PORT=6379 \
        -e RABBITMQ_PORT=5672 \
        -e POSTGRES_DATABASE=letzgo \
        -e MONGODB_DATABASE=letzgo \
        -e POSTGRES_USERNAME=postgres \
        -e MONGODB_USERNAME=admin \
        -e RABBITMQ_USERNAME=admin \
        -e DB_SCHEMA=public \
        -e DOMAIN_NAME="${DOMAIN_NAME}" \
        -e API_DOMAIN="${API_DOMAIN}" \
        -e USER_SERVICE_URL="http://letzgo-user-service:3001" \
        -e USER_SERVICE_VERSION="v1" \
        -e CHAT_SERVICE_URL="http://letzgo-chat-service:3002" \
        -e CHAT_SERVICE_VERSION="v1" \
        -e EVENT_SERVICE_URL="http://letzgo-event-service:3003" \
        -e EVENT_SERVICE_VERSION="v1" \
        -e SHARED_SERVICE_URL="http://letzgo-shared-service:3004" \
        -e SHARED_SERVICE_VERSION="v1" \
        -e SPLITZ_SERVICE_URL="http://letzgo-splitz-service:3005" \
        -e SPLITZ_SERVICE_VERSION="v1" \
        -v "/opt/letzgo/logs:/app/logs" \
        -v "/opt/letzgo/uploads:/app/uploads" \
        --restart unless-stopped \
        "letzgo-$service_name:latest"
    
    if [ $? -eq 0 ]; then
        log_success "✅ $service_name deployed successfully from $repo_name with all fixes applied!"
    else
        log_error "❌ Failed to deploy $service_name"
        return 1
    fi
    
    # Show running container
    log_info "📋 Running container:"
    docker ps | grep "letzgo-$service_name" || log_warning "Container not found in ps output"
    
    return 0
}

# Function to perform health check with optimized timing
perform_health_check() {
    local service_name="$1"
    local max_attempts=5
    local wait_time=5
    
    # Determine service port
    case "$service_name" in
        "auth-service") PORT=3000 ;;
        "user-service") PORT=3001 ;;
        "chat-service") PORT=3002 ;;
        "event-service") PORT=3003 ;;
        "shared-service") PORT=3004 ;;
        "splitz-service") PORT=3005 ;;
        *) 
            log_error "Unknown service for health check: $service_name"
            return 1
            ;;
    esac
    
    log_info "⏳ Waiting for $service_name to be healthy on port $PORT..."
    log_info "📊 Health check: $max_attempts attempts × ${wait_time}s = $((max_attempts * wait_time))s maximum"
    
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        # Check if container is running first
        if ! docker ps --format "{{.Names}}" | grep -q "letzgo-$service_name"; then
            log_warning "⚠️ Container letzgo-$service_name is not running"
            if [ $attempt -eq $max_attempts ]; then
                log_error "❌ Container failed to stay running after $max_attempts attempts"
                log_info "📋 Container logs (last 20 lines):"
                docker logs "letzgo-$service_name" --tail 20 2>/dev/null || echo "No logs available"
                return 1
            fi
            log_info "Attempt $attempt/$max_attempts - container not running, waiting ${wait_time}s..."
            sleep $wait_time
            attempt=$((attempt + 1))
            continue
        fi
        
        # Check if port is bound first
        if ! netstat -tlnp 2>/dev/null | grep -q ":$PORT "; then
            log_info "⏳ Port $PORT not yet bound, service may still be starting..."
            if [ $attempt -eq $max_attempts ]; then
                log_warning "⚠️ Port $PORT never became available"
                log_info "📊 Currently bound ports:"
                netstat -tlnp 2>/dev/null | grep -E ":(3000|3001|3002|3003|3004|3005) " || echo "No service ports bound"
            else
                log_info "Attempt $attempt/$max_attempts - waiting for port binding, ${wait_time}s..."
                sleep $wait_time
                attempt=$((attempt + 1))
                continue
            fi
        fi
        
        # Test health endpoint with connection timeout
        if curl -f -s --connect-timeout 3 --max-time 10 "http://localhost:$PORT/health" >/dev/null 2>&1; then
            log_success "✅ $service_name is healthy!"
            log_info "📊 Health response:"
            curl -s --connect-timeout 3 --max-time 10 "http://localhost:$PORT/health" 2>/dev/null | head -3 || echo "Health endpoint responded"
            return 0
        fi
        
        # Additional diagnostic if health check fails
        if [ $attempt -ge 3 ]; then
            log_info "🔍 Additional diagnostics (attempt $attempt):"
            
            # Test if port responds at all
            if nc -z localhost "$PORT" 2>/dev/null; then
                log_info "✅ Port $PORT is responding"
                # Try to get any response from the port
                log_info "📊 Raw response test:"
                echo "GET /health HTTP/1.1\r\nHost: localhost\r\n\r\n" | nc localhost "$PORT" 2>/dev/null | head -5 || echo "No response"
            else
                log_warning "⚠️ Port $PORT is not responding"
            fi
            
            # Check recent logs for errors
            log_info "📋 Recent service logs:"
            docker logs "letzgo-$service_name" --tail 10 2>/dev/null | tail -5 || echo "No recent logs"
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "❌ $service_name failed to become healthy after $max_attempts attempts"
            log_info "📋 Final diagnostics:"
            echo ""
            echo "Container status:"
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "letzgo-$service_name" || echo "Container not found"
            echo ""
            echo "Container logs (last 50 lines):"
            docker logs "letzgo-$service_name" --tail 50 2>/dev/null || echo "No logs available"
            echo ""
            echo "Network connectivity test:"
            docker exec "letzgo-$service_name" wget -qO- "http://localhost:$PORT/health" 2>&1 || echo "Internal health check failed"
            echo ""
            echo "Database connectivity test:"
            docker exec "letzgo-$service_name" nslookup letzgo-postgres 2>/dev/null || echo "PostgreSQL DNS lookup failed"
            docker exec "letzgo-$service_name" nslookup letzgo-mongodb 2>/dev/null || echo "MongoDB DNS lookup failed"
            return 1
        fi
        
        log_info "Attempt $attempt/$max_attempts - waiting ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Main execution function
main() {
    local service_name="$1"
    local repo_name="$2"
    local deploy_path="${3:-/opt/letzgo}"
    
    if [ -z "$service_name" ] || [ -z "$repo_name" ]; then
        log_error "Usage: $0 <service_name> <repo_name> [deploy_path]"
        log_info "Example: $0 auth-service rishanimates/auth-service /opt/letzgo"
        exit 1
    fi
    
    log_info "🚀 Starting service deployment with all fixes applied"
    log_info "📊 Parameters:"
    echo "  Service: $service_name"
    echo "  Repository: $repo_name"
    echo "  Deploy Path: $deploy_path"
    echo ""
    
    # Execute deployment steps with error handling
    if load_docker_image "$service_name"; then
        log_success "✅ Step 1/5: Docker image loaded"
    else
        log_error "❌ Step 1/5: Failed to load Docker image"
        exit 1
    fi
    
    if setup_network; then
        log_success "✅ Step 2/5: Network setup completed"
    else
        log_error "❌ Step 2/5: Failed to setup network"
        exit 1
    fi
    
    if prepare_environment "$deploy_path"; then
        log_success "✅ Step 3/5: Environment prepared"
    else
        log_error "❌ Step 3/5: Failed to prepare environment"
        exit 1
    fi
    
    if deploy_service "$service_name" "$repo_name"; then
        log_success "✅ Step 4/5: Service deployed"
    else
        log_error "❌ Step 4/5: Failed to deploy service"
        exit 1
    fi
    
    echo ""
    if perform_health_check "$service_name"; then
        log_success "✅ Step 5/5: Health check passed"
        echo ""
        log_success "🎉 $service_name deployment completed successfully!"
        echo ""
        log_info "📊 Final Status:"
        echo "✅ Docker image: Loaded and verified"
        echo "✅ Network connectivity: Fixed (same network as infrastructure)"
        echo "✅ Database URLs: Corrected with proper hostnames"
        echo "✅ Service deployment: Successful"
        echo "✅ Health check: Passed"
        echo "✅ Service status: Ready for use"
    else
        log_warning "⚠️ Step 5/5: Health check failed"
        echo ""
        log_warning "⚠️ $service_name deployed but not fully healthy"
        echo ""
        log_info "📊 Partial Success Status:"
        echo "✅ Docker image: Loaded and verified"
        echo "✅ Network connectivity: Fixed"
        echo "✅ Database URLs: Corrected"
        echo "✅ Service deployment: Successful"
        echo "⚠️ Health check: Failed (possibly schema migration issues)"
        echo "⚠️ Service status: Deployed but may need manual intervention"
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"
