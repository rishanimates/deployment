#!/bin/bash

# ==============================================================================
# GitHub Workflows Setup Script
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
    exit 1
}

# --- Main Function ---
main() {
    echo -e "${C_BLUE}===================================================${C_RESET}"
    echo -e "${C_BLUE}    GitHub Workflows Setup${C_RESET}"
    echo -e "${C_BLUE}===================================================${C_RESET}"
    
    # Get the script directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    
    # Move to the project root (one level up from deployment)
    PROJECT_ROOT="$SCRIPT_DIR/.."
    cd "$PROJECT_ROOT"
    
    log_info "Setting up GitHub workflows in project root..."
    
    # Create .github/workflows directory in project root
    mkdir -p .github/workflows
    
    # Copy workflow files from deployment directory
    if [ -d "deployment/.github/workflows" ]; then
        cp deployment/.github/workflows/*.yml .github/workflows/
        log_success "GitHub workflow files copied to .github/workflows/"
    else
        log_error "Workflow files not found in deployment/.github/workflows/"
    fi
    
    # List the copied files
    log_info "Copied workflow files:"
    ls -la .github/workflows/
    
    log_success "GitHub workflows setup completed!"
    
    echo -e "\n${C_YELLOW}=== Next Steps ===${C_RESET}"
    echo "1. Run the SSH setup script: ./deployment/setup-ssh.sh"
    echo "2. Add the GitHub repository secrets shown by the SSH setup script"
    echo "3. Configure the production environment: cp deployment/env.template deployment/.env"
    echo "4. Commit and push your changes to trigger the workflows"
    echo
    echo -e "${C_GREEN}Available workflows:${C_RESET}"
    echo "• ci.yml - Runs on pull requests and develop branch pushes"
    echo "• deploy.yml - Runs on main branch pushes for production deployment"
    echo "• rollback.yml - Manual workflow for rolling back deployments"
}

# Execute main function
main "$@"
