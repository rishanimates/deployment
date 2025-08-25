#!/bin/bash

# ==============================================================================
# Setup GitHub Webhooks for Automatic Deployments
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

# --- Configuration ---
SERVICES=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")
GITHUB_ORG=""
DEPLOYMENT_REPO=""

# --- Get configuration ---
get_configuration() {
    echo -e "${C_YELLOW}Webhook Configuration Setup${C_RESET}"
    
    read -p "Enter your GitHub organization/username: " GITHUB_ORG
    if [ -z "$GITHUB_ORG" ]; then
        log_error "GitHub organization is required"
        exit 1
    fi
    
    read -p "Enter your deployment repository name (e.g., 'deployment'): " DEPLOYMENT_REPO
    if [ -z "$DEPLOYMENT_REPO" ]; then
        log_error "Deployment repository name is required"
        exit 1
    fi
    
    log_success "Configuration set: $GITHUB_ORG/$DEPLOYMENT_REPO"
}

# --- Create webhook workflow for service repositories ---
create_service_webhook_workflow() {
    log_info "Creating webhook workflows for service repositories..."
    
    local workflow_dir="service-webhook-workflows"
    mkdir -p "$workflow_dir"
    
    for service in "${SERVICES[@]}"; do
        log_info "Creating webhook workflow for $service..."
        
        cat > "$workflow_dir/${service}-webhook.yml" << EOF
name: Deploy $service on Branch Merge

on:
  push:
    branches: 
      - develop  # Triggers staging deployment
      - main     # Triggers production deployment

jobs:
  trigger-deployment:
    name: Trigger Deployment
    runs-on: ubuntu-latest
    
    steps:
      - name: Determine deployment environment
        id: env
        run: |
          if [[ "\${{ github.ref }}" == "refs/heads/develop" ]]; then
            echo "environment=staging" >> \$GITHUB_OUTPUT
            echo "dispatch_type=deploy-staging" >> \$GITHUB_OUTPUT
          elif [[ "\${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "environment=production" >> \$GITHUB_OUTPUT
            echo "dispatch_type=deploy-production" >> \$GITHUB_OUTPUT
          else
            echo "environment=none" >> \$GITHUB_OUTPUT
            echo "dispatch_type=none" >> \$GITHUB_OUTPUT
          fi

      - name: Trigger deployment workflow
        if: steps.env.outputs.environment != 'none'
        uses: peter-evans/repository-dispatch@v2
        with:
          token: \${{ secrets.DEPLOYMENT_TOKEN }}
          repository: $GITHUB_ORG/$DEPLOYMENT_REPO
          event-type: \${{ steps.env.outputs.dispatch_type }}
          client-payload: |
            {
              "service_name": "$service",
              "service_repo": "$GITHUB_ORG/$service",
              "service_branch": "\${{ github.ref_name }}",
              "commit_sha": "\${{ github.sha }}",
              "commit_message": "\${{ github.event.head_commit.message }}",
              "pusher": "\${{ github.event.pusher.name }}"
            }

      - name: Log deployment trigger
        if: steps.env.outputs.environment != 'none'
        run: |
          echo "🚀 Triggered \${{ steps.env.outputs.environment }} deployment for $service"
          echo "Branch: \${{ github.ref_name }}"
          echo "Commit: \${{ github.sha }}"
          echo "Deployment repo: $GITHUB_ORG/$DEPLOYMENT_REPO"
EOF
        
        log_success "Created webhook workflow for $service"
    done
    
    log_success "All webhook workflows created in $workflow_dir/"
}

# --- Create GitHub Actions setup script ---
create_setup_script() {
    log_info "Creating setup script for service repositories..."
    
    cat > "setup-service-webhooks.sh" << 'EOF'
#!/bin/bash

# ==============================================================================
# Setup Script for Individual Service Repositories
# Run this script in each service repository
# ==============================================================================

set -e

SERVICE_NAME=$(basename $(pwd))
GITHUB_ORG="GITHUB_ORG_PLACEHOLDER"
DEPLOYMENT_REPO="DEPLOYMENT_REPO_PLACEHOLDER"

echo "Setting up webhook for service: $SERVICE_NAME"

# Create .github/workflows directory
mkdir -p .github/workflows

# Copy the webhook workflow
cp "../deployment/service-webhook-workflows/${SERVICE_NAME}-webhook.yml" ".github/workflows/deploy-on-merge.yml"

echo "✅ Webhook workflow installed for $SERVICE_NAME"
echo "📋 Next steps:"
echo "1. Add DEPLOYMENT_TOKEN secret to this repository"
echo "2. Commit and push the workflow file"
echo "3. Test by merging to develop branch"

EOF

    # Replace placeholders
    sed -i.tmp "s/GITHUB_ORG_PLACEHOLDER/$GITHUB_ORG/g" "setup-service-webhooks.sh"
    sed -i.tmp "s/DEPLOYMENT_REPO_PLACEHOLDER/$DEPLOYMENT_REPO/g" "setup-service-webhooks.sh"
    rm -f "setup-service-webhooks.sh.tmp"
    
    chmod +x "setup-service-webhooks.sh"
    
    log_success "Setup script created: setup-service-webhooks.sh"
}

# --- Create GitHub token setup instructions ---
create_token_instructions() {
    log_info "Creating GitHub token setup instructions..."
    
    cat > "WEBHOOK_SETUP_INSTRUCTIONS.md" << EOF
# GitHub Webhook Setup Instructions

## 🔑 Required GitHub Secrets

### 1. Create Personal Access Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Set expiration to "No expiration" or desired period
4. Select these scopes:
   - ✅ **repo** (Full control of private repositories)
   - ✅ **workflow** (Update GitHub Action workflows)
5. Click "Generate token"
6. **Copy the token** (you won't see it again)

### 2. Add Token to Each Service Repository

For each service repository ($GITHUB_ORG/auth-service, $GITHUB_ORG/user-service, etc.):

1. Go to repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: **DEPLOYMENT_TOKEN**
4. Value: **<your_personal_access_token>**
5. Click "Add secret"

### 3. Add Token to Deployment Repository

In your deployment repository ($GITHUB_ORG/$DEPLOYMENT_REPO):

1. Go to repository → Settings → Secrets and variables → Actions
2. Add these secrets if not already present:
   - **VPS_SSH_KEY**: SSH private key for staging server
   - **VPS_HOST**: 103.168.19.241
   - **VPS_PORT**: 7576
   - **VPS_USER**: root
   - **PROD_VPS_SSH_KEY**: SSH private key for production server (when ready)
   - **PROD_VPS_HOST**: your production server IP
   - **PROD_VPS_PORT**: production SSH port
   - **PROD_VPS_USER**: production SSH user

## 🚀 Deployment Setup for Each Service

### Step 1: Install Webhook in Service Repositories

Run this in each service repository directory:

\`\`\`bash
# Clone or navigate to service repository
git clone https://github.com/$GITHUB_ORG/auth-service.git
cd auth-service

# Copy setup script from deployment repo
cp ../deployment/setup-service-webhooks.sh .
./setup-service-webhooks.sh

# Commit the webhook workflow
git add .github/workflows/deploy-on-merge.yml
git commit -m "Add automatic deployment webhook"
git push origin main
\`\`\`

### Step 2: Test Automatic Deployment

**For Staging (develop branch):**
\`\`\`bash
# In service repository
git checkout develop
echo "# Test change" >> README.md
git add README.md
git commit -m "Test staging deployment"
git push origin develop
\`\`\`

**For Production (main branch):**
\`\`\`bash
# In service repository  
git checkout main
git merge develop
git push origin main
\`\`\`

## 📋 Workflow Summary

| Branch | Environment | Trigger | Deployment |
|--------|-------------|---------|------------|
| **develop** | Staging | Auto on push | Immediate |
| **main** | Production | Auto on push | With tests |

## 🔍 Monitoring Deployments

1. **Service Repository**: Check Actions tab for webhook triggers
2. **Deployment Repository**: Check Actions tab for actual deployments
3. **VPS**: Monitor service health at http://103.168.19.241

## 🛠️ Troubleshooting

### Webhook Not Triggering
- Check DEPLOYMENT_TOKEN secret is set in service repository
- Verify token has correct permissions
- Check Actions tab for error messages

### Deployment Failing
- Check deployment repository Actions tab
- Verify VPS secrets are correctly set
- Check VPS connectivity and service health

### Service Not Starting
- Check Docker container logs on VPS
- Verify service has /health endpoint
- Check environment variables and configuration

---

**🎉 Once set up, your services will automatically deploy when code is merged!**
EOF

    log_success "Instructions created: WEBHOOK_SETUP_INSTRUCTIONS.md"
}

# --- Update deployment workflows ---
update_deployment_workflows() {
    log_info "Copying automatic deployment workflows..."
    
    # Copy the auto-deploy workflows to main workflows directory
    cp ".github/workflows/auto-deploy-staging.yml" "../.github/workflows/" 2>/dev/null || true
    cp ".github/workflows/auto-deploy-production.yml" "../.github/workflows/" 2>/dev/null || true
    
    log_success "Automatic deployment workflows updated"
}

# --- Main function ---
main() {
    echo -e "${C_BLUE}===================================================${C_RESET}"
    echo -e "${C_BLUE}    GitHub Webhooks Setup for Auto Deployment${C_RESET}"
    echo -e "${C_BLUE}===================================================${C_RESET}"
    
    get_configuration
    create_service_webhook_workflow
    create_setup_script
    create_token_instructions
    update_deployment_workflows
    
    echo -e "\n${C_GREEN}===================================================${C_RESET}"
    echo -e "${C_GREEN}    Webhook Setup Completed!${C_RESET}"
    echo -e "${C_GREEN}===================================================${C_RESET}"
    
    echo -e "\n${C_YELLOW}📋 Next Steps:${C_RESET}"
    echo "1. Read: WEBHOOK_SETUP_INSTRUCTIONS.md"
    echo "2. Create GitHub Personal Access Token"
    echo "3. Add DEPLOYMENT_TOKEN to each service repository"
    echo "4. Run ./setup-service-webhooks.sh in each service repository"
    echo "5. Test by pushing to develop branch"
    echo
    echo -e "${C_YELLOW}📁 Files Created:${C_RESET}"
    echo "• service-webhook-workflows/ - Webhook workflows for each service"
    echo "• setup-service-webhooks.sh - Script to install webhooks in service repos"
    echo "• WEBHOOK_SETUP_INSTRUCTIONS.md - Complete setup guide"
    echo
    echo -e "${C_GREEN}🚀 Auto-deployment is ready! Services will deploy automatically when merged.${C_RESET}"
}

# Execute main function
main "$@"
