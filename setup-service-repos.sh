#!/bin/bash

# ==============================================================================
# LetzGo Service Repositories Setup Script
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

# --- Service configuration ---
SERVICES=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")
GITHUB_ORG=""

# --- Get GitHub organization ---
get_github_org() {
    echo -e "${C_YELLOW}GitHub Organization Setup${C_RESET}"
    echo "Enter your GitHub organization or username:"
    read -p "GitHub org/username: " GITHUB_ORG
    
    if [ -z "$GITHUB_ORG" ]; then
        log_error "GitHub organization/username is required"
        exit 1
    fi
    
    log_success "Using GitHub organization: $GITHUB_ORG"
}

# --- Update service repositories configuration ---
update_service_config() {
    log_info "Updating service repositories configuration..."
    
    local config_file="service-repositories.json"
    
    if [ ! -f "$config_file" ]; then
        log_error "Configuration file $config_file not found"
        exit 1
    fi
    
    # Create backup
    cp "$config_file" "$config_file.backup"
    
    # Update repository URLs
    for service in "${SERVICES[@]}"; do
        local repo_url="https://github.com/$GITHUB_ORG/$service.git"
        
        # Use sed to replace the repository URL
        sed -i.tmp "s|\"https://github.com/your-org/$service.git\"|\"$repo_url\"|g" "$config_file"
        rm -f "$config_file.tmp"
        
        log_success "Updated $service repository URL"
    done
    
    log_success "Service configuration updated successfully"
}

# --- Update GitHub Actions workflow ---
update_workflow() {
    log_info "Updating GitHub Actions workflow..."
    
    local workflow_file=".github/workflows/deploy-services-multi-repo.yml"
    
    if [ ! -f "$workflow_file" ]; then
        log_error "Workflow file $workflow_file not found"
        exit 1
    fi
    
    # Create backup
    cp "$workflow_file" "$workflow_file.backup"
    
    # Update repository URLs in workflow
    for service in "${SERVICES[@]}"; do
        local repo_url="https://github.com/$GITHUB_ORG/$service.git"
        
        sed -i.tmp "s|\"https://github.com/your-org/$service.git\"|\"$repo_url\"|g" "$workflow_file"
        rm -f "$workflow_file.tmp"
    done
    
    log_success "GitHub Actions workflow updated successfully"
}

# --- Create individual service repositories ---
create_service_repos() {
    log_info "Creating individual service repositories..."
    
    echo -e "${C_YELLOW}Repository Creation Options:${C_RESET}"
    echo "1. Create repositories manually on GitHub"
    echo "2. Use GitHub CLI to create repositories automatically"
    echo "3. Skip repository creation (repositories already exist)"
    
    read -p "Choose option (1-3): " choice
    
    case $choice in
        1)
            create_repos_manually
            ;;
        2)
            create_repos_with_cli
            ;;
        3)
            log_info "Skipping repository creation"
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

# --- Manual repository creation instructions ---
create_repos_manually() {
    log_info "Manual repository creation instructions:"
    
    echo -e "\n${C_YELLOW}Create these repositories on GitHub:${C_RESET}"
    for service in "${SERVICES[@]}"; do
        echo "  📁 https://github.com/$GITHUB_ORG/$service"
    done
    
    echo -e "\n${C_YELLOW}For each repository:${C_RESET}"
    echo "1. Go to https://github.com/new"
    echo "2. Set repository name (e.g., auth-service)"
    echo "3. Set as Private or Public"
    echo "4. Initialize with README"
    echo "5. Click 'Create repository'"
    
    read -p "Press Enter when you've created all repositories..."
}

# --- GitHub CLI repository creation ---
create_repos_with_cli() {
    # Check if GitHub CLI is installed
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        log_info "Install it from: https://cli.github.com/"
        exit 1
    fi
    
    # Check if user is logged in
    if ! gh auth status &> /dev/null; then
        log_error "Not logged in to GitHub CLI"
        log_info "Run: gh auth login"
        exit 1
    fi
    
    log_info "Creating repositories with GitHub CLI..."
    
    for service in "${SERVICES[@]}"; do
        log_info "Creating repository: $service"
        
        if gh repo create "$GITHUB_ORG/$service" --private --description "LetzGo $service microservice" --clone; then
            log_success "Created repository: $service"
        else
            log_warning "Repository $service might already exist or creation failed"
        fi
    done
}

