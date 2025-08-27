#!/bin/bash

# Deploy Infrastructure via GitHub Actions
# This script is called by GitHub Actions to deploy infrastructure with proper error handling
# Usage: ./deploy-infrastructure-via-actions.sh [force_rebuild]

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

# Main function to deploy infrastructure
deploy_infrastructure() {
    local force_rebuild="$1"
    local deploy_path="/opt/letzgo"
    
    log_info "🚀 Starting fresh infrastructure deployment via GitHub Actions..."
    log_info "Environment: staging"
    log_info "Force rebuild: $force_rebuild"
    log_info "Deploy path: $deploy_path"
    echo ""
    
    # Check for port conflicts
    log_info "🔍 Checking for port conflicts..."
    if netstat -tlnp 2>/dev/null | grep -E ":(5432|27017|6379|5672|15672|8090) " >/dev/null; then
        log_warning "⚠️ Some ports may be in use - will attempt deployment anyway"
        netstat -tlnp 2>/dev/null | grep -E ":(5432|27017|6379|5672|15672|8090) " | head -5
    else
        log_success "✅ No port conflicts found"
    fi
    echo ""
    
    # Extract infrastructure files if they exist
    if [ -f "/tmp/letzgo-infrastructure.tar.gz" ]; then
        log_info "📦 Extracting infrastructure files..."
        cd /tmp
        tar -xzf letzgo-infrastructure.tar.gz
        
        # Create deployment directory
        mkdir -p "$deploy_path"
        
        # Copy infrastructure files
        cp -r /tmp/letzgo-infrastructure/* "$deploy_path/"
        
        # Make scripts executable
        chmod +x "$deploy_path"/*.sh 2>/dev/null || true
        chmod +x "$deploy_path"/scripts/*.sh 2>/dev/null || true
        
        log_success "✅ Infrastructure files extracted and permissions set"
    else
        log_warning "⚠️ No infrastructure archive found - using existing files"
    fi
    
    # Change to deployment directory
    cd "$deploy_path"
    
    # Call the main deployment script
    if [ -f "./deploy-infrastructure.sh" ]; then
        log_info "🔧 Calling main infrastructure deployment script..."
        echo ""
        
        # Execute the deployment script with proper error handling
        if ./deploy-infrastructure.sh "$force_rebuild"; then
            log_success "✅ Infrastructure deployment script completed successfully"
        else
            local exit_code=$?
            log_error "❌ Infrastructure deployment script failed with exit code: $exit_code"
            
            # Show recent logs for debugging
            log_info "📋 Recent Docker logs for debugging:"
            docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep letzgo | head -10
            echo ""
            
            # Show network status
            log_info "📋 Network status:"
            docker network ls | grep letzgo || echo "No letzgo networks found"
            echo ""
            
            return $exit_code
        fi
    else
        log_error "❌ deploy-infrastructure.sh script not found"
        log_info "📋 Available files:"
        ls -la "$deploy_path"
        return 1
    fi
    
    echo ""
    log_success "🎉 Fresh infrastructure deployment completed successfully via GitHub Actions!"
    log_info "📱 Infrastructure is ready for service deployment"
    
    # Final status check
    log_info "📊 Final Infrastructure Status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep letzgo | head -10
    echo ""
    
    # Show network status
    log_info "🌐 Network Status:"
    docker network ls | grep letzgo
    echo ""
    
    # Show database connectivity
    log_info "🗄️ Database Connectivity Check:"
    if docker exec letzgo-postgres pg_isready -U postgres -d letzgo >/dev/null 2>&1; then
        echo "✅ PostgreSQL ready"
    else
        echo "❌ PostgreSQL not ready"
    fi
    
    if docker exec letzgo-mongodb mongosh --eval 'db.adminCommand("ping")' >/dev/null 2>&1; then
        echo "✅ MongoDB ready"
    else
        echo "❌ MongoDB not ready"
    fi
    
    if docker exec letzgo-redis redis-cli ping >/dev/null 2>&1; then
        echo "✅ Redis ready"
    else
        echo "❌ Redis not ready"
    fi
    
    if docker exec letzgo-rabbitmq rabbitmqctl status >/dev/null 2>&1; then
        echo "✅ RabbitMQ ready"
    else
        echo "❌ RabbitMQ not ready"
    fi
    
    echo ""
    log_success "🎯 Infrastructure deployment via GitHub Actions completed successfully!"
    
    return 0
}

# Error handling function
handle_error() {
    local exit_code=$?
    log_error "❌ Infrastructure deployment failed with exit code: $exit_code"
    
    log_info "📋 Debug Information:"
    echo "Working directory: $(pwd)"
    echo "Available files:"
    ls -la 2>/dev/null || echo "Cannot list files"
    echo ""
    echo "Docker containers:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | head -10 || echo "Cannot list containers"
    echo ""
    echo "Docker networks:"
    docker network ls 2>/dev/null | head -10 || echo "Cannot list networks"
    
    exit $exit_code
}

# Set up error handling
trap handle_error ERR

# Main execution
main() {
    local force_rebuild="${1:-false}"
    
    log_info "🏗️ GitHub Actions Infrastructure Deployment Script"
    log_info "📊 Parameters:"
    echo "  Force rebuild: $force_rebuild"
    echo "  Environment: staging"
    echo "  Deploy path: /opt/letzgo"
    echo ""
    
    # Deploy infrastructure
    deploy_infrastructure "$force_rebuild"
    
    log_success "🎉 All operations completed successfully!"
}

# Execute main function with all arguments
main "$@"
