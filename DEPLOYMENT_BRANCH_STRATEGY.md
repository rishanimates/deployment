# 🌿 LetzGo Deployment Branch Strategy

## **📋 OVERVIEW**

This document explains how branches work in the LetzGo deployment system and how the recent GitHub Actions fix resolves branch checkout issues.

## **🏗️ REPOSITORY STRUCTURE**

### **Two Types of Repositories**:

1. **🚀 Deployment Repository** (`deployment/`)
   - **Purpose**: Contains deployment scripts and workflows
   - **Branch Strategy**: Primarily uses `main` branch
   - **Content**: Infrastructure and service deployment scripts

2. **📦 Service Repositories** (Individual repos)
   - **Purpose**: Contains actual application code
   - **Branch Strategy**: `main`, `develop`, `staging`, etc.
   - **Content**: Node.js microservices code

## **🔧 BRANCH SELECTION LOGIC**

### **How It Works**:
```
GitHub Actions (Deployment Repo: main)
    ↓
Deploy Script on VPS
    ↓
Clone Services (Selected Branch: develop/main/staging)
    ↓
Build & Deploy Containers
```

### **Branch Fallback Chain**:
1. **SSH Clone** from selected branch → If fails:
2. **HTTPS Clone** from selected branch → If fails:
3. **HTTPS Clone** from `main` branch → If fails:
4. **Deployment fails** with error

## **✅ GITHUB ACTIONS FIX**

### **Problem Before**:
```yaml
# ❌ This was failing
- name: Checkout code
  uses: actions/checkout@v4
  with:
    ref: ${{ github.event.inputs.branch }}  # Tried to checkout 'develop' from deployment repo
```

**Error**: `The process '/usr/bin/git' failed with exit code 1`

### **Solution After**:
```yaml
# ✅ This works
- name: Checkout deployment repo
  uses: actions/checkout@v4
  # Always checkout main branch for deployment scripts
  # The service branch selection happens during deployment
```

## **🎯 WORKFLOW BEHAVIOR**

### **Successful Deployment Flow**:
```
1. User selects: Services = "auth-service,user-service", Branch = "develop"
2. GitHub Actions: Checkout main branch of deployment repo ✅
3. Copy Scripts: Transfer deploy-services.sh to VPS ✅
4. Execute Script: Run deployment with branch parameter ✅
5. Clone Services: 
   - git clone -b develop auth-service ✅
   - git clone -b develop user-service ✅
6. Build & Deploy: Create containers from cloned code ✅
```

### **Branch Fallback Example**:
```
🌿 Requested: develop branch
⚠️  SSH failed: Trying HTTPS...
⚠️  HTTPS develop failed: Trying main branch...
✅ Success: Cloned from main branch (fallback)
⚠️  Note: Deployed from 'main' branch instead of 'develop'
```

## **📝 USAGE GUIDELINES**

### **Service Branch Selection**:
- **`main`**: Production-ready, stable code
- **`develop`**: Latest development features
- **`staging`**: Pre-production testing
- **`master`**: Legacy main branch (if used)

### **When to Use Each Branch**:

| Environment | Recommended Branch | Purpose |
|-------------|-------------------|---------|
| **Production** | `main` | Stable, tested code |
| **Staging** | `staging` or `develop` | Pre-production testing |
| **Development** | `develop` | Latest features |
| **Hotfix** | `main` | Critical fixes |

## **🚀 GITHUB ACTIONS INTERFACE**

### **Workflow Inputs**:
```yaml
Services: "auth-service,user-service,chat-service,event-service,shared-service,splitz-service or all"
Branch: main | develop | staging | master
Force Rebuild: true/false
```

### **Expected Output**:
```
🏗️ Deployment Configuration:
  📁 Deployment repo branch: main
  🌿 Services will be deployed from: develop branch
  🎯 Services to deploy: auth-service,user-service
  🔄 Force rebuild: false

📝 Note: If a service repository doesn't have the 'develop' branch,
         the deployment script will automatically fallback to HTTPS and then main branch.
```

## **🛠️ TROUBLESHOOTING**

### **Common Issues**:

1. **"Branch not found" in service repo**:
   - **Solution**: Script automatically falls back to `main`
   - **Action**: Check if the branch exists in the service repository

2. **"Permission denied" during clone**:
   - **Solution**: Script tries HTTPS as fallback
   - **Action**: Ensure service repositories are public or SSH keys are configured

3. **"Repository not found"**:
   - **Solution**: Check repository URL in `SERVICE_REPOS` configuration
   - **Action**: Verify repository exists and is accessible

### **Debug Steps**:
1. **Check branch exists**: Go to service repository on GitHub
2. **Verify permissions**: Ensure repository is accessible
3. **Review logs**: Check GitHub Actions logs for specific errors
4. **Test manually**: Try cloning the repository manually with the same branch

## **🎉 BENEFITS OF THE FIX**

### **Before Fix**:
- ❌ Workflow failed if branch didn't exist in deployment repo
- ❌ Confusing error messages
- ❌ No fallback mechanism

### **After Fix**:
- ✅ Deployment repo always uses `main` (stable scripts)
- ✅ Service branch selection works independently
- ✅ Automatic fallback chain for missing branches
- ✅ Clear logging and error messages
- ✅ Robust error handling

## **📊 BRANCH USAGE EXAMPLES**

### **Scenario 1: Feature Development**
```bash
# Deploy latest features to staging environment
Services: all
Branch: develop
Force Rebuild: false
```

### **Scenario 2: Production Deployment**
```bash
# Deploy stable code to production
Services: all
Branch: main
Force Rebuild: false
```

### **Scenario 3: Single Service Update**
```bash
# Deploy only updated service
Services: auth-service
Branch: main
Force Rebuild: true
```

### **Scenario 4: Emergency Hotfix**
```bash
# Deploy critical fix immediately
Services: auth-service,user-service
Branch: main
Force Rebuild: true
```

---

**🎯 This branch strategy ensures reliable deployments while providing flexibility for different development workflows and environments.**
