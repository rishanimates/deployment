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

For each service repository (rishanimates/auth-service, rishanimates/user-service, etc.):

1. Go to repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: **DEPLOYMENT_TOKEN**
4. Value: **<your_personal_access_token>**
5. Click "Add secret"

### 3. Add Token to Deployment Repository

In your deployment repository (rishanimates/deployment):

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

```bash
# Clone or navigate to service repository
git clone https://github.com/rishanimates/auth-service.git
cd auth-service

# Copy setup script from deployment repo
cp ../deployment/setup-service-webhooks.sh .
./setup-service-webhooks.sh

# Commit the webhook workflow
git add .github/workflows/deploy-on-merge.yml
git commit -m "Add automatic deployment webhook"
git push origin main
```

### Step 2: Test Automatic Deployment

**For Staging (develop branch):**
```bash
# In service repository
git checkout develop
echo "# Test change" >> README.md
git add README.md
git commit -m "Test staging deployment"
git push origin develop
```

**For Production (main branch):**
```bash
# In service repository  
git checkout main
git merge develop
git push origin main
```

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
