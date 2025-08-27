#!/bin/bash

# Fix Service Network Connectivity Script
# This script runs on the VPS via GitHub Actions to fix network connectivity issues
# Usage: Called automatically by GitHub Actions deployment workflow

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

# Main function to fix network connectivity
fix_network_connectivity() {
    local service_name="$1"
    local deploy_path="${2:-/opt/letzgo}"
    
    log_info "🔧 Fixing network connectivity for $service_name..."
    
    cd "$deploy_path"
    
    # Load environment variables
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
        log_success "✅ Environment variables loaded"
    else
        log_error "❌ Environment file not found at $deploy_path/.env"
        return 1
    fi
    
    # Ensure we use the correct network (same as infrastructure)
    NETWORK_NAME="letzgo-network"
    
    log_info "🔍 Verifying network configuration..."
    
    # Check if infrastructure containers are running
    if ! docker ps --format "{{.Names}}" | grep -q "letzgo-postgres"; then
        log_error "❌ Infrastructure containers not found. Deploy infrastructure first."
        return 1
    fi
    
    # Get infrastructure network
    INFRA_NETWORK=$(docker inspect letzgo-postgres --format='{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}{{end}}' 2>/dev/null || echo "")
    
    if [ -n "$INFRA_NETWORK" ]; then
        NETWORK_NAME="$INFRA_NETWORK"
        log_info "🔗 Using infrastructure network: $NETWORK_NAME"
    else
        log_warning "⚠️ Could not detect infrastructure network, using default: $NETWORK_NAME"
    fi
    
    # Stop existing service container
    log_info "🛑 Stopping existing $service_name container..."
    docker stop "letzgo-$service_name" 2>/dev/null || true
    docker rm "letzgo-$service_name" 2>/dev/null || true
    
    # Prepare corrected database URLs
    POSTGRES_URL="postgresql://postgres:${POSTGRES_PASSWORD}@letzgo-postgres:5432/letzgo?sslmode=disable"
    MONGODB_URL="mongodb://admin:${MONGODB_PASSWORD}@letzgo-mongodb:27017/letzgo?authSource=admin"
    MONGODB_URI="mongodb://admin:${MONGODB_PASSWORD}@letzgo-mongodb:27017/letzgo?authSource=admin"
    REDIS_URL="redis://:${REDIS_PASSWORD}@letzgo-redis:6379"
    RABBITMQ_URL="amqp://admin:${RABBITMQ_PASSWORD}@letzgo-rabbitmq:5672"
    
    log_info "🔍 Database connection URLs prepared with correct hostnames"
    
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
    
    # Ensure proper permissions for container volumes
    log_info "🔧 Setting container permissions..."
    mkdir -p logs uploads
    chown -R 1001:1001 logs/ uploads/ 2>/dev/null || true
    chmod -R 755 logs/ uploads/ 2>/dev/null || true
    
    # Deploy service with corrected network and database URLs
    log_info "🚀 Deploying $service_name on network $NETWORK_NAME with fixed connectivity..."
    
    docker run -d \
        --name "letzgo-$service_name" \
        --network "$NETWORK_NAME" \
        -p "$PORT:$PORT" \
        -e NODE_ENV=staging \
        -e PORT="$PORT" \
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
        -e DOMAIN_NAME="${DOMAIN_NAME:-103.168.19.241}" \
        -e API_DOMAIN="${API_DOMAIN:-103.168.19.241}" \
        -v "$deploy_path/logs:/app/logs" \
        -v "$deploy_path/uploads:/app/uploads" \
        --restart unless-stopped \
        "letzgo-$service_name:latest"
    
    if [ $? -eq 0 ]; then
        log_success "✅ $service_name deployed successfully with fixed network connectivity"
    else
        log_error "❌ Failed to deploy $service_name"
        return 1
    fi
    
    # Verify network connectivity
    log_info "🔍 Verifying network connectivity..."
    sleep 3
    
    # Check if container is running
    if docker ps --format "{{.Names}}" | grep -q "letzgo-$service_name"; then
        log_success "✅ Container letzgo-$service_name is running"
        
        # Test network connectivity to databases
        log_info "🔍 Testing database connectivity from $service_name..."
        
        # Test PostgreSQL connectivity
        if docker exec "letzgo-$service_name" nslookup letzgo-postgres >/dev/null 2>&1; then
            log_success "✅ DNS resolution to letzgo-postgres working"
        else
            log_warning "⚠️ DNS resolution to letzgo-postgres failed"
        fi
        
        # Test MongoDB connectivity
        if docker exec "letzgo-$service_name" nslookup letzgo-mongodb >/dev/null 2>&1; then
            log_success "✅ DNS resolution to letzgo-mongodb working"
        else
            log_warning "⚠️ DNS resolution to letzgo-mongodb failed"
        fi
        
        # Show network status
        log_info "📋 Network status:"
        echo "Service network: $(docker inspect "letzgo-$service_name" --format='{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}{{end}}' 2>/dev/null || echo 'Unknown')"
        echo "Infrastructure networks:"
        docker ps --format "table {{.Names}}\t{{.Networks}}" | grep -E "(postgres|mongodb|redis|rabbitmq)" | head -4
        
    else
        log_error "❌ Container letzgo-$service_name is not running"
        log_info "📋 Recent logs:"
        docker logs "letzgo-$service_name" --tail 10 2>/dev/null || echo "No logs available"
        return 1
    fi
    
    log_success "🎉 Network connectivity fix completed for $service_name"
    return 0
}

