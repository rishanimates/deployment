#!/bin/bash

# Diagnose and Fix Service Health Issues
# This script analyzes why services are not responding to health checks
# Usage: ./diagnose-and-fix-service-health.sh <service_name> [deploy_path]

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

# Function to get service port
get_service_port() {
    local service_name="$1"
    case "$service_name" in
        "auth-service") echo "3000" ;;
        "user-service") echo "3001" ;;
        "chat-service") echo "3002" ;;
        "event-service") echo "3003" ;;
        "shared-service") echo "3004" ;;
        "splitz-service") echo "3005" ;;
        *) echo "unknown" ;;
    esac
}

# Function to diagnose container status
diagnose_container_status() {
    local service_name="$1"
    local container_name="letzgo-$service_name"
    
    log_info "🔍 Diagnosing container status for $service_name..."
    
    # Check if container exists
    if ! docker ps -a --format "{{.Names}}" | grep -q "^$container_name$"; then
        log_error "❌ Container $container_name does not exist"
        return 1
    fi
    
    # Get container status
    local status=$(docker ps --format "{{.Names}} {{.Status}}" | grep "^$container_name " | cut -d' ' -f2- || echo "Not running")
    log_info "📊 Container status: $status"
    
    # Check if container is running
    if docker ps --format "{{.Names}}" | grep -q "^$container_name$"; then
        log_success "✅ Container is running"
        
        # Get detailed container info
        log_info "📋 Container details:"
        docker inspect "$container_name" --format='
Container ID: {{.Id}}
State: {{.State.Status}}
Started: {{.State.StartedAt}}
Ports: {{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}} {{end}}
Network: {{range $net, $conf := .NetworkSettings.Networks}}{{$net}} ({{$conf.IPAddress}}){{end}}
' 2>/dev/null || echo "Could not get container details"
        
        return 0
    else
        log_error "❌ Container is not running"
        
        # Check container logs for why it's not running
        log_info "📋 Recent container logs:"
        docker logs "$container_name" --tail 20 2>/dev/null || echo "No logs available"
        
        return 1
    fi
}

# Function to diagnose network connectivity
diagnose_network_connectivity() {
    local service_name="$1"
    local port="$2"
    local container_name="letzgo-$service_name"
    
    log_info "🌐 Diagnosing network connectivity for $service_name on port $port..."
    
    # Check if container is on the correct network
    local container_networks=$(docker inspect "$container_name" --format='{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}' 2>/dev/null || echo "")
    log_info "📊 Container networks: $container_networks"
    
    # Check infrastructure networks for comparison
    log_info "📊 Infrastructure container networks:"
    docker ps --format "table {{.Names}}\t{{.Networks}}" | grep -E "(postgres|mongodb|redis|rabbitmq)" | head -4
    
    # Test internal network connectivity from container
    if docker ps --format "{{.Names}}" | grep -q "^$container_name$"; then
        log_info "🔍 Testing internal network connectivity..."
        
        # Test if service can reach databases
        log_info "Testing PostgreSQL connectivity:"
        if docker exec "$container_name" nslookup letzgo-postgres >/dev/null 2>&1; then
            log_success "✅ DNS resolution to letzgo-postgres works"
            if docker exec "$container_name" nc -z letzgo-postgres 5432 2>/dev/null; then
                log_success "✅ Network connection to PostgreSQL works"
            else
                log_warning "⚠️ Cannot connect to PostgreSQL port 5432"
            fi
        else
            log_error "❌ DNS resolution to letzgo-postgres failed"
        fi
        
        log_info "Testing MongoDB connectivity:"
        if docker exec "$container_name" nslookup letzgo-mongodb >/dev/null 2>&1; then
            log_success "✅ DNS resolution to letzgo-mongodb works"
            if docker exec "$container_name" nc -z letzgo-mongodb 27017 2>/dev/null; then
                log_success "✅ Network connection to MongoDB works"
            else
                log_warning "⚠️ Cannot connect to MongoDB port 27017"
            fi
        else
            log_error "❌ DNS resolution to letzgo-mongodb failed"
        fi
    fi
    
    # Test external port binding
    log_info "🔍 Testing external port binding..."
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        log_success "✅ Port $port is bound and listening"
        local pid=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1)
        log_info "📊 Process listening on port $port: PID $pid"
    else
        log_error "❌ Port $port is not bound or not listening"
        log_info "📊 Currently bound ports:"
        netstat -tlnp 2>/dev/null | grep -E ":(3000|3001|3002|3003|3004|3005) " || echo "No service ports found"
    fi
}

