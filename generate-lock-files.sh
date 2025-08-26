#!/bin/bash

# ==============================================================================
# Generate Missing Lock Files for Services
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

SERVICES_MISSING_LOCKS=("user-service" "chat-service" "shared-service" "splitz-service")

echo -e "${C_BLUE}===================================================${C_RESET}"
echo -e "${C_BLUE}    Generate Missing Lock Files${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

echo -e "\n${C_YELLOW}📦 Services missing lock files:${C_RESET}"
for service in "${SERVICES_MISSING_LOCKS[@]}"; do
    echo "• $service"
done

echo -e "\n${C_YELLOW}🔧 Generating package-lock.json files...${C_RESET}"
echo

# Function to generate lock file for a service
generate_lock_file() {
    local service=$1
    local service_dir="../$service"
    
    log_info "Processing $service..."
    
    if [ ! -d "$service_dir" ]; then
        log_warning "Directory $service_dir not found, skipping"
        return 0
    fi
    
    cd "$service_dir"
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        log_error "No package.json found in $service"
        cd - > /dev/null
        return 1
    fi
    
    # Remove existing node_modules to ensure clean install
    if [ -d "node_modules" ]; then
        log_info "Removing existing node_modules..."
        rm -rf node_modules
    fi
    
    # Generate package-lock.json
    log_info "Running npm install to generate package-lock.json..."
    if npm install; then
        if [ -f "package-lock.json" ]; then
            log_success "✅ Generated package-lock.json for $service"
            
            # Show some stats
            DEPS_COUNT=$(jq '.dependencies | length' package-lock.json 2>/dev/null || echo "unknown")
            log_info "Dependencies: $DEPS_COUNT packages"
        else
            log_warning "⚠️  npm install completed but no package-lock.json generated"
        fi
    else
        log_error "❌ npm install failed for $service"
        cd - > /dev/null
        return 1
    fi
    
    cd - > /dev/null
}

# Generate lock files for services that need them
for service in "${SERVICES_MISSING_LOCKS[@]}"; do
    generate_lock_file "$service"
    echo
done

echo -e "${C_YELLOW}🔍 Verification - checking lock files again...${C_RESET}"
echo

# Re-check lock files
for service in "${SERVICES_MISSING_LOCKS[@]}"; do
    service_dir="../$service"
    echo -n "Checking $service... "
    
    if [ -f "$service_dir/package-lock.json" ]; then
        log_success "✅ package-lock.json exists"
    else
        log_warning "⚠️  Still missing lock file"
    fi
done

echo -e "\n${C_YELLOW}📝 Next Steps:${C_RESET}"
echo "1. Commit the generated lock files to your repositories:"
echo
for service in "${SERVICES_MISSING_LOCKS[@]}"; do
    cat << EOF
   cd ../$service
   git add package-lock.json
   git commit -m "Add package-lock.json for reproducible builds"
   git push origin develop
   git push origin main

EOF
done

echo "2. Test deployment again - should now work without caching errors"

echo -e "\n${C_YELLOW}🎯 Expected Results:${C_RESET}"
echo "• GitHub Actions will detect package-lock.json files"
echo "• npm caching will work correctly"
echo "• No more 'Some specified paths were not resolved' errors"
echo "• Faster builds due to dependency caching"

echo -e "\n${C_YELLOW}⚡ Alternative: Quick Commit Script${C_RESET}"
cat << 'EOF'
# Run this to quickly commit all lock files:
for service in user-service chat-service shared-service splitz-service; do
    if [ -f "../$service/package-lock.json" ]; then
        cd "../$service"
        git add package-lock.json
        git commit -m "Add package-lock.json for reproducible builds" || true
        git push origin develop || true
        git push origin main || true
        cd - > /dev/null
    fi
done
EOF

echo -e "\n${C_GREEN}===================================================${C_RESET}"
echo -e "${C_GREEN}    Lock File Generation Complete!${C_RESET}"
echo -e "${C_GREEN}===================================================${C_RESET}"

echo -e "\n${C_GREEN}🎉 Lock files generated! Commit them to fix the GitHub Actions caching errors.${C_RESET}"
