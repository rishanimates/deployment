#!/bin/bash

# ==============================================================================
# Setup GitHub Secrets for Private Repository Access
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

echo -e "${C_BLUE}===================================================${C_RESET}"
echo -e "${C_BLUE}    Private Repository Secrets Setup${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

GITHUB_ORG="rishanimates"
DEPLOYMENT_REPO="rishanimates/deployment"
SERVICE_REPOS=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")

echo -e "\n${C_YELLOW}🔐 GitHub Secrets Required for Private Repositories${C_RESET}"
echo
echo "Since your service repositories are private, you need to configure"
echo "Personal Access Token secrets for cross-repository access."

echo -e "\n${C_YELLOW}📋 Required Secrets Configuration:${C_RESET}"
echo

echo -e "${C_BLUE}1. Deployment Repository ($DEPLOYMENT_REPO):${C_RESET}"
echo "   • DEPLOYMENT_TOKEN: Personal Access Token with repo permissions"
echo "   • VPS_SSH_KEY: SSH private key for VPS access"
echo "   • VPS_HOST: 103.168.19.241"
echo "   • VPS_PORT: 7576"
echo "   • VPS_USER: root"

echo -e "\n${C_BLUE}2. Each Service Repository:${C_RESET}"
for service in "${SERVICE_REPOS[@]}"; do
    echo "   • rishanimates/$service:"
    echo "     - DEPLOYMENT_TOKEN: Same Personal Access Token"
done

echo -e "\n${C_YELLOW}🔑 Personal Access Token Setup:${C_RESET}"
echo
echo "1. Go to: https://github.com/settings/tokens"
echo "2. Click 'Generate new token (classic)'"
echo "3. Set expiration (recommend: No expiration for automation)"
echo "4. Select scopes:"
echo "   ✅ repo (Full control of private repositories)"
echo "   ✅ workflow (Update GitHub Action workflows)"
echo "   ✅ read:org (Read organization membership)"
echo "5. Click 'Generate token'"
echo "6. COPY THE TOKEN (you won't see it again!)"

echo -e "\n${C_YELLOW}📝 Adding Secrets to Repositories:${C_RESET}"
echo

# Check if GitHub CLI is available
if command -v gh &> /dev/null; then
    log_info "GitHub CLI detected. You can use automated setup."
    echo
    read -p "Do you want to set up secrets automatically using GitHub CLI? (y/n): " use_gh_cli
    
    if [[ $use_gh_cli =~ ^[Yy]$ ]]; then
        echo
        read -s -p "Enter your Personal Access Token: " PAT_TOKEN
        echo
        
        log_info "Setting up secrets for deployment repository..."
        if gh secret set DEPLOYMENT_TOKEN --body "$PAT_TOKEN" --repo "$DEPLOYMENT_REPO"; then
            log_success "✅ DEPLOYMENT_TOKEN set for $DEPLOYMENT_REPO"
        else
            log_error "❌ Failed to set DEPLOYMENT_TOKEN for $DEPLOYMENT_REPO"
        fi
        
        log_info "Setting up secrets for service repositories..."
        for service in "${SERVICE_REPOS[@]}"; do
            if gh secret set DEPLOYMENT_TOKEN --body "$PAT_TOKEN" --repo "$GITHUB_ORG/$service"; then
                log_success "✅ DEPLOYMENT_TOKEN set for $GITHUB_ORG/$service"
            else
                log_warning "⚠️  Failed to set DEPLOYMENT_TOKEN for $GITHUB_ORG/$service"
            fi
        done
        
        echo -e "\n${C_GREEN}✅ Automated secret setup completed!${C_RESET}"
    else
        echo -e "\n${C_YELLOW}Manual setup instructions below...${C_RESET}"
    fi
else
    log_warning "GitHub CLI not found. Using manual setup instructions."
fi

echo -e "\n${C_YELLOW}📖 Manual Secret Setup Instructions:${C_RESET}"
echo

echo -e "${C_BLUE}For Deployment Repository ($DEPLOYMENT_REPO):${C_RESET}"
echo "1. Go to: https://github.com/$DEPLOYMENT_REPO/settings/secrets/actions"
echo "2. Click 'New repository secret'"
echo "3. Add these secrets:"
echo "   Name: DEPLOYMENT_TOKEN"
echo "   Value: <your_personal_access_token>"
echo "4. Click 'Add secret'"
echo

echo -e "${C_BLUE}For Each Service Repository:${C_RESET}"
for service in "${SERVICE_REPOS[@]}"; do
    echo "• https://github.com/$GITHUB_ORG/$service/settings/secrets/actions"
done
echo "  Add secret: DEPLOYMENT_TOKEN = <your_personal_access_token>"

echo -e "\n${C_YELLOW}🧪 Testing Private Repository Access:${C_RESET}"
echo

cat << 'EOF'
After setting up secrets, test with a simple workflow:

1. Go to any service repository
2. Push a small change to develop branch:
   ```bash
   git checkout develop
   echo "# Test private repo access" >> README.md
   git add README.md
   git commit -m "Test private repository deployment"
   git push origin develop
   ```

3. Check deployment repository Actions tab:
   - Should see "Auto Deploy to Staging" workflow triggered
   - Should successfully checkout private service repository
   - Should build and deploy to staging VPS

Expected workflow log:
✅ Checkout service repository (using DEPLOYMENT_TOKEN)
✅ Setup Node.js
✅ Install dependencies  
✅ Build Docker image
✅ Deploy to VPS
EOF

echo -e "\n${C_YELLOW}🔍 Troubleshooting Private Repository Issues:${C_RESET}"
echo

echo "❌ Error: 'repository not found' or 'access denied'"
echo "   → Check DEPLOYMENT_TOKEN has 'repo' permission"
echo "   → Verify token is set in both deployment and service repositories"
echo "   → Ensure token hasn't expired"
echo

echo "❌ Error: 'bad credentials'"
echo "   → Regenerate Personal Access Token"
echo "   → Update DEPLOYMENT_TOKEN secret in all repositories"
echo

echo "❌ Webhook not triggering deployment"
echo "   → Check DEPLOYMENT_TOKEN in service repository"
echo "   → Verify webhook workflow is installed in service repo"
echo "   → Check repository dispatch permissions"

echo -e "\n${C_YELLOW}✅ Verification Checklist:${C_RESET}"
echo "□ Personal Access Token created with repo + workflow permissions"
echo "□ DEPLOYMENT_TOKEN secret added to deployment repository"
echo "□ DEPLOYMENT_TOKEN secret added to all 6 service repositories"
echo "□ Webhook workflows installed in all service repositories"
echo "□ Test deployment triggered successfully"

echo -e "\n${C_GREEN}===================================================${C_RESET}"
echo -e "${C_GREEN}    Private Repository Setup Guide Complete!${C_RESET}"
echo -e "${C_GREEN}===================================================${C_RESET}"

echo -e "\n${C_YELLOW}🚀 Next Steps:${C_RESET}"
echo "1. Set up the DEPLOYMENT_TOKEN secrets as shown above"
echo "2. Install webhooks: ./setup-service-webhooks.sh in each service repo"
echo "3. Test by pushing to develop branch in any service"
echo "4. Monitor deployment in GitHub Actions"

echo -e "\n${C_GREEN}🎉 Your private repositories will now work with automatic deployment!${C_RESET}"
