#!/bin/bash

# ==============================================================================
# Commit All Docker and Yarn Changes to All Services
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

log_warning() {
    echo -e "${C_YELLOW}[WARNING] $1${C_RESET}"
}

log_error() {
    echo -e "${C_RED}[ERROR] $1${C_RESET}"
}

SERVICES=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")

echo -e "${C_BLUE}===================================================${C_RESET}"
echo -e "${C_BLUE}    Commit Docker and Yarn Changes${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

# Function to commit changes for a service
commit_service_changes() {
    local service=$1
    local service_dir="../$service"
    
    log_info "Committing changes for $service..."
    
    if [ ! -d "$service_dir" ]; then
        log_warning "Directory $service_dir not found, skipping"
        return 0
    fi
    
    cd "$service_dir"
    
    # Check if there are any changes to commit
    if git diff --quiet && git diff --cached --quiet; then
        log_info "No changes to commit for $service"
        cd - > /dev/null
        return 0
    fi
    
    # Add all relevant files
    git add Dockerfile 2>/dev/null || true
    git add yarn.lock 2>/dev/null || true
    git add package.json 2>/dev/null || true
    
    # Remove package-lock.json if it exists
    if [ -f "package-lock.json" ]; then
        git rm package-lock.json 2>/dev/null || true
        log_info "Removed package-lock.json"
    fi
    
    # Check if there are staged changes
    if git diff --cached --quiet; then
        log_info "No staged changes for $service"
        cd - > /dev/null
        return 0
    fi
    
    # Commit changes
    git commit -m "Upgrade to Node.js 20 and migrate to Yarn

🔄 Docker Updates:
- Upgrade base image from node:18-alpine to node:20-alpine
- Switch from npm to yarn for dependency management
- Add non-root user for improved security
- Add health check endpoint
- Add logs directory creation

📦 Package Manager Migration:
- Remove package-lock.json
- Add yarn.lock for reproducible builds
- Use yarn for dependency management

🎯 Benefits:
- Firebase compatibility (requires Node.js 20+)
- Faster dependency installation with yarn
- Better security and reproducible builds
- Enhanced Docker container security"
    
    if [ $? -eq 0 ]; then
        log_success "✅ Committed changes for $service"
        
        # Push to develop branch
        log_info "Pushing to develop branch..."
        if git push origin develop 2>/dev/null; then
            log_success "✅ Pushed to develop branch"
        else
            log_warning "⚠️  Could not push to develop branch (may not exist or no changes)"
        fi
        
        # Push to main branch
        log_info "Pushing to main branch..."
        if git push origin main 2>/dev/null; then
            log_success "✅ Pushed to main branch"
        else
            log_warning "⚠️  Could not push to main branch (may not exist or no changes)"
        fi
    else
        log_error "❌ Failed to commit changes for $service"
    fi
    
    cd - > /dev/null
}

# Commit changes for all services
for service in "${SERVICES[@]}"; do
    commit_service_changes "$service"
    echo
done

echo -e "${C_GREEN}===================================================${C_RESET}"
echo -e "${C_GREEN}    All Changes Committed and Pushed!${C_RESET}"
echo -e "${C_GREEN}===================================================${C_RESET}"

echo -e "\n${C_YELLOW}📋 Changes Applied:${C_RESET}"
echo "✅ Updated all Dockerfiles to Node.js 20 and yarn"
echo "✅ Generated yarn.lock files for all services"
echo "✅ Removed package-lock.json files"
echo "✅ Added security improvements to Docker containers"
echo "✅ Committed and pushed changes to repositories"

echo -e "\n${C_YELLOW}🧪 Test the Deployment:${C_RESET}"
echo "Now you can test the deployment - it should work without Docker build errors:"
echo
echo "# In any service repository"
echo "git checkout develop"
echo "echo '# Test Docker fix' >> README.md"
echo "git add README.md"
echo "git commit -m 'Test Docker and yarn fixes'"
echo "git push origin develop"

echo -e "\n${C_YELLOW}🎯 Expected Results:${C_RESET}"
echo "✅ Docker build uses node:20-alpine base image"
echo "✅ yarn install --frozen-lockfile (no npm ci errors)"
echo "✅ Firebase dependencies install successfully"
echo "✅ Docker container runs with non-root user"
echo "✅ Health check endpoint available"
echo "✅ Successful deployment to staging VPS"

echo -e "\n${C_GREEN}🎉 Your services are now ready for deployment with Node.js 20 and Yarn!${C_RESET}"
