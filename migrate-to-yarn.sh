#!/bin/bash

# ==============================================================================
# Migrate All Services from NPM to Yarn
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
echo -e "${C_BLUE}    Migrate All Services to Yarn Package Manager${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

# Check if yarn is installed
if ! command -v yarn &> /dev/null; then
    log_error "Yarn is not installed. Please install it first:"
    echo "• npm install -g yarn"
    echo "• Or visit: https://yarnpkg.com/getting-started/install"
    exit 1
fi

YARN_VERSION=$(yarn --version)
log_success "Yarn is installed: v$YARN_VERSION"

echo -e "\n${C_YELLOW}🔄 Migrating services from npm to yarn...${C_RESET}"
echo

# Function to migrate a service
migrate_service() {
    local service=$1
    local service_dir="../$service"
    
    log_info "Migrating $service to yarn..."
    
    if [ ! -d "$service_dir" ]; then
        log_warning "Directory $service_dir not found, skipping"
        return 0
    fi
    
    cd "$service_dir"
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        log_warning "No package.json found in $service, skipping"
        cd - > /dev/null
        return 0
    fi
    
    # Remove npm-related files
    if [ -f "package-lock.json" ]; then
        log_info "Removing package-lock.json..."
        rm -f package-lock.json
    fi
    
    if [ -d "node_modules" ]; then
        log_info "Removing node_modules for clean install..."
        rm -rf node_modules
    fi
    
    # Install with yarn
    log_info "Installing dependencies with yarn..."
    if yarn install; then
        if [ -f "yarn.lock" ]; then
            log_success "✅ Successfully migrated $service to yarn"
            
            # Show some stats
            if command -v jq &> /dev/null && [ -f "yarn.lock" ]; then
                DEPS_COUNT=$(yarn list --depth=0 2>/dev/null | grep -c "├─\|└─" || echo "unknown")
                log_info "Dependencies: $DEPS_COUNT packages"
            fi
        else
            log_warning "⚠️  yarn install completed but no yarn.lock generated"
        fi
    else
        log_error "❌ yarn install failed for $service"
        cd - > /dev/null
        return 1
    fi
    
    cd - > /dev/null
}

# Migrate all services
for service in "${SERVICES[@]}"; do
    migrate_service "$service"
    echo
done

echo -e "${C_YELLOW}🔍 Verification - checking yarn.lock files...${C_RESET}"
echo

# Verify migration
for service in "${SERVICES[@]}"; do
    service_dir="../$service"
    echo -n "Checking $service... "
    
    if [ -f "$service_dir/yarn.lock" ]; then
        log_success "✅ yarn.lock exists"
    else
        if [ -f "$service_dir/package.json" ]; then
            log_warning "⚠️  Still using npm (no yarn.lock)"
        else
            log_info "ℹ️  No package.json found"
        fi
    fi
done

echo -e "\n${C_YELLOW}📝 Commit Changes to Repositories:${C_RESET}"
echo "Run these commands to commit the yarn migration:"
echo

for service in "${SERVICES[@]}"; do
    service_dir="../$service"
    if [ -f "$service_dir/yarn.lock" ]; then
        cat << EOF
# $service
cd ../$service
git add yarn.lock
git rm package-lock.json 2>/dev/null || true
git add package.json  # In case any changes were made
git commit -m "Migrate from npm to yarn

- Remove package-lock.json
- Add yarn.lock for reproducible builds
- Use yarn for dependency management"
git push origin develop
git push origin main

EOF
    fi
done

echo -e "\n${C_YELLOW}🚀 GitHub Actions Updates:${C_RESET}"
echo "✅ Workflows already updated to use yarn by default"
echo "✅ Will detect yarn.lock files and use yarn install --frozen-lockfile"
echo "✅ Fallback to yarn install for repos without yarn.lock"

echo -e "\n${C_YELLOW}🧪 Testing the Migration:${C_RESET}"
echo "1. Commit yarn.lock files to your repositories"
echo "2. Push changes to develop branch"
echo "3. GitHub Actions should now show:"
echo "   ✅ 'Detected package manager: pm=yarn'"
echo "   ✅ 'yarn install' or 'yarn install --frozen-lockfile'"
echo "   ✅ No more npm ci sync errors"

echo -e "\n${C_YELLOW}📊 Benefits of Yarn:${C_RESET}"
echo "• Faster dependency installation"
echo "• Better lock file format"
echo "• Improved security with integrity checking"
echo "• Better workspace support"
echo "• More reliable dependency resolution"

echo -e "\n${C_YELLOW}🔧 Yarn Commands Reference:${C_RESET}"
echo "• Install dependencies: yarn install"
echo "• Add dependency: yarn add package-name"
echo "• Add dev dependency: yarn add -D package-name"
echo "• Remove dependency: yarn remove package-name"
echo "• Run scripts: yarn run script-name or yarn script-name"
echo "• Update dependencies: yarn upgrade"

echo -e "\n${C_GREEN}===================================================${C_RESET}"
echo -e "${C_GREEN}    Migration to Yarn Complete!${C_RESET}"
echo -e "${C_GREEN}===================================================${C_RESET}"

echo -e "\n${C_GREEN}🎉 All services migrated to yarn! Commit the changes and test deployment.${C_RESET}"
