# Environment Setup Guide - Complete Configuration

## 🔍 **Issue Explanation**

**Problem:** Services fail to deploy because `.env` file is missing on the VPS.

**Error Message:**
```
❌ Environment file not found!
```

**Root Cause:** The deployment process expects environment variables to be loaded from `/opt/letzgo/.env`, but this file wasn't created during infrastructure setup.

## ✅ **Complete Solution**

Since we're using the **same deployment repository** for infrastructure setup, the environment file should be automatically created during infrastructure deployment. Here's how it works:

### **Infrastructure-First Approach**
```
1. Deploy Infrastructure → Creates .env file with generated passwords
2. Deploy Services → Uses .env file for configuration
```

## 🔧 **Setup Methods**

### **Method 1: Automatic Setup (Recommended)**

**Infrastructure deployment automatically creates `.env` file:**

1. **Deploy Infrastructure First:**
   ```bash
   # In GitHub Actions
   1. Go to Actions tab
   2. Run "Deploy Infrastructure" workflow
   3. This will automatically create .env file with secure passwords
   ```

2. **Then Deploy Services:**
   ```bash
   # Services will now find the .env file and deploy successfully
   ```

### **Method 2: Manual Setup (If Needed)**

**If you need to set up the environment manually:**

```bash
# From deployment directory
./setup-environment.sh
```

**This script will:**
- ✅ Generate secure passwords for all services
- ✅ Create `.env` file from `env.template`
- ✅ Transfer `.env` file to VPS
- ✅ Set proper permissions (600)
- ✅ Create required directories

## 📋 **Environment File Structure**

**The `.env` file contains:**

### **Auto-Generated Passwords:**
```env
POSTGRES_PASSWORD=auto_generated_25_chars
MONGODB_PASSWORD=auto_generated_25_chars
REDIS_PASSWORD=auto_generated_25_chars
RABBITMQ_PASSWORD=auto_generated_25_chars
JWT_SECRET=auto_generated_32_chars
SERVICE_API_KEY=auto_generated_32_chars
```

### **Database Connection URLs:**
```env
POSTGRES_URL=postgresql://postgres:${POSTGRES_PASSWORD}@letzgo-postgres:5432/letzgo_db
MONGODB_URL=mongodb://admin:${MONGODB_PASSWORD}@letzgo-mongodb:27017/letzgo_db?authSource=admin
REDIS_URL=redis://:${REDIS_PASSWORD}@letzgo-redis:6379
RABBITMQ_URL=amqp://admin:${RABBITMQ_PASSWORD}@letzgo-rabbitmq:5672
```

### **Service Configuration:**
```env
NODE_ENV=staging
STORAGE_PROVIDER=local
DOMAIN_NAME=103.168.19.241
API_DOMAIN=103.168.19.241
```

### **Service Ports & URLs:**
```env
AUTH_SERVICE_PORT=3000
USER_SERVICE_PORT=3001
CHAT_SERVICE_PORT=3002
EVENT_SERVICE_PORT=3003
SHARED_SERVICE_PORT=3004
SPLITZ_SERVICE_PORT=3005

AUTH_SERVICE_URL=http://letzgo-auth-service:3000
USER_SERVICE_URL=http://letzgo-user-service:3001
# ... etc for all services
```

## 🔄 **Deployment Flow**

### **Correct Deployment Order:**

**1. Infrastructure Deployment:**
```bash
GitHub Actions → Deploy Infrastructure
├── Create directories (/opt/letzgo/logs, /uploads, etc.)
├── Generate .env file with secure passwords
├── Start databases (PostgreSQL, MongoDB, Redis, RabbitMQ)
├── Start Nginx API Gateway
└── ✅ Infrastructure ready
```

**2. Service Deployment:**
```bash
GitHub Actions → Deploy Services
├── Load environment variables from .env
├── Deploy auth-service (port 3000)
├── Deploy user-service (port 3001)
├── Deploy chat-service (port 3002)
├── Deploy event-service (port 3003)
├── Deploy shared-service (port 3004)
├── Deploy splitz-service (port 3005)
└── ✅ All services running
```

