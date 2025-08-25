#!/bin/bash

# ==============================================================================
# LetzGo Port Cleanup Script
# Stops conflicting services and containers using required ports
# ==============================================================================

set -e

# --- Colors for logging ---
C_BLUE="\033[0;34m"
C_GREEN="\033[0;32m"
C_RED="\033[0;31m"
C_YELLOW="\033[0;33m"
C_RESET="\033[0m"

# --- Required ports ---
REQUIRED_PORTS=(5432 27017 6379 5672 15672)
PORT_SERVICES=("PostgreSQL" "MongoDB" "Redis" "RabbitMQ" "RabbitMQ Management")

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

# --- Check what's using ports ---
check_port_usage() {
    log_info "Checking port usage..."
    
    for i in "${!REQUIRED_PORTS[@]}"; do
        port="${REQUIRED_PORTS[$i]}"
        service="${PORT_SERVICES[$i]}"
        
        echo -e "\n${C_YELLOW}Port $port ($service):${C_RESET}"
        
        # Check if port is in use
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_warning "Port $port is in use:"
            netstat -tlnp 2>/dev/null | grep ":$port " || true
        else
            log_success "Port $port is available"
        fi
    done
}

# --- Stop conflicting Docker containers ---
stop_conflicting_containers() {
    log_info "Stopping conflicting Docker containers..."
    
    # Stop any containers using our required ports
    CONFLICTING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "5432|27017|6379|5672|15672" | awk '{print $1}' | grep -v NAMES || true)
    
    if [ -n "$CONFLICTING_CONTAINERS" ]; then
        echo "Found conflicting containers:"
        echo "$CONFLICTING_CONTAINERS"
        
        for container in $CONFLICTING_CONTAINERS; do
            log_info "Stopping container: $container"
            docker stop "$container" || true
            docker rm "$container" || true
        done
        log_success "Conflicting containers stopped"
    else
        log_info "No conflicting Docker containers found"
    fi
}

# --- Stop system services ---
stop_system_services() {
    log_info "Stopping system database services..."
    
    # Common system services that might conflict
    SERVICES=("postgresql" "postgres" "mongod" "mongodb" "redis-server" "redis" "rabbitmq-server")
    
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_warning "Stopping system service: $service"
            systemctl stop "$service" || true
            systemctl disable "$service" || true
        fi
    done
}

# --- Kill processes using ports ---
kill_port_processes() {
    log_info "Killing processes using required ports..."
    
    for port in "${REQUIRED_PORTS[@]}"; do
        # Find processes using the port
        PIDS=$(lsof -ti:$port 2>/dev/null || true)
        
        if [ -n "$PIDS" ]; then
            log_warning "Killing processes using port $port: $PIDS"
            echo "$PIDS" | xargs kill -9 2>/dev/null || true
        fi
    done
}

# --- Clean up Docker networks ---
cleanup_docker_networks() {
    log_info "Cleaning up Docker networks..."
    
    # Remove any existing letzgo network
    docker network rm letzgo-network 2>/dev/null || true
    
    # Prune unused networks
    docker network prune -f || true
    
    log_success "Docker networks cleaned up"
}

# --- Clean up Docker volumes ---
cleanup_docker_volumes() {
    log_info "Cleaning up old Docker volumes..."
    
    # List existing letzgo volumes
    LETZGO_VOLUMES=$(docker volume ls -q | grep letzgo || true)
    
    if [ -n "$LETZGO_VOLUMES" ]; then
        log_warning "Found existing LetzGo volumes:"
        echo "$LETZGO_VOLUMES"
        
        read -p "Do you want to remove these volumes? This will DELETE ALL DATA! (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$LETZGO_VOLUMES" | xargs docker volume rm 2>/dev/null || true
            log_success "Old volumes removed"
        else
            log_info "Keeping existing volumes"
        fi
    else
        log_info "No existing LetzGo volumes found"
    fi
}

# --- Verify ports are free ---
verify_ports_free() {
    log_info "Verifying ports are now free..."
    
    all_free=true
    for i in "${!REQUIRED_PORTS[@]}"; do
        port="${REQUIRED_PORTS[$i]}"
        service="${PORT_SERVICES[$i]}"
        
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_error "Port $port ($service) is still in use!"
            netstat -tlnp 2>/dev/null | grep ":$port "
            all_free=false
        else
            log_success "Port $port ($service) is free"
        fi
    done
    
    if [ "$all_free" = true ]; then
        log_success "All required ports are now available!"
        return 0
    else
        log_error "Some ports are still in use. You may need to reboot the server."
        return 1
    fi
}

# --- Main function ---
main() {
    echo -e "${C_BLUE}===================================================${C_RESET}"
    echo -e "${C_BLUE}    LetzGo Port Cleanup Script${C_RESET}"
    echo -e "${C_BLUE}===================================================${C_RESET}"
    echo
    
    log_info "Required ports: ${REQUIRED_PORTS[*]}"
    echo
    
    check_port_usage
    
    echo
    log_warning "This script will stop services and containers using required ports."
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled."
        exit 0
    fi
    
    stop_conflicting_containers
    stop_system_services
    kill_port_processes
    cleanup_docker_networks
    cleanup_docker_volumes
    
    echo
    log_info "Waiting 5 seconds for processes to fully stop..."
    sleep 5
    
    verify_ports_free
    
    echo
    log_success "Port cleanup completed!"
    echo
    log_info "You can now run the deployment script:"
    echo "  cd /opt/letzgo && ./deploy-infrastructure.sh"
}

# Execute main function
main "$@"
