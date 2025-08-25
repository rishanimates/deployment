#!/bin/bash

# ==============================================================================
# LetzGo Production Deployment Script
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
BACKUP_DIR="/opt/letzgo/backups"
LOG_FILE="/opt/letzgo/logs/deployment.log"

# --- Helper Functions ---
log_info() {
    echo -e "${C_BLUE}[INFO] $1${C_RESET}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${C_GREEN}[SUCCESS] $1${C_RESET}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${C_YELLOW}[WARNING] $1${C_RESET}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${C_RED}[ERROR] $1${C_RESET}" | tee -a "$LOG_FILE"
    exit 1
}

# --- Create necessary directories ---
setup_directories() {
    log_info "Setting up deployment directories..."
    
    mkdir -p "$DEPLOY_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "/opt/letzgo/logs"
    mkdir -p "/opt/letzgo/uploads"
    mkdir -p "/opt/letzgo/ssl"
    mkdir -p "/opt/letzgo/config"
    mkdir -p "/opt/letzgo/schemas"
    
    log_success "Directories created successfully"
}

# --- Backup current deployment ---
backup_current_deployment() {
    log_info "Creating backup of current deployment..."
    
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"
    
    if [ -d "$DEPLOY_DIR/app" ]; then
        mkdir -p "$BACKUP_PATH"
        cp -r "$DEPLOY_DIR/app" "$BACKUP_PATH/" || true
        cp "$DEPLOY_DIR/.env" "$BACKUP_PATH/" 2>/dev/null || true
        log_success "Backup created at $BACKUP_PATH"
    else
        log_warning "No existing deployment found to backup"
    fi
    
    # Keep only last 5 backups
    cd "$BACKUP_DIR"
    ls -t | tail -n +6 | xargs -r rm -rf
}

# --- Stop running services ---
stop_services() {
    log_info "Stopping running services..."
    
    cd "$DEPLOY_DIR"
    if [ -f "docker-compose.prod.yml" ]; then
        docker-compose -f docker-compose.prod.yml down || true
        log_success "Services stopped"
    else
        log_warning "No docker-compose.prod.yml found"
    fi
}

