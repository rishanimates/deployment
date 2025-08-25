# LetzGo Staging Environment Configuration

## 🎯 **Environment Setup**

Your VPS at `103.168.19.241` is now configured as a **staging environment** rather than production. This is a best practice for development and testing.

## 🔧 **Changes Applied**

### 1. **GitHub Actions Environment**
All workflows now use `staging` environment:
- **Infrastructure Deployment**: `deploy.yml` → staging
- **Service Deployment**: `deploy-services.yml` → staging  
- **Rollback**: `rollback.yml` → staging

### 2. **Environment Variables**
- `NODE_ENV=staging` (instead of production)
- Environment template updated for staging
- Default environment selection changed to staging

### 3. **GitHub Secrets**
Your GitHub repository secrets should be configured for staging:
```
VPS_HOST=103.168.19.241
VPS_PORT=7576
VPS_USER=root
VPS_SSH_KEY=<your_ssh_private_key>
```

## 🚀 **Deployment Workflow**

### Staging Deployment (Current Setup)
```bash
# Deploy infrastructure to staging
git add deployment/
git commit -m "Deploy infrastructure to staging"
git push origin main

# Deploy services to staging
git add auth-service/
git commit -m "Update auth service for staging"
git push origin main
```

### When Ready for Production
When you're ready to deploy to a production server, you can:

1. **Option A: Use Manual Workflow Dispatch**
   - Go to GitHub Actions
   - Select "Deploy Services" or "Infrastructure Deployment"
   - Choose "production" from the environment dropdown
   - Update VPS details for production server

2. **Option B: Create Production Branch**
   ```bash
   git checkout -b production
   # Update workflows to use production environment
   git push origin production
   ```

## 📋 **Environment Comparison**

| Aspect | Staging (Current) | Production (Future) |
|--------|------------------|-------------------|
| **VPS** | 103.168.19.241 | Your production server |
| **NODE_ENV** | staging | production |
| **Branch** | main | main or production |
| **Secrets** | Less sensitive | Highly sensitive |
| **SSL** | Optional | Required |
| **Monitoring** | Basic | Comprehensive |
| **Backups** | Regular | Critical |

## 🔒 **Security Considerations**

### Staging Environment
- ✅ Use test data only
- ✅ Relaxed SSL requirements
- ✅ Debug logging enabled
- ✅ Development-friendly configuration

### Production Environment (Future)
- 🔐 Real user data
- 🔐 SSL/TLS certificates required
- 🔐 Minimal logging
- 🔐 Strict security policies
- 🔐 Separate database credentials

## 🛠️ **Configuration Files Updated**

1. **Workflows**:
   - `.github/workflows/deploy.yml` - Infrastructure staging deployment
   - `.github/workflows/deploy-services.yml` - Service staging deployment
   - `.github/workflows/rollback.yml` - Staging rollback

2. **Environment**:
   - `deployment/env.template` - Staging environment template
   - Auto-generated `.env` includes `NODE_ENV=staging`

3. **Default Settings**:
   - Manual workflow dispatch defaults to "staging"
   - Environment protection rules apply to staging

## 📊 **Monitoring Staging Environment**

### Health Checks
```bash
# Infrastructure health
curl http://103.168.19.241/health

# Service health  
curl http://103.168.19.241:3000/health  # auth-service
curl http://103.168.19.241:3001/health  # user-service
curl http://103.168.19.241:3002/health  # chat-service
curl http://103.168.19.241:3003/health  # event-service
curl http://103.168.19.241:3004/health  # shared-service
curl http://103.168.19.241:3005/health  # splitz-service
```

### Container Status
```bash
ssh -p 7576 root@103.168.19.241
docker ps | grep letzgo
```

### Logs
```bash
# Infrastructure logs
tail -f /opt/letzgo/logs/infrastructure-deployment.log

# Service logs
docker logs letzgo-auth-service -f
```

## 🔄 **Migration to Production**

When you're ready to set up a production environment:

1. **Get Production Server**
   - Separate VPS/server for production
   - Higher specs and better security
   - SSL certificates configured

2. **Update GitHub Secrets**
   - Add production server details
   - Use separate SSH keys for production
   - Configure environment-specific secrets

3. **Create Production Workflow**
   - Duplicate workflows with production settings
   - Add additional security checks
   - Configure production-specific environment variables

4. **Database Migration**
   - Set up production databases
   - Implement data migration scripts
   - Configure backups and monitoring

---

**🎯 Your staging environment is now properly configured and ready for development and testing!**
