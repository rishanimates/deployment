# Private Repository Deployment Guide

## 🔒 **Private Repository Configuration**

Your service repositories are **private**, which requires special authentication setup for GitHub Actions to access them across repositories.

### 📋 **Repository Status**
- ✅ **rishanimates/auth-service** (Private)
- ✅ **rishanimates/user-service** (Private) 
- ✅ **rishanimates/chat-service** (Private)
- ✅ **rishanimates/event-service** (Private)
- ✅ **rishanimates/shared-service** (Private)
- ✅ **rishanimates/splitz-service** (Private)

### 🔧 **Authentication Fix Applied**

**Updated GitHub Actions workflows to use Personal Access Token:**
```yaml
# ❌ BEFORE (doesn't work for private repos)
token: ${{ secrets.GITHUB_TOKEN }}

# ✅ AFTER (works for private repos)  
token: ${{ secrets.DEPLOYMENT_TOKEN }}
```

**Files Updated:**
- ✅ `.github/workflows/auto-deploy-staging.yml`
- ✅ `.github/workflows/auto-deploy-production.yml`
- ✅ `.github/workflows/deploy-services-multi-repo.yml`

## 🔑 **Required GitHub Secrets Setup**

### 1. **Create Personal Access Token**

**Go to:** https://github.com/settings/tokens

**Configuration:**
```
Name: Deployment Token for Private Repos
Expiration: No expiration (recommended for automation)
Scopes:
  ✅ repo (Full control of private repositories)
  ✅ workflow (Update GitHub Action workflows)  
  ✅ read:org (Read organization membership)
```

**⚠️ CRITICAL:** The `repo` scope is **essential** for accessing private repositories.

### 2. **Add DEPLOYMENT_TOKEN to Repositories**

**Deployment Repository:**
- Repository: `rishanimates/deployment`
- URL: https://github.com/rishanimates/deployment/settings/secrets/actions
- Secret: `DEPLOYMENT_TOKEN` = `<your_personal_access_token>`

**Each Service Repository:**
- `rishanimates/auth-service/settings/secrets/actions`
- `rishanimates/user-service/settings/secrets/actions`
- `rishanimates/chat-service/settings/secrets/actions`
- `rishanimates/event-service/settings/secrets/actions`
- `rishanimates/shared-service/settings/secrets/actions`
- `rishanimates/splitz-service/settings/secrets/actions`

**Secret for each:** `DEPLOYMENT_TOKEN` = `<your_personal_access_token>`

## 🚀 **Automated Setup (Optional)**

Run the setup script for guided configuration:
```bash
cd deployment
./setup-private-repo-secrets.sh
```

This script will:
- ✅ Guide you through Personal Access Token creation
- ✅ Optionally set secrets automatically (requires GitHub CLI)
- ✅ Provide manual setup instructions
- ✅ Give troubleshooting tips

## 🔄 **How Private Repository Access Works**

### Workflow Sequence:
1. **Service Repository** (private) → Push to `develop` branch
2. **Webhook Trigger** → Dispatches to `rishanimates/deployment`
3. **Deployment Repository** → Runs `auto-deploy-staging.yml`
4. **Checkout Step** → Uses `DEPLOYMENT_TOKEN` to access private service repo
5. **Build & Deploy** → Creates Docker image and deploys to VPS

### Authentication Flow:
```yaml
# In deployment repository workflow
- name: Checkout service repository
  uses: actions/checkout@v4
  with:
    repository: rishanimates/auth-service  # Private repo
    ref: develop
    token: ${{ secrets.DEPLOYMENT_TOKEN }}  # Personal Access Token
    path: service-code
```

## 🧪 **Testing Private Repository Access**

### Test Staging Deployment:
```bash
# In any service repository (e.g., auth-service)
git checkout develop
echo "# Test private repo deployment" >> README.md
git add README.md
git commit -m "Test private repository access"
git push origin develop
```

### Expected Results:
1. ✅ Webhook triggers deployment repository
2. ✅ Deployment workflow starts
3. ✅ Successfully checks out private service repository
4. ✅ Builds Docker image
5. ✅ Deploys to staging VPS

### Monitor Progress:
- **Service Repository:** Check Actions tab for webhook trigger
- **Deployment Repository:** Check Actions tab for actual deployment
- **VPS:** Check service health at http://103.168.19.241

## 🔍 **Troubleshooting Private Repository Issues**

### ❌ Error: "Repository not found"
```
fatal: repository 'https://github.com/rishanimates/auth-service/' not found
```
**Solution:**
- ✅ Verify `DEPLOYMENT_TOKEN` is set in deployment repository
- ✅ Check Personal Access Token has `repo` permission
- ✅ Ensure token hasn't expired

### ❌ Error: "Bad credentials"
```
remote: Invalid username or password
```
**Solution:**
- ✅ Regenerate Personal Access Token
- ✅ Update `DEPLOYMENT_TOKEN` secret in all repositories
- ✅ Verify token has correct permissions

### ❌ Error: "Resource not accessible by integration"
```
Error: Resource not accessible by integration
```
**Solution:**
- ✅ Add `read:org` permission to Personal Access Token
- ✅ Verify you have admin access to the repositories
- ✅ Check organization settings allow Personal Access Tokens

### ❌ Webhook Not Triggering
**Check:**
- ✅ `DEPLOYMENT_TOKEN` is set in service repository
- ✅ Webhook workflow is installed in service repository
- ✅ Repository dispatch permissions are correct

## 📊 **Security Considerations**

### Personal Access Token Security:
- 🔒 **Store securely:** Only in GitHub repository secrets
- ⏰ **Monitor expiration:** Set up renewal reminders
- 🔄 **Rotate regularly:** Update token periodically
- 👥 **Limit scope:** Only necessary permissions

### Repository Access:
- 🔐 **Private repos:** Keep sensitive code private
- 🛡️ **Branch protection:** Protect main/develop branches
- 👨‍💻 **Team access:** Manage collaborator permissions
- 📝 **Audit logs:** Monitor repository access

## ✅ **Verification Checklist**

**Before Testing:**
- [ ] Personal Access Token created with `repo` + `workflow` + `read:org` permissions
- [ ] `DEPLOYMENT_TOKEN` secret added to deployment repository
- [ ] `DEPLOYMENT_TOKEN` secret added to all 6 service repositories
- [ ] Webhook workflows installed in all service repositories
- [ ] VPS secrets (SSH keys) configured in deployment repository

**After Testing:**
- [ ] Test deployment triggered successfully
- [ ] Private repository checkout worked
- [ ] Docker image built successfully
- [ ] Service deployed to staging VPS
- [ ] Health check passes

## 🎯 **Expected Deployment Flow**

### Staging (develop branch):
```
Private Service Repo (develop) 
    ↓ (webhook with DEPLOYMENT_TOKEN)
Deployment Repo (auto-deploy-staging.yml)
    ↓ (checkout with DEPLOYMENT_TOKEN)  
Private Service Code Retrieved
    ↓ (build & deploy)
Staging VPS (103.168.19.241)
```

### Production (main branch):
```
Private Service Repo (main)
    ↓ (webhook with DEPLOYMENT_TOKEN)
Deployment Repo (auto-deploy-production.yml)
    ↓ (checkout with DEPLOYMENT_TOKEN)
Private Service Code Retrieved
    ↓ (build & deploy with tests)
Production VPS
```

---

**🎉 With proper Personal Access Token configuration, your private repositories will work seamlessly with automatic deployment!**