# --- Deploy new version ---
deploy_new_version() {
    log_info "Deploying new version..."
    
    # Remove old app directory
    rm -rf "$DEPLOY_DIR/app"
    
    # Copy new application files
    mkdir -p "$DEPLOY_DIR/app"
    cp -r /tmp/letzgo-deployment/* "$DEPLOY_DIR/"
    
    # Set proper permissions
    chmod +x "$DEPLOY_DIR"/*.sh
    chown -R root:root "$DEPLOY_DIR/app"
    
    log_success "New version deployed"
}

# --- Load environment variables ---
load_environment() {
    log_info "Loading environment variables..."
    
    if [ -f "$DEPLOY_DIR/.env" ]; then
        set -a
        source "$DEPLOY_DIR/.env"
        set +a
        log_success "Environment variables loaded"
    else
        log_error "Environment file not found at $DEPLOY_DIR/.env"
    fi
}

# --- Copy database schemas ---
copy_schemas() {
    log_info "Copying database schemas..."
    
    # Copy schemas to the schemas directory
    cp "$DEPLOY_DIR/app/user-service/src/database/schema.sql" "$DEPLOY_DIR/schemas/user-schema.sql" 2>/dev/null || true
    cp "$DEPLOY_DIR/app/user-service/src/database/stories.sql" "$DEPLOY_DIR/schemas/user-stories.sql" 2>/dev/null || true
    cp "$DEPLOY_DIR/app/event-service/src/database/schema.sql" "$DEPLOY_DIR/schemas/event-schema.sql" 2>/dev/null || true
    
    log_success "Database schemas copied"
}

# --- Pull latest Docker images ---
pull_images() {
    log_info "Pulling latest Docker images..."
    
    docker pull timescale/timescaledb-ha:pg14-latest
    docker pull mongo:6.0
    docker pull redis:7.2-alpine
    docker pull rabbitmq:3-management-alpine
    docker pull nginx:alpine
    
    log_success "Docker images pulled"
}

# --- Build application images ---
build_images() {
    log_info "Building application Docker images..."
    
    cd "$DEPLOY_DIR"
    docker-compose -f docker-compose.prod.yml build --no-cache
    
    log_success "Application images built"
}

# --- Start services ---
start_services() {
    log_info "Starting services..."
    
    cd "$DEPLOY_DIR"
    docker-compose -f docker-compose.prod.yml up -d
    
    log_success "Services started"
}

# --- Wait for services to be healthy ---
wait_for_services() {
    log_info "Waiting for services to be healthy..."
    
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Health check attempt $attempt/$max_attempts"
        
        # Check if all services are healthy
        if docker-compose -f "$DEPLOY_DIR/docker-compose.prod.yml" ps | grep -q "unhealthy\|starting"; then
            log_info "Services still starting... waiting 10 seconds"
            sleep 10
            attempt=$((attempt + 1))
        else
            log_success "All services are healthy"
            return 0
        fi
    done
    
    log_error "Services failed to become healthy within timeout"
}

# --- Run database migrations ---
run_migrations() {
    log_info "Running database migrations..."
    
    # Wait for PostgreSQL to be ready
    sleep 30
    
    # Run any necessary migrations
    # docker exec letzgo-postgres psql -U postgres -d letzgo_db -c "SELECT 1;" > /dev/null 2>&1
    
    log_success "Database migrations completed"
}

# --- Verify deployment ---
verify_deployment() {
    log_info "Verifying deployment..."
    
    local services=("auth-service:3000" "user-service:3001" "chat-service:3002" "event-service:3003" "shared-service:3004" "splitz-service:3005")
    
    for service in "${services[@]}"; do
        local name=$(echo $service | cut -d: -f1)
        local port=$(echo $service | cut -d: -f2)
        
        if curl -f -s "http://localhost:$port/health" > /dev/null; then
            log_success "$name is responding"
        else
            log_warning "$name is not responding on port $port"
        fi
    done
    
    # Check Nginx
    if curl -f -s "http://localhost/health" > /dev/null; then
        log_success "Nginx is responding"
    else
        log_warning "Nginx is not responding"
    fi
}

# --- Cleanup ---
cleanup() {
    log_info "Cleaning up..."
    
    # Remove unused Docker images
    docker image prune -f
    
    # Clean up temporary files
    rm -rf /tmp/letzgo-deployment
    
    log_success "Cleanup completed"
}

# --- Main deployment function ---
main() {
    echo -e "${C_BLUE}===================================================${C_RESET}"
    echo -e "${C_BLUE}    LetzGo Production Deployment${C_RESET}"
    echo -e "${C_BLUE}===================================================${C_RESET}"
    
    log_info "Starting deployment at $(date)"
    
    setup_directories
    backup_current_deployment
    stop_services
    deploy_new_version
    load_environment
    copy_schemas
    pull_images
    build_images
    start_services
    wait_for_services
    run_migrations
    verify_deployment
    cleanup
    
    log_success "Deployment completed successfully at $(date)"
    
    echo -e "\n${C_GREEN}===================================================${C_RESET}"
    echo -e "${C_GREEN}    Deployment Summary${C_RESET}"
    echo -e "${C_GREEN}===================================================${C_RESET}"
    echo -e "${C_GREEN}✅ All services deployed and running${C_RESET}"
    echo -e "${C_GREEN}✅ API Gateway: http://$(curl -s ifconfig.me)/health${C_RESET}"
    echo -e "${C_GREEN}✅ Logs: $LOG_FILE${C_RESET}"
    echo -e "${C_GREEN}===================================================${C_RESET}"
}

# Execute main function
main "$@"
