# 🔧 Database Connection Troubleshooting Guide

## **❌ REPORTED ISSUES**
After infrastructure deployment, the following errors were reported:
```
[ERROR] ❌ PostgreSQL: Connection failed
[ERROR] ❌ RabbitMQ: Connection failed
```

## **🔍 DIAGNOSTIC TOOLS CREATED**

### **1. Debug Infrastructure Script**
**File**: `debug-infrastructure.sh`
**Purpose**: Comprehensive diagnostic of all infrastructure components

**Usage**:
```bash
./debug-infrastructure.sh
```

**What it checks**:
- ✅ Container status and health
- ✅ Recent logs from all containers
- ✅ PostgreSQL process and configuration
- ✅ RabbitMQ process and port status
- ✅ Network connectivity
- ✅ Environment configuration
- ✅ Docker Compose setup
- ✅ System resources

### **2. Database Connection Fix Script**
**File**: `fix-database-connections.sh`
**Purpose**: Automatically fix common database connection issues

**Usage**:
```bash
./fix-database-connections.sh
```

**What it fixes**:
- ✅ PostgreSQL startup and readiness issues
- ✅ RabbitMQ initialization and health checks
- ✅ MongoDB connection problems
- ✅ Redis authentication issues
- ✅ Network connectivity problems
- ✅ Container restart when needed

### **3. GitHub Actions Debug Workflow**
**File**: `.github/workflows/debug-infrastructure.yml`
**Purpose**: Run diagnostics and fixes via GitHub Actions

**Options**:
- **Debug**: Run diagnostic analysis only
- **Fix**: Run connection fixes only  
- **Both**: Run diagnostics then fixes

## **🚀 INFRASTRUCTURE SCRIPT IMPROVEMENTS**

### **Enhanced Health Check**
Updated `wait_for_health()` function in `deploy-infrastructure.sh`:

**Previous**: Only checked if containers were running
**New**: Checks both running status AND service readiness:
- ✅ PostgreSQL: `pg_isready -U postgres`
- ✅ MongoDB: `mongosh --eval "db.adminCommand('ping')"`
- ✅ Redis: `redis-cli -a password ping`
- ✅ RabbitMQ: `rabbitmqctl node_health_check`

**Improvements**:
- Increased timeout to 60 attempts (5 minutes total)
- Reduced wait time to 5 seconds between attempts
- Better progress reporting
- More accurate readiness detection

## **🔧 COMMON ISSUES & SOLUTIONS**

### **PostgreSQL Connection Issues**

**Possible Causes**:
- Container not fully initialized
- Database schema not created
- PostgreSQL process not ready

**Solutions**:
1. **Wait longer**: PostgreSQL needs time to initialize
2. **Check logs**: `docker logs letzgo-postgres`
3. **Restart container**: `docker restart letzgo-postgres`
4. **Re-run schema**: Execute initialization scripts manually

### **RabbitMQ Connection Issues**

**Possible Causes**:
- RabbitMQ startup time
- Management plugin not enabled
- Node health check failing

**Solutions**:
1. **Wait for startup**: RabbitMQ takes 15-30 seconds to start
2. **Enable management**: `rabbitmq-plugins enable rabbitmq_management`
3. **Check node health**: `rabbitmqctl node_health_check`
4. **Restart container**: `docker restart letzgo-rabbitmq`

### **Network Issues**

**Possible Causes**:
- Docker network not created
- Containers not connected to network
- Port conflicts

**Solutions**:
1. **Create network**: `docker network create letzgo-network`
2. **Connect containers**: `docker network connect letzgo-network <container>`
3. **Check ports**: `netstat -tlnp | grep <port>`

## **📋 STEP-BY-STEP TROUBLESHOOTING**

### **1. Run Diagnostics**
```bash
# Via script (on VPS)
./debug-infrastructure.sh

# Via GitHub Actions
# Go to Actions → Debug Infrastructure → Run workflow → Select "debug"
```

### **2. Analyze Output**
Look for:
- ❌ Containers not running
- ❌ Health checks failing
- ❌ Network connectivity issues
- ❌ Environment configuration problems

### **3. Apply Fixes**
```bash
# Via script (on VPS)
./fix-database-connections.sh

# Via GitHub Actions  
# Go to Actions → Debug Infrastructure → Run workflow → Select "fix"
```

### **4. Verify Resolution**
```bash
# Via verification script
./verify-deployment.sh

# Via manual checks
docker exec letzgo-postgres pg_isready -U postgres -d letzgo
docker exec letzgo-rabbitmq rabbitmqctl status
```

## **⏰ TIMING CONSIDERATIONS**

### **Expected Startup Times**:
- **PostgreSQL**: 10-30 seconds
- **MongoDB**: 5-15 seconds  
- **Redis**: 2-5 seconds
- **RabbitMQ**: 15-45 seconds

### **Health Check Timing**:
- **Total timeout**: 5 minutes (60 attempts × 5 seconds)
- **Check frequency**: Every 5 seconds
- **Early success**: Exits as soon as all services are ready

## **🔗 QUICK COMMANDS**

### **Manual Connection Tests**:
```bash
# PostgreSQL
docker exec letzgo-postgres pg_isready -U postgres -d letzgo

# MongoDB
docker exec letzgo-mongodb mongosh --quiet --eval "db.adminCommand('ping')"

# Redis (with password from env)
REDIS_PASSWORD=$(grep REDIS_PASSWORD /opt/letzgo/.env | cut -d'=' -f2)
docker exec letzgo-redis redis-cli --no-auth-warning -a "$REDIS_PASSWORD" ping

# RabbitMQ
docker exec letzgo-rabbitmq rabbitmqctl status
```

### **Container Management**:
```bash
# Check all containers
docker ps | grep letzgo

# Restart specific container
docker restart letzgo-postgres
docker restart letzgo-rabbitmq

# View logs
docker logs letzgo-postgres --tail 20
docker logs letzgo-rabbitmq --tail 20
```

### **Network Debugging**:
```bash
# Check network
docker network ls | grep letzgo

# Check connected containers
docker network inspect letzgo-network

# Connect container to network
docker network connect letzgo-network letzgo-postgres
```

## **🎯 EXPECTED RESOLUTION**

After running the fix script, you should see:
```
✅ PostgreSQL: Working
✅ RabbitMQ: Working  
✅ MongoDB: Working
✅ Redis: Working
```

If issues persist:
1. **Check system resources** (memory, disk space)
2. **Review container logs** for specific errors
3. **Try force rebuild**: `./deploy-infrastructure.sh --force-rebuild`
4. **Contact support** with diagnostic output

---

**🔧 These tools should resolve the PostgreSQL and RabbitMQ connection issues and provide ongoing diagnostic capabilities for infrastructure troubleshooting.**
