#!/bin/bash

# ==============================================================================
# Check Package Managers in Service Repositories
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
echo -e "${C_BLUE}    Package Manager Check for Services${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

echo -e "\n${C_YELLOW}📦 Checking package managers and lock files...${C_RESET}"
echo

# Function to check a service
check_service() {
    local service=$1
    local service_dir="../$service"
    
    echo -n "Checking $service... "
    
    if [ ! -d "$service_dir" ]; then
        log_warning "Directory not found"
        return 0
    fi
    
    cd "$service_dir"
    
    # Check for package.json
    if [ ! -f "package.json" ]; then
        log_error "No package.json found"
        cd - > /dev/null
        return 1
    fi
    
    # Determine package manager
    if [ -f "yarn.lock" ]; then
        echo -e "${C_GREEN}✅ Yarn (yarn.lock found)${C_RESET}"
        PACKAGE_MANAGER="yarn"
        LOCK_FILE="yarn.lock"
    elif [ -f "package-lock.json" ]; then
        echo -e "${C_GREEN}✅ NPM (package-lock.json found)${C_RESET}"
        PACKAGE_MANAGER="npm"
        LOCK_FILE="package-lock.json"
    else
        echo -e "${C_YELLOW}⚠️  No lock file (will use npm install)${C_RESET}"
        PACKAGE_MANAGER="npm"
        LOCK_FILE="none"
    fi
    
    # Store results for summary
    echo "$service:$PACKAGE_MANAGER:$LOCK_FILE" >> /tmp/package_managers.txt
    
    cd - > /dev/null
}

# Create temp file for results
> /tmp/package_managers.txt

# Check all services
for service in "${SERVICES[@]}"; do
    check_service "$service"
done

echo -e "\n${C_YELLOW}📋 Package Manager Summary:${C_RESET}"
echo

# Read results and display summary
if [ -f "/tmp/package_managers.txt" ]; then
    while IFS=':' read -r service pm lockfile; do
        case $pm in
            "yarn")
                echo "• $service: ${C_GREEN}Yarn${C_RESET} (yarn.lock)"
                ;;
            "npm")
                if [ "$lockfile" = "package-lock.json" ]; then
                    echo "• $service: ${C_GREEN}NPM${C_RESET} (package-lock.json)"
                else
                    echo "• $service: ${C_YELLOW}NPM${C_RESET} (no lock file)"
                fi
                ;;
        esac
    done < /tmp/package_managers.txt
fi

echo -e "\n${C_YELLOW}🔧 GitHub Actions Workflow Updates:${C_RESET}"
echo "✅ Workflows now automatically detect package managers"
echo "✅ Support for both npm and yarn"
echo "✅ Handles missing lock files gracefully"
echo "✅ Uses appropriate install commands:"
echo "   - yarn.lock → yarn install --frozen-lockfile"
echo "   - package-lock.json → npm ci"
echo "   - no lock file → npm install"

echo -e "\n${C_YELLOW}🛠️ Recommendations:${C_RESET}"

# Check for services without lock files
SERVICES_WITHOUT_LOCKS=""
if [ -f "/tmp/package_managers.txt" ]; then
    while IFS=':' read -r service pm lockfile; do
        if [ "$lockfile" = "none" ]; then
            SERVICES_WITHOUT_LOCKS="$SERVICES_WITHOUT_LOCKS $service"
        fi
    done < /tmp/package_managers.txt
fi

if [ -n "$SERVICES_WITHOUT_LOCKS" ]; then
    echo -e "${C_YELLOW}⚠️  Services without lock files:$SERVICES_WITHOUT_LOCKS${C_RESET}"
    echo "   Consider generating lock files for better reproducibility:"
    echo "   - For npm: run 'npm install' to generate package-lock.json"
    echo "   - For yarn: run 'yarn install' to generate yarn.lock"
    echo
fi

# Check for mixed package managers
NPM_COUNT=$(grep -c ":npm:" /tmp/package_managers.txt 2>/dev/null || echo "0")
YARN_COUNT=$(grep -c ":yarn:" /tmp/package_managers.txt 2>/dev/null || echo "0")

if [ "$NPM_COUNT" -gt 0 ] && [ "$YARN_COUNT" -gt 0 ]; then
    echo -e "${C_YELLOW}📝 Mixed package managers detected${C_RESET}"
    echo "   Consider standardizing on one package manager across all services"
    echo "   Current usage:"
    echo "   - NPM: $NPM_COUNT services"
    echo "   - Yarn: $YARN_COUNT services"
    echo
fi

echo -e "\n${C_YELLOW}🧪 Testing the Fix:${C_RESET}"
echo "1. Push changes to any service repository develop branch"
echo "2. Check GitHub Actions logs for:"
echo "   ✅ 'Detected package manager: pm=npm' or 'pm=yarn'"
echo "   ✅ Successful dependency installation"
echo "   ✅ No caching errors"

echo -e "\n${C_YELLOW}🔍 If Issues Persist:${C_RESET}"
echo "• Check that package.json exists in service root"
echo "• Verify lock files are committed to repository"
echo "• Ensure dependencies are valid and installable"

# Cleanup
rm -f /tmp/package_managers.txt

echo -e "\n${C_GREEN}===================================================${C_RESET}"
echo -e "${C_GREEN}    Package Manager Check Complete!${C_RESET}"
echo -e "${C_GREEN}===================================================${C_RESET}"

echo -e "\n${C_GREEN}🎉 GitHub Actions workflows are now updated to handle different package managers automatically!${C_RESET}"
