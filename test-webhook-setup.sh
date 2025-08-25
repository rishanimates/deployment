#!/bin/bash

# ==============================================================================
# Test Webhook Setup
# Verify that all configurations are correct
# ==============================================================================

set -e

# --- Colors for logging ---
C_BLUE="\033[0;34m"
C_GREEN="\033[0;32m"
C_RED="\033[0;31m"
C_YELLOW="\033[0;33m"
C_RESET="\033[0m"

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

echo -e "${C_BLUE}===================================================${C_RESET}"
echo -e "${C_BLUE}    Testing Webhook Setup Configuration${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

# Test 1: Check service-repositories.json format
log_info "Testing service-repositories.json format..."

if [ -f "service-repositories.json" ]; then
    # Check if repositories are in owner/repo format (not full URLs)
    if grep -q "https://github.com" service-repositories.json; then
        log_error "Found HTTPS URLs in service-repositories.json - should be owner/repo format"
        log_info "Example: 'rishanimates/auth-service' not 'https://github.com/rishanimates/auth-service.git'"
        exit 1
    else
        log_success "Repository format is correct (owner/repo)"
    fi
    
    # Check if all services use develop branch
    if grep -q '"default_branch": "develop"' service-repositories.json; then
        log_success "Services configured for develop branch"
    else
        log_warning "Some services may not be configured for develop branch"
    fi
else
    log_error "service-repositories.json not found"
    exit 1
fi

# Test 2: Check webhook workflows
log_info "Testing webhook workflows..."

webhook_dir="service-webhook-workflows"
if [ -d "$webhook_dir" ]; then
    services=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")
    
    for service in "${services[@]}"; do
        webhook_file="$webhook_dir/${service}-webhook.yml"
        if [ -f "$webhook_file" ]; then
            # Check if webhook points to deployment repo
            if grep -q "repository: rishanimates/deployment" "$webhook_file"; then
                log_success "✅ $service webhook configured correctly"
            else
                log_error "❌ $service webhook has incorrect repository"
            fi
            
            # Check if service_repo is correct format
            if grep -q "\"service_repo\": \"rishanimates/$service\"" "$webhook_file"; then
                log_success "✅ $service repo format correct"
            else
                log_error "❌ $service repo format incorrect"
            fi
        else
            log_error "❌ $service webhook file missing"
        fi
    done
else
    log_error "service-webhook-workflows directory not found"
    exit 1
fi

# Test 3: Check main deployment workflows
log_info "Testing main deployment workflows..."

main_workflows="../.github/workflows"
if [ -d "$main_workflows" ]; then
    if [ -f "$main_workflows/auto-deploy-staging.yml" ]; then
        log_success "✅ Staging deployment workflow exists"
    else
        log_error "❌ Staging deployment workflow missing"
    fi
    
    if [ -f "$main_workflows/auto-deploy-production.yml" ]; then
        log_success "✅ Production deployment workflow exists"
    else
        log_error "❌ Production deployment workflow missing"
    fi
else
    log_error "Main workflows directory not found"
fi

# Test 4: Check setup script
log_info "Testing setup script..."

if [ -f "setup-service-webhooks.sh" ]; then
    if [ -x "setup-service-webhooks.sh" ]; then
        log_success "✅ Setup script is executable"
    else
        log_warning "⚠️  Setup script is not executable (run: chmod +x setup-service-webhooks.sh)"
    fi
    
    # Check if placeholders are replaced
    if grep -q "rishanimates" setup-service-webhooks.sh; then
        log_success "✅ Setup script configured with correct organization"
    else
        log_error "❌ Setup script placeholders not replaced"
    fi
else
    log_error "❌ setup-service-webhooks.sh not found"
fi

echo -e "\n${C_BLUE}===================================================${C_RESET}"
echo -e "${C_GREEN}    Configuration Test Summary${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

echo -e "\n${C_YELLOW}📋 Repository Configuration:${C_RESET}"
echo "• Organization: rishanimates"
echo "• Deployment repo: rishanimates/deployment"
echo "• Service repos: rishanimates/{service-name}"
echo "• Default branch: develop (staging)"

echo -e "\n${C_YELLOW}🔗 Webhook Flow:${C_RESET}"
echo "1. Service repo (develop) → Webhook triggers → Deployment repo"
echo "2. Deployment repo → Auto Deploy Staging → VPS (103.168.19.241)"

echo -e "\n${C_YELLOW}🚀 Next Steps:${C_RESET}"
echo "1. Add DEPLOYMENT_TOKEN to each service repository"
echo "2. Run setup-service-webhooks.sh in each service repository"
echo "3. Test by pushing to develop branch in any service"

echo -e "\n${C_GREEN}✅ Webhook setup test completed!${C_RESET}"
