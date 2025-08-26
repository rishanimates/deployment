# GitHub Repository Creation Guide

## 🎯 **Issue Resolution**

**Error:** `fatal: repository 'https://github.com/rishanimates/auth-service/' not found`

**Root Cause:** The service repositories don't exist on GitHub yet.

## 🚀 **Solution Options**

### Option 1: Automatic Creation (Recommended)

**Prerequisites:**
- GitHub CLI installed: `brew install gh` (macOS) or `sudo apt install gh` (Ubuntu)
- Authenticated with GitHub: `gh auth login`

**Run the creation script:**
```bash
cd deployment
./create-github-repositories.sh
```

This will:
- ✅ Create all 6 service repositories on GitHub
- ✅ Initialize local git repositories
- ✅ Push existing code to GitHub
- ✅ Set up develop and main branches
- ✅ Create README and .gitignore files

### Option 2: Manual Creation

If you prefer to create repositories manually:

#### Step 1: Create Repositories on GitHub
Visit https://github.com/new and create these repositories:

1. **rishanimates/auth-service**
   - Description: "Authentication and authorization service for LetzGo platform"
   - Visibility: Public (or Private if preferred)

2. **rishanimates/user-service**
   - Description: "User management and profiles service"

3. **rishanimates/chat-service**
   - Description: "Real-time messaging and communication service"

4. **rishanimates/event-service**
   - Description: "Event management and ticketing service"

5. **rishanimates/shared-service**
   - Description: "Shared utilities for storage, payments, and notifications"

6. **rishanimates/splitz-service**
   - Description: "Expense splitting and management service"

#### Step 2: Push Existing Code
For each service directory (auth-service, user-service, etc.):

```bash
# Navigate to service directory
cd ../auth-service  # (or user-service, chat-service, etc.)

# Initialize git repository
git init

# Add remote origin
git remote add origin git@github.com:rishanimates/auth-service.git

# Create .gitignore
cat > .gitignore << 'EOF'
node_modules/
.env
*.log
coverage/
.nyc_output
.DS_Store
dist/
build/
EOF

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: auth-service setup"

# Create develop branch
git checkout -b develop

# Push both branches
git push -u origin develop
git checkout main
git push -u origin main
```

## 🔍 **Verify Repository Creation**

Check if repositories exist:
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

## 🔧 **GitHub Actions Configuration**

### Repository Format for GitHub Actions:
The workflows are correctly configured to use:
```yaml
repository: rishanimates/auth-service  # ✅ Correct format
```

### Authentication:
- **Public repositories:** Use `GITHUB_TOKEN` (automatic)
- **Private repositories:** May need Personal Access Token

### SSH vs HTTPS:
- **GitHub Actions:** Uses `owner/repo` format internally
- **Local development:** Use SSH (`git@github.com:rishanimates/service.git`)
- **Manual cloning:** Use SSH for authentication

## 🚀 **Post-Creation Setup**

### 1. Install Webhooks
After repositories are created, install webhooks in each:
```bash
# In each service repository
cd ../auth-service
cp ../deployment/setup-service-webhooks.sh .
./setup-service-webhooks.sh

# Commit webhook
git add .github/workflows/deploy-on-merge.yml
git commit -m "Add automatic deployment webhook"
git push origin main
```

### 2. Add GitHub Secrets
For each service repository, add these secrets:
- **DEPLOYMENT_TOKEN**: Personal Access Token with repo and workflow permissions

### 3. Test Deployment
```bash
# In any service repository
git checkout develop
echo "# Test change" >> README.md
git add README.md
git commit -m "Test staging deployment"
git push origin develop
# 🚀 Should trigger automatic staging deployment
```

## 📊 **Repository Structure**

After creation, each repository will have:
```
service-name/
├── .github/
│   └── workflows/
│       └── deploy-on-merge.yml    # Automatic deployment webhook
├── src/                           # Service source code
├── package.json                   # Dependencies and scripts
├── .gitignore                     # Git ignore rules
├── README.md                      # Service documentation
└── .env.example                   # Environment variables template
```

## 🎯 **Expected Workflow**

1. **Developer pushes to develop** → **Staging deployment**
2. **Developer pushes to main** → **Production deployment**
3. **GitHub Actions** → **Deploys to VPS automatically**

---

**🎉 Once repositories are created, your automatic deployment system will work without the "repository not found" errors!**
