#!/bin/bash

# Fix Database Connection Issues
# This script fixes common PostgreSQL and RabbitMQ connection problems

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${CYAN}"
echo "============================================================================"
echo "🔧 LetzGo Database Connection Fix"
echo "============================================================================"
echo -e "${NC}"
echo "📅 Started: $(date)"
echo ""

# Load environment if available
if [ -f "/opt/letzgo/.env" ]; then
    set -a
    source /opt/letzgo/.env
    set +a
    log_info "✅ Environment loaded"
else
    log_warning "⚠️ Environment file not found at /opt/letzgo/.env"
fi

# Fix PostgreSQL issues
fix_postgresql() {
    log_info "🐘 Fixing PostgreSQL issues..."
    
    if docker ps --format "{{.Names}}" | grep -q "^letzgo-postgres$"; then
        log_info "PostgreSQL container is running"
        
        # Wait for PostgreSQL to be ready
        log_info "Waiting for PostgreSQL to be ready..."
        local attempts=0
        local max_attempts=30
        
        while [ $attempts -lt $max_attempts ]; do
            if docker exec letzgo-postgres pg_isready -U postgres >/dev/null 2>&1; then
                log_success "✅ PostgreSQL is ready"
                break
            fi
            
            attempts=$((attempts + 1))
            log_info "Attempt $attempts/$max_attempts - waiting 2 seconds..."
            sleep 2
        done
        
        if [ $attempts -eq $max_attempts ]; then
            log_error "❌ PostgreSQL did not become ready"
            log_info "Restarting PostgreSQL container..."
            docker restart letzgo-postgres
            sleep 10
        fi
        
        # Test database connection
        if docker exec letzgo-postgres pg_isready -U postgres -d letzgo >/dev/null 2>&1; then
            log_success "✅ PostgreSQL database connection working"
            
            # Test if we can query the database
            local table_count=$(docker exec letzgo-postgres psql -U postgres -d letzgo -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ' || echo "0")
            log_info "PostgreSQL tables found: $table_count"
            
            if [ "$table_count" = "0" ]; then
                log_warning "⚠️ No tables found, database schema may not be initialized"
                log_info "Checking if initialization scripts exist..."
                
                if [ -d "/opt/letzgo/database/init" ]; then
                    log_info "Re-running database initialization..."
                    docker exec letzgo-postgres psql -U postgres -d letzgo -f /docker-entrypoint-initdb.d/01-init-postgres.sql || log_warning "Schema initialization failed"
                fi
            fi
            
        else
            log_error "❌ PostgreSQL database connection failed"
            log_info "Checking PostgreSQL logs..."
            docker logs letzgo-postgres --tail 20
        fi
        
    else
        log_error "❌ PostgreSQL container is not running"
        log_info "Starting PostgreSQL container..."
        
        cd /opt/letzgo
        docker-compose -f docker-compose.infrastructure.yml up -d postgres
        sleep 15
        
        if docker ps --format "{{.Names}}" | grep -q "^letzgo-postgres$"; then
            log_success "✅ PostgreSQL container started"
        else
            log_error "❌ Failed to start PostgreSQL container"
        fi
    fi
    
    echo ""
}

# Fix RabbitMQ issues
fix_rabbitmq() {
    log_info "🐰 Fixing RabbitMQ issues..."
    
    if docker ps --format "{{.Names}}" | grep -q "^letzgo-rabbitmq$"; then
        log_info "RabbitMQ container is running"
        
        # Wait for RabbitMQ to be ready
        log_info "Waiting for RabbitMQ to be ready..."
        local attempts=0
        local max_attempts=30
        
        while [ $attempts -lt $max_attempts ]; do
            if docker exec letzgo-rabbitmq rabbitmqctl node_health_check >/dev/null 2>&1; then
                log_success "✅ RabbitMQ is ready"
                break
            fi
            
            attempts=$((attempts + 1))
            log_info "Attempt $attempts/$max_attempts - waiting 3 seconds..."
            sleep 3
        done
        
        if [ $attempts -eq $max_attempts ]; then
            log_error "❌ RabbitMQ did not become ready"
            log_info "Restarting RabbitMQ container..."
            docker restart letzgo-rabbitmq
            sleep 15
        fi
        
        # Test RabbitMQ status
        if docker exec letzgo-rabbitmq rabbitmqctl status >/dev/null 2>&1; then
            log_success "✅ RabbitMQ status check passed"
            
            # Check if management plugin is enabled
            if docker exec letzgo-rabbitmq rabbitmq-plugins list | grep -q "rabbitmq_management.*E"; then
                log_success "✅ RabbitMQ management plugin is enabled"
            else
                log_info "Enabling RabbitMQ management plugin..."
                docker exec letzgo-rabbitmq rabbitmq-plugins enable rabbitmq_management || log_warning "Failed to enable management plugin"
            fi
            
            # Test if we can list users
            local user_count=$(docker exec letzgo-rabbitmq rabbitmqctl list_users 2>/dev/null | wc -l || echo "0")
            log_info "RabbitMQ users found: $user_count"
            
        else
            log_error "❌ RabbitMQ status check failed"
            log_info "Checking RabbitMQ logs..."
            docker logs letzgo-rabbitmq --tail 20
        fi
        
    else
        log_error "❌ RabbitMQ container is not running"
        log_info "Starting RabbitMQ container..."
        
        cd /opt/letzgo
        docker-compose -f docker-compose.infrastructure.yml up -d rabbitmq
        sleep 20
        
        if docker ps --format "{{.Names}}" | grep -q "^letzgo-rabbitmq$"; then
            log_success "✅ RabbitMQ container started"
        else
            log_error "❌ Failed to start RabbitMQ container"
        fi
    fi
    
    echo ""
}

# Fix MongoDB (for completeness)
fix_mongodb() {
    log_info "🍃 Checking MongoDB..."
    
    if docker ps --format "{{.Names}}" | grep -q "^letzgo-mongodb$"; then
        if docker exec letzgo-mongodb mongosh --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
            log_success "✅ MongoDB connection working"
        else
            log_warning "⚠️ MongoDB connection issues detected"
            docker restart letzgo-mongodb
            sleep 10
        fi
    else
        log_info "Starting MongoDB container..."
        cd /opt/letzgo
        docker-compose -f docker-compose.infrastructure.yml up -d mongodb
        sleep 10
    fi
    
    echo ""
}

# Fix Redis (for completeness)
fix_redis() {
    log_info "📦 Checking Redis..."
    
    if docker ps --format "{{.Names}}" | grep -q "^letzgo-redis$"; then
        if [ -n "$REDIS_PASSWORD" ]; then
            if docker exec letzgo-redis redis-cli --no-auth-warning -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
                log_success "✅ Redis connection working"
            else
                log_warning "⚠️ Redis connection issues detected"
                docker restart letzgo-redis
                sleep 5
            fi
        else
            log_warning "⚠️ Redis password not found in environment"
        fi
    else
        log_info "Starting Redis container..."
        cd /opt/letzgo
        docker-compose -f docker-compose.infrastructure.yml up -d redis
        sleep 5
    fi
    
    echo ""
}

# Check network connectivity
fix_network() {
    log_info "🌐 Checking network connectivity..."
    
    if ! docker network ls --format "{{.Name}}" | grep -q "^letzgo-network$"; then
        log_warning "⚠️ letzgo-network does not exist, creating..."
        docker network create letzgo-network || log_error "Failed to create network"
    fi
    
    # Ensure all containers are on the correct network
    local containers=("letzgo-postgres" "letzgo-mongodb" "letzgo-redis" "letzgo-rabbitmq")
    for container in "${containers[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^$container$"; then
            local networks=$(docker inspect "$container" --format '{{range .NetworkSettings.Networks}}{{.NetworkID}} {{end}}' 2>/dev/null || echo "")
            if [[ "$networks" != *"letzgo-network"* ]]; then
                log_info "Connecting $container to letzgo-network..."
                docker network connect letzgo-network "$container" 2>/dev/null || log_warning "Failed to connect $container to network"
            fi
        fi
    done
    
    log_success "✅ Network connectivity checked"
    echo ""
}

# Main execution
main() {
    fix_network
    fix_postgresql
    fix_rabbitmq
    fix_mongodb
    fix_redis
    
    log_info "🔍 Running final verification..."
    
    # Final tests
    echo -e "${CYAN}=== Final Connection Tests ===${NC}"
    
    if docker exec letzgo-postgres pg_isready -U postgres -d letzgo >/dev/null 2>&1; then
        log_success "✅ PostgreSQL: Working"
    else
        log_error "❌ PostgreSQL: Still failing"
    fi
    
    if docker exec letzgo-rabbitmq rabbitmqctl status >/dev/null 2>&1; then
        log_success "✅ RabbitMQ: Working"
    else
        log_error "❌ RabbitMQ: Still failing"
    fi
    
    if docker exec letzgo-mongodb mongosh --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
        log_success "✅ MongoDB: Working"
    else
        log_error "❌ MongoDB: Still failing"
    fi
    
    if [ -n "$REDIS_PASSWORD" ] && docker exec letzgo-redis redis-cli --no-auth-warning -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
        log_success "✅ Redis: Working"
    else
        log_error "❌ Redis: Still failing"
    fi
    
    echo ""
    echo -e "${CYAN}============================================================================${NC}"
    echo -e "${GREEN}🎯 Database connection fix completed at $(date)${NC}"
    echo -e "${CYAN}============================================================================${NC}"
    echo ""
    echo "💡 If issues persist:"
    echo "   1. Run ./debug-infrastructure.sh for detailed diagnostics"
    echo "   2. Check container logs: docker logs <container-name>"
    echo "   3. Try redeploying infrastructure: ./deploy-infrastructure.sh --force-rebuild"
}

main "$@"