# Health check function with optimized timing
wait_for_service_health() {
    local service_name="$1"
    local max_attempts="${2:-5}"
    local wait_time="${3:-5}"
    
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
    log_info "📊 Health check parameters: $max_attempts attempts × ${wait_time}s = $((max_attempts * wait_time))s maximum"
    
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        # Check if container is running first
        if ! docker ps --format "{{.Names}}" | grep -q "letzgo-$service_name"; then
            log_warning "⚠️ Container letzgo-$service_name is not running"
            if [ $attempt -eq $max_attempts ]; then
                log_error "❌ Container failed to stay running"
                docker logs "letzgo-$service_name" --tail 20 2>/dev/null || echo "No logs available"
                return 1
            fi
            log_info "Attempt $attempt/$max_attempts - waiting ${wait_time}s for container to start..."
            sleep $wait_time
            attempt=$((attempt + 1))
            continue
        fi
        
        # Test health endpoint
        if curl -f -s "http://localhost:$PORT/health" >/dev/null 2>&1; then
            log_success "✅ $service_name is healthy!"
            log_info "📊 Health response:"
            curl -s "http://localhost:$PORT/health" 2>/dev/null || echo "Health endpoint responded but no JSON output"
            return 0
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "❌ $service_name failed to become healthy after $max_attempts attempts"
            log_info "📋 Final diagnostics:"
            echo "Container status:"
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "letzgo-$service_name" || echo "Container not found"
            echo ""
            echo "Recent logs (last 30 lines):"
            docker logs "letzgo-$service_name" --tail 30 2>/dev/null || echo "No logs available"
            echo ""
            echo "Network connectivity test:"
            docker exec "letzgo-$service_name" wget -qO- "http://localhost:$PORT/health" 2>&1 || echo "Internal health check failed"
            return 1
        fi
        
        log_info "Attempt $attempt/$max_attempts - waiting ${wait_time}s..."
        sleep $wait_time
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Main execution
main() {
    local service_name="$1"
    local deploy_path="${2:-/opt/letzgo}"
    local health_check="${3:-true}"
    
    if [ -z "$service_name" ]; then
        log_error "Usage: $0 <service_name> [deploy_path] [health_check]"
        log_info "Example: $0 auth-service /opt/letzgo true"
        exit 1
    fi
    
    log_info "🚀 Starting network connectivity fix for $service_name"
    log_info "📁 Deploy path: $deploy_path"
    log_info "🏥 Health check: $health_check"
    echo ""
    
    # Fix network connectivity
    if fix_network_connectivity "$service_name" "$deploy_path"; then
        log_success "✅ Network connectivity fixed successfully"
        
        # Perform health check if requested
        if [ "$health_check" = "true" ]; then
            echo ""
            if wait_for_service_health "$service_name" 5 5; then
                log_success "🎉 $service_name is healthy and ready!"
                echo ""
                log_info "📊 Final Status Summary:"
                echo "✅ Network connectivity: Fixed"
                echo "✅ Database URLs: Corrected"
                echo "✅ Container deployment: Successful"
                echo "✅ Health check: Passed"
                echo "✅ Service status: Ready for use"
            else
                log_warning "⚠️ Service deployed but health check failed"
                echo ""
                log_info "📊 Partial Success Summary:"
                echo "✅ Network connectivity: Fixed"
                echo "✅ Database URLs: Corrected"
                echo "✅ Container deployment: Successful"
                echo "⚠️ Health check: Failed (may be schema migration issue)"
                echo "⚠️ Service status: Deployed but not fully healthy"
                exit 1
            fi
        else
            log_info "⏭️ Skipping health check as requested"
        fi
    else
        log_error "❌ Failed to fix network connectivity for $service_name"
        exit 1
    fi
}

# Execute main function with all arguments
main "$@"
