#!/bin/bash

# Debug Infrastructure Issues
# This script helps diagnose PostgreSQL and RabbitMQ connection problems

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
echo "🔍 LetzGo Infrastructure Debug"
echo "============================================================================"
echo -e "${NC}"
echo "📅 Started: $(date)"
echo ""

# Check if containers exist and are running
log_info "🐳 Container Status:"
echo ""
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" | grep letzgo || echo "No letzgo containers found"
echo ""

# Check specific containers
containers=("letzgo-postgres" "letzgo-mongodb" "letzgo-redis" "letzgo-rabbitmq")

for container in "${containers[@]}"; do
    echo -e "${CYAN}=== $container ===${NC}"
    
    if docker ps -a --format "{{.Names}}" | grep -q "^$container$"; then
        # Container exists
        local status=$(docker ps -a --format "{{.Names}} {{.Status}}" | grep "^$container " | cut -d' ' -f2-)
        echo "Status: $status"
        
        # Check if running
        if docker ps --format "{{.Names}}" | grep -q "^$container$"; then
            log_success "✅ Container is running"
            
            # Check health if available
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no_healthcheck")
            if [ "$health" != "no_healthcheck" ]; then
                echo "Health: $health"
            fi
            
            # Show recent logs
            echo "Recent logs (last 10 lines):"
            docker logs "$container" --tail 10 2>/dev/null || echo "No logs available"
            
        else
            log_error "❌ Container is not running"
            echo "Recent logs (last 20 lines):"
            docker logs "$container" --tail 20 2>/dev/null || echo "No logs available"
        fi
    else
        log_error "❌ Container does not exist"
    fi
    echo ""
done

# Test specific database connections with more detail
echo -e "${CYAN}=== PostgreSQL Connection Test ===${NC}"
if docker ps --format "{{.Names}}" | grep -q "^letzgo-postgres$"; then
    echo "Testing pg_isready..."
    docker exec letzgo-postgres pg_isready -U postgres -d letzgo || echo "pg_isready failed"
    
    echo "Testing psql connection..."
    docker exec letzgo-postgres psql -U postgres -d letzgo -c "SELECT version();" 2>/dev/null || echo "psql connection failed"
    
    echo "Checking PostgreSQL process..."
    docker exec letzgo-postgres ps aux | grep postgres || echo "No PostgreSQL process found"
    
    echo "Checking PostgreSQL configuration..."
    docker exec letzgo-postgres cat /var/lib/postgresql/data/postgresql.conf | grep -E "listen_addresses|port" || echo "Config check failed"
else
    log_error "PostgreSQL container not running"
fi
echo ""

echo -e "${CYAN}=== RabbitMQ Connection Test ===${NC}"
if docker ps --format "{{.Names}}" | grep -q "^letzgo-rabbitmq$"; then
    echo "Testing rabbitmqctl status..."
    docker exec letzgo-rabbitmq rabbitmqctl status || echo "rabbitmqctl status failed"
    
    echo "Testing rabbitmqctl node_health_check..."
    docker exec letzgo-rabbitmq rabbitmqctl node_health_check || echo "node_health_check failed"
    
    echo "Checking RabbitMQ process..."
    docker exec letzgo-rabbitmq ps aux | grep rabbitmq || echo "No RabbitMQ process found"
    
    echo "Checking RabbitMQ ports..."
    docker exec letzgo-rabbitmq netstat -tlnp | grep -E ":5672|:15672" || echo "RabbitMQ ports not listening"
else
    log_error "RabbitMQ container not running"
fi
echo ""

# Check network
echo -e "${CYAN}=== Network Status ===${NC}"
if docker network ls --format "{{.Name}}" | grep -q "^letzgo-network$"; then
    log_success "✅ letzgo-network exists"
    echo "Connected containers:"
    docker network inspect letzgo-network --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "No containers connected"
else
    log_error "❌ letzgo-network does not exist"
fi
echo ""

# Check environment file
echo -e "${CYAN}=== Environment Configuration ===${NC}"
if [ -f "/opt/letzgo/.env" ]; then
    log_success "✅ Environment file exists"
    echo "Environment variables (passwords hidden):"
    grep -E "^(POSTGRES|MONGODB|REDIS|RABBITMQ)_" /opt/letzgo/.env | sed 's/=.*/=***/' || echo "No database variables found"
else
    log_error "❌ Environment file missing"
fi
echo ""

# Check Docker Compose file
echo -e "${CYAN}=== Docker Compose Configuration ===${NC}"
if [ -f "/opt/letzgo/docker-compose.infrastructure.yml" ]; then
    log_success "✅ Docker Compose file exists"
    echo "Services defined:"
    grep -E "^  [a-z-]+:" /opt/letzgo/docker-compose.infrastructure.yml || echo "No services found"
else
    log_error "❌ Docker Compose file missing"
fi
echo ""

# Check system resources
echo -e "${CYAN}=== System Resources ===${NC}"
echo "Memory usage:"
free -h 2>/dev/null || echo "Memory info not available"
echo ""
echo "Disk usage:"
df -h / 2>/dev/null || echo "Disk info not available"
echo ""
echo "Docker system info:"
docker system df 2>/dev/null || echo "Docker system info not available"
echo ""

echo -e "${CYAN}============================================================================${NC}"
echo -e "${GREEN}🎯 Debug completed at $(date)${NC}"
echo -e "${CYAN}============================================================================${NC}"
