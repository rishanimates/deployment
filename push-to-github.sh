#!/bin/bash

# ==============================================================================
# Push Existing Service Code to GitHub Repositories
# Run this after creating the GitHub repositories
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

GITHUB_ORG="rishanimates"
SERVICES=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")

echo -e "${C_BLUE}===================================================${C_RESET}"
echo -e "${C_BLUE}    Push Service Code to GitHub${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

# Function to setup and push a service
setup_service() {
    local service=$1
    local service_dir="../$service"
    
    log_info "Setting up $service..."
    
    # Check if service directory exists
    if [ ! -d "$service_dir" ]; then
        log_warning "Directory $service_dir does not exist, skipping"
        return 0
    fi
    
    cd "$service_dir"
    
    # Initialize git if not already initialized
    if [ ! -d ".git" ]; then
        git init
        log_info "Initialized git repository"
    fi
    
    # Check if remote origin exists
    if git remote get-url origin &> /dev/null; then
        log_info "Remote origin already exists"
    else
        git remote add origin "git@github.com:$GITHUB_ORG/$service.git"
        log_success "Added remote origin"
    fi
    
    # Create basic .gitignore if it doesn't exist
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore << 'EOF'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
logs
*.log

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory
coverage/
*.lcov

# nyc test coverage
.nyc_output

# Build outputs
build/
dist/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Temporary folders
tmp/
temp/

# Database
*.db
*.sqlite
EOF
        log_info "Created .gitignore"
    fi
    
    # Create basic README if it doesn't exist
    if [ ! -f "README.md" ]; then
        cat > README.md << EOF
# $service

## Getting Started

### Installation
\`\`\`bash
npm install
\`\`\`

### Running the Service
\`\`\`bash
# Development
npm run dev

# Production
npm start
\`\`\`

### Environment Variables
Copy \`.env.example\` to \`.env\` and configure as needed.

### Health Check
\`\`\`bash
curl http://localhost:3000/health
\`\`\`

## Deployment
- \`develop\` branch → Staging environment (automatic)
- \`main\` branch → Production environment (automatic)
EOF
        log_info "Created README.md"
    fi
    
    # Add all files
    git add .
    
    # Check if there are changes to commit
    if git diff --staged --quiet; then
        log_info "No changes to commit"
    else
        # Commit changes
        git commit -m "Initial setup for $service" || log_info "Nothing to commit or already committed"
    fi
    
    # Create and checkout develop branch
    if git show-ref --verify --quiet refs/heads/develop; then
        git checkout develop
        log_info "Switched to existing develop branch"
    else
        git checkout -b develop
        log_success "Created and switched to develop branch"
    fi
    
    # Push develop branch
    if git push -u origin develop; then
        log_success "✅ Pushed develop branch"
    else
        log_warning "⚠️  Could not push develop branch (might already exist)"
    fi
    
    # Switch to main branch and push
    if git show-ref --verify --quiet refs/heads/main; then
        git checkout main
        log_info "Switched to existing main branch"
    else
        git checkout -b main
        log_success "Created and switched to main branch"
    fi
    
    if git push -u origin main; then
        log_success "✅ Pushed main branch"
    else
        log_warning "⚠️  Could not push main branch (might already exist)"
    fi
    
    cd - > /dev/null
    log_success "✅ Completed setup for $service"
    echo
}

# Main execution
main() {
    log_info "Starting to push service code to GitHub repositories..."
    echo
    
    for service in "${SERVICES[@]}"; do
        setup_service "$service"
    done
    
    echo -e "${C_GREEN}===================================================${C_RESET}"
    echo -e "${C_GREEN}    All Services Pushed to GitHub!${C_RESET}"
    echo -e "${C_GREEN}===================================================${C_RESET}"
    
    echo -e "\n${C_YELLOW}📋 Repository URLs:${C_RESET}"
    for service in "${SERVICES[@]}"; do
        echo "• https://github.com/$GITHUB_ORG/$service"
    done
    
    echo -e "\n${C_YELLOW}🚀 Next Steps:${C_RESET}"
    echo "1. Verify repositories exist: ./check-repositories.sh"
    echo "2. Install webhooks in each service repository"
    echo "3. Add DEPLOYMENT_TOKEN secret to each repository"
    echo "4. Test by pushing to develop branch"
    
    echo -e "\n${C_GREEN}🎉 Service code is now on GitHub and ready for automatic deployment!${C_RESET}"
}

# Execute main function
main "$@"
