#!/bin/bash

# LetzGo Deployment Verification Script
# This script verifies that the deployment is working correctly

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_banner() {
    echo -e "${CYAN}"
    echo "============================================================================"
    echo "🔍 LetzGo Deployment Verification"
    echo "============================================================================"
    echo -e "${NC}"
    echo "📅 Started: $(date)"
    echo ""
}

# Check infrastructure containers
check_infrastructure() {
    echo -e "${CYAN}🏗️ Infrastructure Status${NC}"
    echo ""
    
    local containers=("letzgo-postgres" "letzgo-mongodb" "letzgo-redis" "letzgo-rabbitmq")
    local running_count=0
    
    for container in "${containers[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^$container$"; then
            log_success "✅ $container: Running"
            running_count=$((running_count + 1))
        else
            log_error "❌ $container: Not running"
        fi
    done
    
    echo ""
    echo "Infrastructure Status: $running_count/${#containers[@]} containers running"
    echo ""
    
    return $running_count
}

# Check services
check_services() {
    echo -e "${CYAN}🚀 Services Status${NC}"
    echo ""
    
    local services=("auth-service:3000" "user-service:3001" "chat-service:3002" "event-service:3003" "shared-service:3004" "splitz-service:3005")
    local healthy_count=0
    
    for service_port in "${services[@]}"; do
        local service=$(echo "$service_port" | cut -d':' -f1)
        local port=$(echo "$service_port" | cut -d':' -f2)
        local container_name="letzgo-$service"
        
        # Check if container is running
        if docker ps --format "{{.Names}}" | grep -q "^$container_name$"; then
            # Check health endpoint
            if curl -f -s --connect-timeout 3 "http://localhost:$port/health" >/dev/null 2>&1; then
                log_success "✅ $service: Running and healthy"
                healthy_count=$((healthy_count + 1))
            else
                log_warning "⚠️ $service: Running but unhealthy"
            fi
        else
            log_error "❌ $service: Not running"
        fi
    done
    
    echo ""
    echo "Services Status: $healthy_count/${#services[@]} services healthy"
    echo ""
    
    return $healthy_count
}

# Check network
check_network() {
    echo -e "${CYAN}🌐 Network Status${NC}"
    echo ""
    
    if docker network ls --format "{{.Name}}" | grep -q "^letzgo-network$"; then
        log_success "✅ letzgo-network: Exists"
        
        # Check connected containers
        local connected_containers=$(docker network inspect letzgo-network --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")
        if [ -n "$connected_containers" ]; then
            log_info "Connected containers: $connected_containers"
        else
            log_warning "No containers connected to network"
        fi
    else
        log_error "❌ letzgo-network: Not found"
    fi
    
    echo ""
}

# Check database connectivity
check_databases() {
    echo -e "${CYAN}🗄️ Database Connectivity${NC}"
    echo ""
    
    # PostgreSQL
    if docker exec letzgo-postgres pg_isready -U postgres -d letzgo >/dev/null 2>&1; then
        log_success "✅ PostgreSQL: Connected"
        
        # Check table count
        local table_count=$(docker exec letzgo-postgres psql -U postgres -d letzgo -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ' || echo "0")
        log_info "PostgreSQL tables: $table_count"
    else
        log_error "❌ PostgreSQL: Connection failed"
    fi
    
    # MongoDB
    if docker exec letzgo-mongodb mongosh --quiet --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
        log_success "✅ MongoDB: Connected"
        
        # Check collection count
        local collection_count=$(docker exec letzgo-mongodb mongosh letzgo --quiet --eval "db.getCollectionNames().length" 2>/dev/null || echo "0")
        log_info "MongoDB collections: $collection_count"
    else
        log_error "❌ MongoDB: Connection failed"
    fi
    
    # Redis
    local redis_password=$(grep REDIS_PASSWORD /opt/letzgo/.env 2>/dev/null | cut -d'=' -f2 || echo "")
    if [ -n "$redis_password" ]; then
        if docker exec letzgo-redis redis-cli --no-auth-warning -a "$redis_password" ping >/dev/null 2>&1; then
            log_success "✅ Redis: Connected"
        else
            log_error "❌ Redis: Connection failed"
        fi
    else
        log_warning "⚠️ Redis: Password not found"
    fi
    
    # RabbitMQ
    if docker exec letzgo-rabbitmq rabbitmqctl status >/dev/null 2>&1; then
        log_success "✅ RabbitMQ: Connected"
    else
        log_error "❌ RabbitMQ: Connection failed"
    fi
    
    echo ""
}

# Check files
check_files() {
    echo -e "${CYAN}📁 File Status${NC}"
    echo ""
    
    local files=("/opt/letzgo/.env" "/opt/letzgo/docker-compose.infrastructure.yml")
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            log_success "✅ $(basename "$file"): Exists"
        else
            log_error "❌ $(basename "$file"): Missing"
        fi
    done
    
    echo ""
}

# Display URLs
display_urls() {
    echo -e "${CYAN}🔗 Service URLs${NC}"
    echo ""
    
    echo "Infrastructure:"
    echo "  PostgreSQL: postgresql://postgres:***@103.168.19.241:5432/letzgo"
    echo "  MongoDB: mongodb://admin:***@103.168.19.241:27017/letzgo"
    echo "  Redis: redis://:***@103.168.19.241:6379"
    echo "  RabbitMQ Management: http://103.168.19.241:15672"
    echo ""
    
    echo "Services:"
    echo "  Auth Service: http://103.168.19.241:3000"
    echo "  User Service: http://103.168.19.241:3001"
    echo "  Chat Service: http://103.168.19.241:3002"
    echo "  Event Service: http://103.168.19.241:3003"
    echo "  Shared Service: http://103.168.19.241:3004"
    echo "  Splitz Service: http://103.168.19.241:3005"
    echo ""
}

# Main execution
main() {
    print_banner
    
    local total_score=0
    local max_score=4
    
    # Run checks
    if check_infrastructure; then
        total_score=$((total_score + 1))
    fi
    
    if check_services; then
        total_score=$((total_score + 1))
    fi
    
    check_network
    check_databases
    check_files
    display_urls
    
    # Final summary
    echo -e "${CYAN}📊 Verification Summary${NC}"
    echo ""
    
    if [ $total_score -eq $max_score ]; then
        echo -e "${GREEN}🎉 Deployment Status: EXCELLENT${NC}"
        echo "✅ All infrastructure and services are running perfectly!"
    elif [ $total_score -ge 2 ]; then
        echo -e "${YELLOW}⚠️ Deployment Status: PARTIAL${NC}"
        echo "Some components may need attention."
    else
        echo -e "${RED}❌ Deployment Status: ISSUES DETECTED${NC}"
        echo "Multiple components need attention."
    fi
    
    echo ""
    echo "📅 Verification completed: $(date)"
    echo ""
    
    if [ $total_score -lt $max_score ]; then
        exit 1
    fi
}

main "$@"
