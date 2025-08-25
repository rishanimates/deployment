#!/bin/bash

# ==============================================================================
# Debug Stuck Deployment Script
# ==============================================================================

set -e

# --- Colors for logging ---
C_BLUE="\033[0;34m"
C_GREEN="\033[0;32m"
C_RED="\033[0;31m"
C_YELLOW="\033[0;33m"
C_RESET="\033[0m"

# --- Configuration ---
DEPLOY_DIR="/opt/letzgo"

# --- Helper Functions ---
log_info() {
    echo -e "${C_BLUE}[INFO] $1${C_RESET}"
}

log_success() {
    echo -e "${C_GREEN}[SUCCESS] $1${C_RESET}"
}

log_warning() {
    echo -e "${C_YELLOW}[WARNING] $1${C_RESET}"
}

log_error() {
    echo -e "${C_RED}[ERROR] $1${C_RESET}"
}

# --- Debug current state ---
debug_current_state() {
    echo -e "${C_BLUE}===================================================${C_RESET}"
    echo -e "${C_BLUE}    LetzGo Deployment Debug${C_RESET}"
    echo -e "${C_BLUE}===================================================${C_RESET}"
    
    log_info "Current working directory: $(pwd)"
    log_info "Checking deployment status..."
    
    # Check if docker-compose file exists
    if [ -f "$DEPLOY_DIR/docker-compose.infrastructure.yml" ]; then
        log_success "Infrastructure compose file found"
        
        # Show current service status
        log_info "Current service status:"
        docker-compose -f "$DEPLOY_DIR/docker-compose.infrastructure.yml" ps
        
        # Check individual container status
        log_info "Individual container status:"
        docker ps --filter "name=letzgo-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        # Check container health
        log_info "Container health status:"
        docker ps --filter "name=letzgo-" --format "table {{.Names}}\t{{.Status}}" | grep -E "healthy|unhealthy|starting" || echo "No health status found"
        
        # Show recent logs
        log_info "Recent container logs (last 10 lines each):"
        containers=("letzgo-postgres" "letzgo-mongodb" "letzgo-redis" "letzgo-rabbitmq")
        
        for container in "${containers[@]}"; do
            if docker ps --filter "name=$container" --format "{{.Names}}" | grep -q "$container"; then
                echo -e "\n${C_YELLOW}=== $container logs ===${C_RESET}"
                docker logs "$container" --tail 10 2>&1 || echo "No logs available"
            else
                echo -e "\n${C_RED}=== $container: NOT RUNNING ===${C_RESET}"
            fi
        done
        
    else
        log_error "Infrastructure compose file not found at $DEPLOY_DIR/docker-compose.infrastructure.yml"
    fi
}

# --- Check port usage ---
check_ports() {
    log_info "Checking port usage:"
    
    ports=(5432 27017 6379 5672 15672)
    port_names=("PostgreSQL" "MongoDB" "Redis" "RabbitMQ" "RabbitMQ-Mgmt")
    
    for i in "${!ports[@]}"; do
        port="${ports[$i]}"
        name="${port_names[$i]}"
        
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "${C_GREEN}Port $port ($name): IN USE${C_RESET}"
            netstat -tlnp 2>/dev/null | grep ":$port " | head -1
        else
            echo -e "${C_RED}Port $port ($name): FREE${C_RESET}"
        fi
    done
}

# --- Check disk space ---
check_resources() {
    log_info "System resources:"
    
    # Disk space
    echo -e "${C_YELLOW}Disk usage:${C_RESET}"
    df -h / | head -2
    
    # Memory usage
    echo -e "${C_YELLOW}Memory usage:${C_RESET}"
    free -h
    
    # Docker system info
    echo -e "${C_YELLOW}Docker system info:${C_RESET}"
    docker system df || true
}

# --- Suggest fixes ---
suggest_fixes() {
    log_info "Suggested fixes:"
    
    echo "1. Kill the stuck deployment:"
    echo "   pkill -f deploy-infrastructure.sh"
    echo
    echo "2. Stop all containers and restart:"
    echo "   cd $DEPLOY_DIR"
    echo "   docker-compose -f docker-compose.infrastructure.yml down"
    echo "   docker-compose -f docker-compose.infrastructure.yml up -d"
    echo
    echo "3. Check individual container logs:"
    echo "   docker logs letzgo-postgres"
    echo "   docker logs letzgo-mongodb"
    echo "   docker logs letzgo-redis"
    echo "   docker logs letzgo-rabbitmq"
    echo
    echo "4. Manual health check:"
    echo "   docker exec letzgo-postgres pg_isready -U postgres"
    echo "   docker exec letzgo-mongodb mongosh --eval 'db.adminCommand(\"ping\")'"
    echo "   docker exec letzgo-redis redis-cli ping"
    echo
    echo "5. Restart deployment with fixed script:"
    echo "   cd $DEPLOY_DIR"
    echo "   ./deploy-infrastructure.sh"
}

# --- Quick fix option ---
quick_fix() {
    log_warning "Quick fix option: Restart infrastructure services"
    read -p "Do you want to restart the infrastructure services? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Stopping current services..."
        cd "$DEPLOY_DIR"
        docker-compose -f docker-compose.infrastructure.yml down || true
        
        log_info "Waiting 5 seconds..."
        sleep 5
        
        log_info "Starting services..."
        docker-compose -f docker-compose.infrastructure.yml up -d
        
        log_info "Waiting 30 seconds for services to start..."
        sleep 30
        
        log_info "Checking service status:"
        docker-compose -f docker-compose.infrastructure.yml ps
        
        log_success "Quick fix completed!"
    else
        log_info "Quick fix cancelled"
    fi
}

# --- Main function ---
main() {
    debug_current_state
    echo
    check_ports
    echo
    check_resources
    echo
    suggest_fixes
    echo
    quick_fix
}

# Execute main function
main "$@"