# --- Split existing monorepo ---
split_monorepo() {
    log_info "Splitting existing monorepo..."
    
    echo -e "${C_YELLOW}Do you want to split an existing monorepo?${C_RESET}"
    read -p "Enter path to existing monorepo (or press Enter to skip): " monorepo_path
    
    if [ -z "$monorepo_path" ]; then
        log_info "Skipping monorepo split"
        return
    fi
    
    if [ ! -d "$monorepo_path" ]; then
        log_error "Monorepo path does not exist: $monorepo_path"
        return
    fi
    
    log_info "Splitting monorepo at: $monorepo_path"
    
    for service in "${SERVICES[@]}"; do
        local service_path="$monorepo_path/$service"
        
        if [ -d "$service_path" ]; then
            log_info "Processing $service..."
            
            # Create temporary directory
            local temp_dir="/tmp/$service-split"
            rm -rf "$temp_dir"
            mkdir -p "$temp_dir"
            
            # Copy service files
            cp -r "$service_path"/* "$temp_dir/"
            
            # Initialize git repo
            cd "$temp_dir"
            git init
            git add .
            git commit -m "Initial commit for $service"
            
            # Add remote and push
            local repo_url="https://github.com/$GITHUB_ORG/$service.git"
            git remote add origin "$repo_url"
            git branch -M main
            git push -u origin main
            
            log_success "Split and pushed $service to $repo_url"
            
            cd - > /dev/null
            rm -rf "$temp_dir"
        else
            log_warning "Service directory not found: $service_path"
        fi
    done
}

# --- Verify setup ---
verify_setup() {
    log_info "Verifying setup..."
    
    # Check if repositories exist
    for service in "${SERVICES[@]}"; do
        local repo_url="https://github.com/$GITHUB_ORG/$service"
        
        if curl -s -f -o /dev/null "$repo_url"; then
            log_success "✅ Repository exists: $repo_url"
        else
            log_warning "⚠️  Repository not accessible: $repo_url"
        fi
    done
    
    # Show configuration
    echo -e "\n${C_YELLOW}=== Configuration Summary ===${C_RESET}"
    echo "GitHub Organization: $GITHUB_ORG"
    echo "Services configured: ${#SERVICES[@]}"
    echo "Configuration file: service-repositories.json"
    echo "Workflow file: .github/workflows/deploy-services-multi-repo.yml"
}

# --- Main function ---
main() {
    echo -e "${C_BLUE}===================================================${C_RESET}"
    echo -e "${C_BLUE}    LetzGo Service Repositories Setup${C_RESET}"
    echo -e "${C_BLUE}===================================================${C_RESET}"
    
    get_github_org
    update_service_config
    update_workflow
    create_service_repos
    split_monorepo
    verify_setup
    
    echo -e "\n${C_GREEN}===================================================${C_RESET}"
    echo -e "${C_GREEN}    Setup Completed Successfully!${C_RESET}"
    echo -e "${C_GREEN}===================================================${C_RESET}"
    
    echo -e "\n${C_YELLOW}Next Steps:${C_RESET}"
    echo "1. Commit and push the updated configuration:"
    echo "   git add ."
    echo "   git commit -m 'Configure multi-repository service deployment'"
    echo "   git push origin main"
    echo
    echo "2. Copy the multi-repo workflow to your main repository:"
    echo "   cp .github/workflows/deploy-services-multi-repo.yml ../../../.github/workflows/"
    echo
    echo "3. Test deployment:"
    echo "   Go to GitHub Actions → Deploy Services (Multi-Repository) → Run workflow"
    echo
    echo "4. Each service repository should have:"
    echo "   - package.json with 'start' script"
    echo "   - /health endpoint in the application"
    echo "   - Dockerfile (will be auto-generated if missing)"
}

# Execute main function
main "$@"
