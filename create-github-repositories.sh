#!/bin/bash

# ==============================================================================
# Create GitHub Repositories for Services
# This script helps create and initialize GitHub repositories for each service
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

# --- Configuration ---
GITHUB_ORG="rishanimates"
SERVICES=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")

echo -e "${C_BLUE}===================================================${C_RESET}"
echo -e "${C_BLUE}    GitHub Repository Creation for Services${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) is not installed"
    echo -e "${C_YELLOW}Install GitHub CLI:${C_RESET}"
    echo "• macOS: brew install gh"
    echo "• Ubuntu: sudo apt install gh"
    echo "• Or download from: https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated with GitHub CLI
if ! gh auth status &> /dev/null; then
    log_error "Not authenticated with GitHub CLI"
    echo -e "${C_YELLOW}Authenticate with GitHub:${C_RESET}"
    echo "gh auth login"
    exit 1
fi

log_success "GitHub CLI is installed and authenticated"

# Function to create repository
create_repository() {
    local service=$1
    local description=$2
    
    log_info "Creating repository: $GITHUB_ORG/$service"
    
    # Check if repository already exists
    if gh repo view "$GITHUB_ORG/$service" &> /dev/null; then
        log_warning "Repository $GITHUB_ORG/$service already exists"
        return 0
    fi
    
    # Create the repository
    if gh repo create "$GITHUB_ORG/$service" --public --description "$description"; then
        log_success "✅ Created repository: $GITHUB_ORG/$service"
    else
        log_error "❌ Failed to create repository: $GITHUB_ORG/$service"
        return 1
    fi
}

# Function to initialize local repository and push code
initialize_repository() {
    local service=$1
    local source_dir="../$service"
    
    log_info "Initializing local repository for $service"
    
    # Check if source directory exists
    if [ ! -d "$source_dir" ]; then
        log_warning "Source directory $source_dir does not exist, skipping initialization"
        return 0
    fi
    
    cd "$source_dir"
    
    # Initialize git if not already initialized
    if [ ! -d ".git" ]; then
        git init
        log_info "Initialized git repository in $source_dir"
    fi
    
    # Add remote origin if not exists
    if ! git remote get-url origin &> /dev/null; then
        git remote add origin "git@github.com:$GITHUB_ORG/$service.git"
        log_info "Added remote origin for $service"
    fi
    
    # Create .gitignore if not exists
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore << 'EOF'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/
*.lcov

# nyc test coverage
.nyc_output

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

# Optional npm cache directory
.npm

# Optional eslint cache
.eslintcache

# Microbundle cache
.rpt2_cache/
.rts2_cache_cjs/
.rts2_cache_es/
.rts2_cache_umd/

# Optional REPL history
.node_repl_history

# Output of 'npm pack'
*.tgz

# Yarn Integrity file
.yarn-integrity

# dotenv environment variables file
.env
.env.test

# parcel-bundler cache (https://parceljs.org/)
.cache
.parcel-cache

# Next.js build output
.next

# Nuxt.js build / generate output
.nuxt
dist

# Gatsby files
.cache/
public

# Storybook build outputs
.out
.storybook-out

# Temporary folders
tmp/
temp/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Docker
Dockerfile.dev
docker-compose.dev.yml

# Database
*.db
*.sqlite

# Build outputs
build/
dist/
EOF
        log_info "Created .gitignore for $service"
    fi
    
    # Create README if not exists
    if [ ! -f "README.md" ]; then
        cat > README.md << EOF
# $service

$description

## Getting Started

### Prerequisites
- Node.js 18+
- npm or yarn

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
Copy \`.env.example\` to \`.env\` and configure:
\`\`\`bash
cp .env.example .env
\`\`\`

### Health Check
\`\`\`bash
curl http://localhost:3000/health
\`\`\`

## API Documentation
- Health: \`GET /health\`
- Swagger: \`GET /api-docs\` (if configured)

## Deployment
This service is automatically deployed when code is merged to:
- \`develop\` branch → Staging environment
- \`main\` branch → Production environment

## Contributing
1. Create feature branch from \`develop\`
2. Make changes
3. Create pull request to \`develop\`
4. After testing, merge \`develop\` to \`main\` for production
EOF
        log_info "Created README.md for $service"
    fi
    
    # Add all files
    git add .
    
    # Create initial commit if no commits exist
    if ! git rev-parse HEAD &> /dev/null; then
        git commit -m "Initial commit: $service setup"
        log_info "Created initial commit for $service"
    fi
    
    # Create and switch to develop branch
    if ! git show-ref --verify --quiet refs/heads/develop; then
        git checkout -b develop
        log_info "Created develop branch for $service"
    else
        git checkout develop
    fi
    
    # Push to GitHub
    if git push -u origin develop; then
        log_success "✅ Pushed $service to GitHub (develop branch)"
    else
        log_error "❌ Failed to push $service to GitHub"
        cd - > /dev/null
        return 1
    fi
    
    # Switch back to main and push
    git checkout main 2>/dev/null || git checkout -b main
    if git push -u origin main; then
        log_success "✅ Pushed $service to GitHub (main branch)"
    else
        log_warning "⚠️  Could not push main branch for $service"
    fi
    
    cd - > /dev/null
}

# Main execution
main() {
    log_info "Starting repository creation process..."
    
    # Service descriptions
    declare -A SERVICE_DESCRIPTIONS=(
        ["auth-service"]="Authentication and authorization service for LetzGo platform"
        ["user-service"]="User management and profiles service"
        ["chat-service"]="Real-time messaging and communication service"
        ["event-service"]="Event management and ticketing service"
        ["shared-service"]="Shared utilities for storage, payments, and notifications"
        ["splitz-service"]="Expense splitting and management service"
    )
    
    # Step 1: Create repositories on GitHub
    log_info "Step 1: Creating GitHub repositories..."
    for service in "${SERVICES[@]}"; do
        create_repository "$service" "${SERVICE_DESCRIPTIONS[$service]}"
    done
    
    echo
    log_info "Step 2: Initializing local repositories and pushing code..."
    for service in "${SERVICES[@]}"; do
        initialize_repository "$service" "${SERVICE_DESCRIPTIONS[$service]}"
        echo
    done
    
    echo -e "${C_GREEN}===================================================${C_RESET}"
    echo -e "${C_GREEN}    Repository Creation Completed!${C_RESET}"
    echo -e "${C_GREEN}===================================================${C_RESET}"
    
    echo -e "\n${C_YELLOW}📋 Created Repositories:${C_RESET}"
    for service in "${SERVICES[@]}"; do
        echo "• https://github.com/$GITHUB_ORG/$service"
    done
    
    echo -e "\n${C_YELLOW}🔗 SSH Clone URLs:${C_RESET}"
    for service in "${SERVICES[@]}"; do
        echo "• git@github.com:$GITHUB_ORG/$service.git"
    done
    
    echo -e "\n${C_YELLOW}🚀 Next Steps:${C_RESET}"
    echo "1. Set up webhooks in each service repository:"
    echo "   cd ../{service-name}"
    echo "   cp ../deployment/setup-service-webhooks.sh ."
    echo "   ./setup-service-webhooks.sh"
    echo
    echo "2. Add DEPLOYMENT_TOKEN secret to each repository"
    echo
    echo "3. Test automatic deployment by pushing to develop branch"
    
    echo -e "\n${C_GREEN}🎉 All service repositories are ready for automatic deployment!${C_RESET}"
}

# Execute main function
main "$@"
