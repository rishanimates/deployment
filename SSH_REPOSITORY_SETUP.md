# SSH Repository Setup - Complete Guide

## 🔍 **Issue Analysis**

**Error:** `fatal: repository 'https://github.com/rishanimates/auth-service/' not found`

**Root Causes:**
1. ❌ Service repositories don't exist on GitHub yet
2. ❌ GitHub Actions trying to checkout non-existent repositories

## ✅ **Complete Solution**

### 1. **Repository Format for GitHub Actions**
GitHub Actions `checkout` requires `owner/repo` format (already configured correctly):
```yaml
# ✅ Correct format for GitHub Actions
repository: rishanimates/auth-service
```

### 2. **SSH URLs for Local Development**
For local git operations, use SSH format:
```bash
# ✅ SSH format for local cloning
git clone git@github.com:rishanimates/auth-service.git
```

## 🚀 **Repository Creation Process**

### Option A: Automatic Creation (Recommended)
```bash
cd deployment

# Check current status
./check-repositories.sh

# Create all repositories automatically
./create-github-repositories.sh

# Verify creation
./check-repositories.sh
```

### Option B: Manual Creation
1. Visit https://github.com/new
2. Create each repository manually:
   - `rishanimates/auth-service`
   - `rishanimates/user-service`
   - `rishanimates/chat-service`
   - `rishanimates/event-service`
   - `rishanimates/shared-service`
   - `rishanimates/splitz-service`

3. Push existing code:
```bash
cd deployment
./push-to-github.sh
```

## 📋 **Repository Configuration**

### Current Setup:
```json
{
  "services": {
    "auth-service": {
      "repository": "rishanimates/auth-service",    // ✅ GitHub Actions format
      "default_branch": "develop",                  // ✅ Staging branch
      "port": 3000
    }
    // ... other services
  }
}
```

### SSH URLs for Local Development:
- `git@github.com:rishanimates/auth-service.git`
- `git@github.com:rishanimates/user-service.git`
- `git@github.com:rishanimates/chat-service.git`
- `git@github.com:rishanimates/event-service.git`
- `git@github.com:rishanimates/shared-service.git`
- `git@github.com:rishanimates/splitz-service.git`

## 🔧 **GitHub Actions Workflow**

### How it Works:
1. **Webhook Trigger:** Service repo push → `rishanimates/deployment`
2. **Checkout:** Uses `owner/repo` format with GitHub token
3. **Build:** Creates Docker image
4. **Deploy:** Pushes to VPS

### Authentication:
- **Public repos:** `GITHUB_TOKEN` (automatic)
- **Private repos:** Personal Access Token (if needed)

## 🎯 **Deployment Flow**

### Branch-Based Deployment:
```
develop branch → Staging (103.168.19.241)
main branch    → Production (when configured)
```

### Webhook Flow:
```
Service Repo → Webhook → Deployment Repo → VPS
```

## 🛠️ **Setup Scripts Created**

### 1. **check-repositories.sh**
```bash
./check-repositories.sh
# Checks if repositories exist on GitHub
```

### 2. **create-github-repositories.sh**
```bash
./create-github-repositories.sh
# Creates all repositories using GitHub CLI
```

### 3. **push-to-github.sh**
```bash
./push-to-github.sh
# Pushes existing service code to GitHub
```

## 🔍 **Verification Steps**

### 1. Check Repository Status:
```bash
cd deployment
./check-repositories.sh
```

Expected output:
```
✅ rishanimates/auth-service... EXISTS
✅ rishanimates/user-service... EXISTS
✅ rishanimates/chat-service... EXISTS
✅ rishanimates/event-service... EXISTS
✅ rishanimates/shared-service... EXISTS
✅ rishanimates/splitz-service... EXISTS
```

### 2. Test GitHub Actions Format:
The workflows use correct format:
```yaml
uses: actions/checkout@v4
with:
  repository: rishanimates/auth-service  # ✅ Correct
  ref: develop
  token: ${{ secrets.GITHUB_TOKEN }}
```

### 3. Test SSH Access:
```bash
# Test SSH connection to GitHub
ssh -T git@github.com

# Clone using SSH
git clone git@github.com:rishanimates/auth-service.git
```

## 🚀 **Post-Creation Steps**

### 1. Install Webhooks:
```bash
# In each service repository
cd ../auth-service
cp ../deployment/setup-service-webhooks.sh .
./setup-service-webhooks.sh
git add .github/workflows/deploy-on-merge.yml
git commit -m "Add automatic deployment webhook"
git push origin main
```

### 2. Add GitHub Secrets:
For each service repository:
- **DEPLOYMENT_TOKEN**: Personal Access Token

### 3. Test Deployment:
```bash
# In any service repository
git checkout develop
echo "# Test" >> README.md
git add README.md
git commit -m "Test deployment"
git push origin develop
# 🚀 Should trigger staging deployment
```

## 📊 **Expected Results**

### After Repository Creation:
- ✅ No more "repository not found" errors
- ✅ GitHub Actions can checkout service code
- ✅ Automatic deployments work
- ✅ SSH access for local development

### Deployment Matrix:
| Branch | Environment | Trigger | Status |
|--------|-------------|---------|---------|
| develop | staging | Auto | ✅ Ready |
| main | production | Auto | ✅ Ready |

---

**🎉 Once repositories are created, your SSH-based deployment system will work perfectly with automatic staging and production deployments!**