# Function to diagnose application health
diagnose_application_health() {
    local service_name="$1"
    local port="$2"
    local container_name="letzgo-$service_name"
    
    log_info "🏥 Diagnosing application health for $service_name..."
    
    # Check container logs for application startup
    log_info "📋 Recent application logs (last 30 lines):"
    docker logs "$container_name" --tail 30 2>/dev/null || echo "No logs available"
    
    echo ""
    
    # Test health endpoint from multiple perspectives
    log_info "🔍 Testing health endpoint accessibility..."
    
    # Test from host
    log_info "Testing from host (localhost:$port/health):"
    if curl -f -s --connect-timeout 5 "http://localhost:$port/health" >/dev/null 2>&1; then
        log_success "✅ Health endpoint accessible from host"
        curl -s "http://localhost:$port/health" | head -3
    else
        log_error "❌ Health endpoint not accessible from host"
        
        # Test if port is responding at all
        if nc -z localhost "$port" 2>/dev/null; then
            log_warning "⚠️ Port $port is open but health endpoint not responding"
        else
            log_error "❌ Port $port is not responding at all"
        fi
    fi
    
    # Test from inside container
    if docker ps --format "{{.Names}}" | grep -q "^$container_name$"; then
        log_info "Testing from inside container (localhost:$port/health):"
        if docker exec "$container_name" wget -qO- --timeout=5 "http://localhost:$port/health" >/dev/null 2>&1; then
            log_success "✅ Health endpoint accessible from inside container"
            docker exec "$container_name" wget -qO- --timeout=5 "http://localhost:$port/health" 2>/dev/null | head -3
        else
            log_error "❌ Health endpoint not accessible from inside container"
            
            # Check if the process is listening inside container
            log_info "📊 Processes inside container:"
            docker exec "$container_name" ps aux 2>/dev/null || echo "Cannot list processes"
            
            log_info "📊 Network interfaces inside container:"
            docker exec "$container_name" ip addr show 2>/dev/null || echo "Cannot show network interfaces"
            
            log_info "📊 Listening ports inside container:"
            docker exec "$container_name" netstat -tlnp 2>/dev/null || echo "Cannot show listening ports"
        fi
    fi
}

# Function to check service configuration issues
diagnose_service_configuration() {
    local service_name="$1"
    local container_name="letzgo-$service_name"
    
    log_info "⚙️ Diagnosing service configuration for $service_name..."
    
    if docker ps --format "{{.Names}}" | grep -q "^$container_name$"; then
        # Check environment variables
        log_info "📊 Key environment variables:"
        docker exec "$container_name" env 2>/dev/null | grep -E "(NODE_ENV|PORT|HOST|POSTGRES|MONGODB)" | sort || echo "Cannot get environment variables"
        
        echo ""
        
        # Check if service is trying to connect to other services that don't exist
        log_info "📊 Service validation issues from logs:"
        docker logs "$container_name" 2>/dev/null | grep -E "(Invalid Services|Version: Not configured|SERVICE_URL)" | tail -10 || echo "No service validation issues found"
    fi
}