## 🧪 **Verification Steps**

### **Check Environment File on VPS:**
```bash
# SSH to VPS
ssh -p 7576 root@103.168.19.241

# Check if .env file exists
ls -la /opt/letzgo/.env

# Should show:
-rw------- 1 root root [SIZE] [DATE] /opt/letzgo/.env
```

### **View Environment File (Safely):**
```bash
# Show non-sensitive parts
grep -E "^NODE_ENV|^STORAGE_PROVIDER|^DOMAIN_NAME" /opt/letzgo/.env

# Should show:
NODE_ENV=staging
STORAGE_PROVIDER=local
DOMAIN_NAME=103.168.19.241
```

### **Test Environment Loading:**
```bash
# Test loading environment variables
cd /opt/letzgo
set -a
source .env
set +a
echo "Database: $POSTGRES_URL"
```

## 🔧 **Customization**

### **Update Environment Variables:**

**1. Edit Local Template:**
```bash
# Edit env.template with your values
nano deployment/env.template
```

**2. Regenerate Environment:**
```bash
# Run setup script again
./setup-environment.sh
```

**3. Or Update Directly on VPS:**
```bash
# SSH to VPS
ssh -p 7576 root@103.168.19.241

# Edit .env file
nano /opt/letzgo/.env

# Restart services to pick up changes
cd /opt/letzgo
docker-compose -f docker-compose.prod.yml restart
```

### **Required Customizations:**

**Payment Gateway (Razorpay):**
```env
RAZORPAY_KEY_ID=rzp_live_your_actual_key_id
RAZORPAY_KEY_SECRET=your_actual_razorpay_secret
```

**Email Configuration (Optional):**
```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASS=your_app_password
```

**Domain Configuration (Production):**
```env
DOMAIN_NAME=yourdomain.com
API_DOMAIN=api.yourdomain.com
```

## 🚀 **Quick Start**

**For immediate deployment:**

```bash
# 1. Deploy infrastructure (creates .env automatically)
GitHub Actions → Deploy Infrastructure

# 2. Wait for infrastructure to be ready (databases, nginx)

# 3. Deploy services (will use .env file)
GitHub Actions → Deploy Services

# 4. Verify services are running
ssh -p 7576 root@103.168.19.241 "docker ps"
```

## 🔍 **Troubleshooting**

### **If .env File Missing:**

**Check Infrastructure Deployment:**
```bash
# Look for this in infrastructure deployment logs:
✅ Environment file created successfully
✅ Generated passwords: PostgreSQL, MongoDB, Redis, RabbitMQ, JWT Secret, API Key
```

**Manual Fix:**
```bash
# Run environment setup manually
./setup-environment.sh

# Or SSH to VPS and check
ssh -p 7576 root@103.168.19.241 "ls -la /opt/letzgo/.env"
```

### **If Services Still Can't Load .env:**

**Check File Permissions:**
```bash
# Should be 600 (read/write for owner only)
ssh -p 7576 root@103.168.19.241 "ls -la /opt/letzgo/.env"
```

**Check File Location:**
```bash
# Services expect .env in /opt/letzgo/
# Verify path in deployment logs:
cd "/opt/letzgo"
if [ -f ".env" ]; then
  echo "✅ .env file found"
else
  echo "❌ .env file missing"
fi
```

## 📋 **Summary**

**Environment setup is now automated:**

1. ✅ **Infrastructure deployment** automatically creates `.env` file
2. ✅ **Secure passwords** generated for all services
3. ✅ **Database URLs** configured automatically
4. ✅ **Service configuration** ready for deployment
5. ✅ **Manual setup script** available if needed

**Next Steps:**
1. Deploy infrastructure (creates .env)
2. Deploy services (uses .env)
3. Customize payment/email settings as needed

---

**🎉 Environment configuration is now fully automated! Your services will have all required environment variables available during deployment.**
