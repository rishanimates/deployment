#!/bin/bash

# Diagnose Deployment Issues Script
# This script helps troubleshoot common deployment problems
# Usage: ./diagnose-deployment-issues.sh

set -e

echo "🔍 LetzGo Deployment Issues Diagnostic Tool"
echo "============================================"
echo "Timestamp: $(date)"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Function to check system basics
check_system() {
    log_info "🖥️ System Information:"
    echo "OS: $(uname -s)"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo "Home: $HOME"
    echo "Current directory: $(pwd)"
    echo ""
}

# Function to check Docker
check_docker() {
    log_info "🐳 Docker Status:"
    
    if command -v docker >/dev/null 2>&1; then
        log_success "✅ Docker is installed"
        docker --version
        
        if docker info >/dev/null 2>&1; then
            log_success "✅ Docker daemon is running"
            
            # Show Docker system info
            echo "Docker system info:"
            docker system df 2>/dev/null || echo "Could not get Docker system info"
            
            # Show running containers
            echo ""
            echo "Running containers:"
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Could not list containers"
            
            # Show networks
            echo ""
            echo "Docker networks:"
            docker network ls 2>/dev/null || echo "Could not list networks"
            
        else
            log_error "❌ Docker daemon is not running"
        fi
    else
        log_error "❌ Docker is not installed"
    fi
    echo ""
}

# Function to check Docker Compose
check_docker_compose() {
    log_info "🐙 Docker Compose Status:"
    
    if command -v docker-compose >/dev/null 2>&1; then
        log_success "✅ Docker Compose is installed"
        docker-compose --version
    else
        log_error "❌ Docker Compose is not installed"
    fi
    echo ""
}

# Function to check ports
check_ports() {
    log_info "🔌 Port Status:"
    
    local ports=("5432" "27017" "6379" "5672" "15672" "3000" "3001" "3002" "3003" "3004" "3005")
    
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            local process=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | head -1)
            echo "🔴 Port $port: IN USE ($process)"
        else
            echo "🟢 Port $port: Available"
        fi
    done
    echo ""
}

# Function to check deployment directory
check_deployment_directory() {
    log_info "📁 Deployment Directory Status:"
    
    local deploy_path="/opt/letzgo"
    
    if [ -d "$deploy_path" ]; then
        log_success "✅ Deployment directory exists: $deploy_path"
        
        echo "Directory contents:"
        ls -la "$deploy_path" 2>/dev/null || echo "Could not list directory contents"
        
        # Check key files
        echo ""
        echo "Key files:"
        
        if [ -f "$deploy_path/.env" ]; then
            echo "✅ Environment file exists"
            echo "   Size: $(stat -c%s "$deploy_path/.env" 2>/dev/null || stat -f%z "$deploy_path/.env" 2>/dev/null) bytes"
            echo "   Modified: $(stat -c%y "$deploy_path/.env" 2>/dev/null || stat -f%Sm "$deploy_path/.env" 2>/dev/null)"
        else
            echo "❌ Environment file missing"
        fi
        
        if [ -f "$deploy_path/docker-compose.yml" ]; then
            echo "✅ Docker Compose file exists"
        else
            echo "❌ Docker Compose file missing"
        fi
        
        if [ -d "$deploy_path/logs" ]; then
            echo "✅ Logs directory exists"
        else
            echo "❌ Logs directory missing"
        fi
        
        if [ -d "$deploy_path/uploads" ]; then
            echo "✅ Uploads directory exists"
        else
            echo "❌ Uploads directory missing"
        fi
        
    else
        log_error "❌ Deployment directory does not exist: $deploy_path"
    fi
    echo ""
}

# Function to check existing containers
check_existing_containers() {
    log_info "📦 Existing LetzGo Containers:"
    
    local containers=$(docker ps -a --format "{{.Names}}" | grep letzgo 2>/dev/null || echo "")
    
    if [ -n "$containers" ]; then
        echo "Found LetzGo containers:"
        while IFS= read -r container; do
            if [ -n "$container" ]; then
                local status=$(docker ps -a --format "{{.Names}} {{.Status}}" | grep "^$container " | cut -d' ' -f2- || echo "Unknown")
                echo "  $container: $status"
            fi
        done <<< "$containers"
        
        echo ""
        echo "Container details:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep letzgo || echo "No details available"
    else
        log_info "No existing LetzGo containers found"
    fi
    echo ""
}