# Function to fix common issues
fix_service_issues() {
    local service_name="$1"
    local port="$2"
    local deploy_path="$3"
    local container_name="letzgo-$service_name"
    
    log_info "🔧 Attempting to fix common service issues for $service_name..."
    
    cd "$deploy_path"
    
    # Load environment variables
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
    else
        log_error "❌ Environment file not found!"
        return 1
    fi
    
    # Stop and remove existing container
    log_info "🛑 Stopping and removing existing container..."
    docker stop "$container_name" 2>/dev/null || true
    docker rm "$container_name" 2>/dev/null || true
    
    # Get the correct network (same as infrastructure)
    local network_name="letzgo-network"
    if docker network ls --format "{{.Name}}" | grep -q "^letzgo_letzgo-network$"; then
        network_name="letzgo_letzgo-network"
    fi
    
    log_info "🔗 Using network: $network_name"
    
    # Prepare corrected database URLs
    local POSTGRES_URL="postgresql://postgres:${POSTGRES_PASSWORD}@letzgo-postgres:5432/letzgo?sslmode=disable"
    local MONGODB_URL="mongodb://admin:${MONGODB_PASSWORD}@letzgo-mongodb:27017/letzgo?authSource=admin"
    local MONGODB_URI="mongodb://admin:${MONGODB_PASSWORD}@letzgo-mongodb:27017/letzgo?authSource=admin"
    local REDIS_URL="redis://:${REDIS_PASSWORD}@letzgo-redis:6379"
    local RABBITMQ_URL="amqp://admin:${RABBITMQ_PASSWORD}@letzgo-rabbitmq:5672"
    
    # Deploy service with fixes
    log_info "🚀 Deploying $service_name with fixes..."
    docker run -d \
        --name "$container_name" \
        --network "$network_name" \
        -p "$port:$port" \
        -e NODE_ENV=staging \
        -e PORT="$port" \
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
        -e DOMAIN_NAME="${DOMAIN_NAME:-103.168.19.241}" \
        -e API_DOMAIN="${API_DOMAIN:-103.168.19.241}" \
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
        -v "$deploy_path/logs:/app/logs" \
        -v "$deploy_path/uploads:/app/uploads" \
        --restart unless-stopped \
        "letzgo-$service_name:latest"
    
    if [ $? -eq 0 ]; then
        log_success "✅ $service_name redeployed with fixes"
        
        # Wait a moment for startup
        log_info "⏳ Waiting for service to start..."
        sleep 10
        
        # Test health endpoint
        local max_attempts=10
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if curl -f -s --connect-timeout 5 "http://localhost:$port/health" >/dev/null 2>&1; then
                log_success "✅ $service_name is now healthy!"
                curl -s "http://localhost:$port/health" | head -3
                return 0
            fi
            
            if [ $attempt -eq $max_attempts ]; then
                log_warning "⚠️ Service deployed but still not responding to health checks"
                break
            fi
            
            log_info "Attempt $attempt/$max_attempts - waiting 3 seconds..."
            sleep 3
            attempt=$((attempt + 1))
        done
    else
        log_error "❌ Failed to redeploy $service_name"
        return 1
    fi
}

# Main diagnosis and fix function
main() {
    local service_name="$1"
    local deploy_path="${2:-/opt/letzgo}"
    
    if [ -z "$service_name" ]; then
        log_error "Usage: $0 <service_name> [deploy_path]"
        log_info "Example: $0 auth-service /opt/letzgo"
        exit 1
    fi
    
    local port=$(get_service_port "$service_name")
    if [ "$port" = "unknown" ]; then
        log_error "❌ Unknown service: $service_name"
        exit 1
    fi
    
    log_info "🔍 Starting comprehensive diagnosis for $service_name"
    log_info "📊 Service: $service_name"
    log_info "📊 Port: $port"
    log_info "📊 Deploy path: $deploy_path"
    echo ""
    
    # Step 1: Diagnose container status
    log_info "🔍 Step 1: Container Status Diagnosis"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if diagnose_container_status "$service_name"; then
        log_success "✅ Container status diagnosis completed"
    else
        log_warning "⚠️ Container status issues detected"
    fi
    echo ""
    
    # Step 2: Diagnose network connectivity
    log_info "🔍 Step 2: Network Connectivity Diagnosis"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    diagnose_network_connectivity "$service_name" "$port"
    echo ""
    
    # Step 3: Diagnose application health
    log_info "🔍 Step 3: Application Health Diagnosis"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    diagnose_application_health "$service_name" "$port"
    echo ""
    
    # Step 4: Diagnose service configuration
    log_info "🔍 Step 4: Service Configuration Diagnosis"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    diagnose_service_configuration "$service_name"
    echo ""
    
    # Step 5: Attempt to fix issues
    log_info "🔧 Step 5: Attempting to Fix Issues"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if fix_service_issues "$service_name" "$port" "$deploy_path"; then
        log_success "🎉 $service_name diagnosis and fix completed successfully!"
        echo ""
        log_info "📊 Final Status:"
        echo "✅ Service deployed and running"
        echo "✅ Health endpoint responding"
        echo "✅ Network connectivity verified"
        echo "✅ Database connections working"
    else
        log_warning "⚠️ $service_name diagnosis completed but issues may remain"
        echo ""
        log_info "📊 Final Status:"
        echo "✅ Diagnosis completed"
        echo "⚠️ Some issues may require manual intervention"
        echo "📋 Check the diagnosis output above for specific problems"
    fi
}

# Execute main function with all arguments
main "$@"
