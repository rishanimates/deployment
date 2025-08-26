#!/bin/bash

# ==============================================================================
# Verify Repository Format Fix
# Check all workflows for correct owner/repo format
# ==============================================================================

set -e

# --- Colors for logging ---
C_BLUE="\033[0;34m"
C_GREEN="\033[0;32m"
C_RED="\033[0;31m"
C_YELLOW="\033[0;33m"
C_RESET="\033[0m"

log_info() {
    echo -e "${C_BLUE}[INFO] $1${C_RESET}"
}

log_success() {
    echo -e "${C_GREEN}[SUCCESS] $1${C_RESET}"
}

log_error() {
    echo -e "${C_RED}[ERROR] $1${C_RESET}"
}

echo -e "${C_BLUE}===================================================${C_RESET}"
echo -e "${C_BLUE}    Repository Format Verification${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

# Check for HTTPS URLs in any workflow files
log_info "Checking for HTTPS URLs in workflow files..."

HTTPS_FOUND=false
WORKFLOW_DIRS=("../.github/workflows" ".github/workflows" "service-webhook-workflows")

for dir in "${WORKFLOW_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log_info "Checking directory: $dir"
        
        # Check for HTTPS URLs
        HTTPS_FILES=$(find "$dir" -name "*.yml" -exec grep -l "https://github.com" {} \; 2>/dev/null)
        if [ -n "$HTTPS_FILES" ]; then
            log_error "❌ Found HTTPS URLs in workflow files in $dir"
            echo "$HTTPS_FILES" | while read file; do
                echo "  File: $file"
                grep -n "https://github.com" "$file" 2>/dev/null | head -3
            done
            HTTPS_FOUND=true
        else
            log_success "✅ No HTTPS URLs found in $dir"
        fi
    fi
done

if [ "$HTTPS_FOUND" = true ]; then
    echo -e "\n${C_RED}❌ Repository format issues found!${C_RESET}"
    echo -e "${C_YELLOW}Fix: Replace HTTPS URLs with owner/repo format${C_RESET}"
    echo -e "${C_YELLOW}Example: 'rishanimates/auth-service' not 'https://github.com/rishanimates/auth-service.git'${C_RESET}"
    exit 1
fi

# Check service-repositories.json
log_info "Checking service-repositories.json..."

if [ -f "service-repositories.json" ]; then
    if grep -q "https://github.com" service-repositories.json; then
        log_error "❌ HTTPS URLs found in service-repositories.json"
        exit 1
    else
        log_success "✅ service-repositories.json uses correct format"
    fi
else
    log_error "❌ service-repositories.json not found"
    exit 1
fi

# Verify specific workflows
log_info "Verifying specific workflow configurations..."

# Check multi-repo workflow
MULTI_REPO_WORKFLOW="../.github/workflows/deploy-services-multi-repo.yml"
if [ -f "$MULTI_REPO_WORKFLOW" ]; then
    if grep -q 'rishanimates/auth-service' "$MULTI_REPO_WORKFLOW" && ! grep -q 'https://github.com' "$MULTI_REPO_WORKFLOW"; then
        log_success "✅ Multi-repository workflow uses correct format"
    else
        log_error "❌ Multi-repository workflow has format issues"
        exit 1
    fi
else
    log_error "❌ Multi-repository workflow not found"
fi

# Check staging workflow
STAGING_WORKFLOW="../.github/workflows/auto-deploy-staging.yml"
if [ -f "$STAGING_WORKFLOW" ]; then
    # This workflow should use variables, not hardcoded repos
    if ! grep -q 'https://github.com' "$STAGING_WORKFLOW"; then
        log_success "✅ Staging deployment workflow is clean"
    else
        log_error "❌ Staging deployment workflow has HTTPS URLs"
        exit 1
    fi
else
    log_error "❌ Staging deployment workflow not found"
fi

# Check webhook workflows
log_info "Verifying webhook workflows..."

WEBHOOK_DIR="service-webhook-workflows"
if [ -d "$WEBHOOK_DIR" ]; then
    services=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")
    
    for service in "${services[@]}"; do
        webhook_file="$WEBHOOK_DIR/${service}-webhook.yml"
        if [ -f "$webhook_file" ]; then
            # Check for correct dispatch repository
            if grep -q "repository: rishanimates/deployment" "$webhook_file"; then
                log_success "✅ $service webhook dispatches to correct repo"
            else
                log_error "❌ $service webhook dispatch repo incorrect"
                exit 1
            fi
            
            # Check for correct service repo format
            if grep -q "\"service_repo\": \"rishanimates/$service\"" "$webhook_file"; then
                log_success "✅ $service repo format is correct"
            else
                log_error "❌ $service repo format is incorrect"
                exit 1
            fi
        else
            log_error "❌ $service webhook file missing"
            exit 1
        fi
    done
else
    log_error "❌ service-webhook-workflows directory not found"
    exit 1
fi

echo -e "\n${C_GREEN}===================================================${C_RESET}"
echo -e "${C_GREEN}    ✅ All Repository Formats Verified!${C_RESET}"
echo -e "${C_GREEN}===================================================${C_RESET}"

echo -e "\n${C_YELLOW}📋 Configuration Summary:${C_RESET}"
echo "• Organization: rishanimates"
echo "• Repository format: owner/repo (✅ Correct)"
echo "• No HTTPS URLs found (✅ Fixed)"
echo "• Webhook dispatch: rishanimates/deployment (✅ Correct)"
echo "• Service repos: rishanimates/{service-name} (✅ Correct)"

echo -e "\n${C_YELLOW}🚀 Expected GitHub Actions Behavior:${C_RESET}"
echo "• checkout@v4 will use owner/repo format"
echo "• No more 'Invalid repository' errors"
echo "• Webhooks will trigger deployment repository"
echo "• Services will checkout from correct repositories"

echo -e "\n${C_GREEN}🎉 Repository format fix is complete and verified!${C_RESET}"