# Function to check disk space
check_disk_space() {
    log_info "💾 Disk Space:"
    
    df -h / 2>/dev/null || echo "Could not get disk space info"
    echo ""
    
    # Check Docker disk usage
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        echo "Docker disk usage:"
        docker system df 2>/dev/null || echo "Could not get Docker disk usage"
    fi
    echo ""
}

# Function to check memory
check_memory() {
    log_info "🧠 Memory Usage:"
    
    free -h 2>/dev/null || echo "Could not get memory info"
    echo ""
}

# Function to check network connectivity
check_network() {
    log_info "🌐 Network Connectivity:"
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_success "✅ Internet connectivity working"
    else
        log_error "❌ No internet connectivity"
    fi
    
    # Check Docker Hub connectivity
    if ping -c 1 registry-1.docker.io >/dev/null 2>&1; then
        log_success "✅ Docker Hub connectivity working"
    else
        log_warning "⚠️ Docker Hub connectivity issues"
    fi
    
    echo ""
}

# Function to check permissions
check_permissions() {
    log_info "🔐 Permissions:"
    
    # Check if we can write to /opt
    if [ -w "/opt" ]; then
        log_success "✅ Can write to /opt"
    else
        log_warning "⚠️ Cannot write to /opt (may need sudo)"
    fi
    
    # Check if we can run Docker commands
    if docker ps >/dev/null 2>&1; then
        log_success "✅ Can run Docker commands"
    else
        log_warning "⚠️ Cannot run Docker commands (may need sudo or user in docker group)"
    fi
    
    echo ""
}

# Function to show recent logs
show_recent_logs() {
    log_info "📋 Recent Docker Logs:"
    
    local containers=$(docker ps -a --format "{{.Names}}" | grep letzgo 2>/dev/null || echo "")
    
    if [ -n "$containers" ]; then
        while IFS= read -r container; do
            if [ -n "$container" ]; then
                echo "--- Logs for $container (last 10 lines) ---"
                docker logs "$container" --tail 10 2>/dev/null || echo "Could not get logs for $container"
                echo ""
            fi
        done <<< "$containers"
    else
        log_info "No LetzGo containers found to show logs"
    fi
    echo ""
}

# Function to provide recommendations
provide_recommendations() {
    log_info "💡 Recommendations:"
    echo ""
    
    echo "To fix common issues:"
    echo ""
    
    echo "1. If Docker is not running:"
    echo "   sudo systemctl start docker"
    echo "   sudo systemctl enable docker"
    echo ""
    
    echo "2. If permission issues:"
    echo "   sudo usermod -aG docker \$USER"
    echo "   newgrp docker  # or logout and login again"
    echo ""
    
    echo "3. If ports are in use:"
    echo "   sudo netstat -tlnp | grep :<PORT>"
    echo "   sudo kill <PID>  # or stop the conflicting service"
    echo ""
    
    echo "4. If disk space is low:"
    echo "   docker system prune -f"
    echo "   docker volume prune -f"
    echo ""
    
    echo "5. To clean up existing LetzGo deployment:"
    echo "   docker stop \$(docker ps -q --filter name=letzgo)"
    echo "   docker rm \$(docker ps -aq --filter name=letzgo)"
    echo "   docker network rm letzgo-network"
    echo "   sudo rm -rf /opt/letzgo"
    echo ""
    
    echo "6. To run simple deployment:"
    echo "   curl -O https://your-repo/simple-infrastructure-deploy.sh"
    echo "   chmod +x simple-infrastructure-deploy.sh"
    echo "   ./simple-infrastructure-deploy.sh"
    echo ""
}

# Main execution
main() {
    echo "Starting comprehensive deployment diagnostic..."
    echo ""
    
    check_system
    check_docker
    check_docker_compose
    check_ports
    check_deployment_directory
    check_existing_containers
    check_disk_space
    check_memory
    check_network
    check_permissions
    show_recent_logs
    provide_recommendations
    
    echo "============================================"
    log_success "🎯 Diagnostic completed!"
    echo "============================================"
    
    echo ""
    echo "Next steps:"
    echo "1. Review the output above for any issues"
    echo "2. Follow the recommendations to fix problems"
    echo "3. Try running the simple deployment script"
    echo "4. If issues persist, share this diagnostic output for support"
}

# Execute main function
main "$@"
