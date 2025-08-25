# Port Conflicts Troubleshooting Guide

## 🚨 **Issue: Port Already in Use**

**Error Message:**
```
Error starting userland proxy: listen tcp4 0.0.0.0:5432: bind: address already in use
Error starting userland proxy: listen tcp4 0.0.0.0:27017: bind: address already in use
```

## 🔍 **Root Cause**
Your VPS has existing services running on the ports that LetzGo needs:
- **Port 5432**: PostgreSQL
- **Port 27017**: MongoDB  
- **Port 6379**: Redis
- **Port 5672**: RabbitMQ
- **Port 15672**: RabbitMQ Management

## ✅ **Solutions**

### Quick Fix (Automated)
```bash
# SSH into your VPS
ssh -p 7576 root@103.168.19.241

# Run the cleanup script
cd /opt/letzgo
./cleanup-ports.sh
```

### Manual Fix (Step by Step)

#### 1. Check What's Using the Ports
```bash
# Check all required ports
netstat -tlnp | grep -E ":5432|:27017|:6379|:5672|:15672"

# Or check individual ports
lsof -i :5432  # PostgreSQL
lsof -i :27017 # MongoDB
lsof -i :6379  # Redis
lsof -i :5672  # RabbitMQ
```

#### 2. Stop Conflicting Docker Containers
```bash
# List containers using our ports
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "5432|27017|6379|5672"

# Stop specific containers
docker stop <container_name>
docker rm <container_name>

# Or stop all containers using these ports
docker ps -q --filter "publish=5432" | xargs docker stop
docker ps -q --filter "publish=27017" | xargs docker stop
docker ps -q --filter "publish=6379" | xargs docker stop
docker ps -q --filter "publish=5672" | xargs docker stop
```

#### 3. Stop System Services
```bash
# Stop system database services
systemctl stop postgresql || true
systemctl stop mongod || true
systemctl stop mongodb || true
systemctl stop redis-server || true
systemctl stop redis || true
systemctl stop rabbitmq-server || true

# Disable them from auto-starting
systemctl disable postgresql || true
systemctl disable mongod || true
systemctl disable mongodb || true
systemctl disable redis-server || true
systemctl disable rabbitmq-server || true
```

#### 4. Kill Processes Using Ports
```bash
# Kill processes on specific ports
lsof -ti:5432 | xargs kill -9
lsof -ti:27017 | xargs kill -9
lsof -ti:6379 | xargs kill -9
lsof -ti:5672 | xargs kill -9
lsof -ti:15672 | xargs kill -9
```

#### 5. Clean Up Docker Resources
```bash
# Remove old networks
docker network rm letzgo-network || true
docker network prune -f

# Remove containers
docker container prune -f

# Remove unused images
docker image prune -f
```

#### 6. Verify Ports Are Free
```bash
# Check that ports are now available
netstat -tlnp | grep -E ":5432|:27017|:6379|:5672|:15672"

# Should return nothing if ports are free
```

### Alternative: Use Different Ports

If you want to keep existing services running, modify the docker-compose file to use different ports:

```yaml
# In docker-compose.infrastructure.yml
services:
  postgres:
    ports:
      - "15432:5432"  # External port 15432 -> Internal 5432
  
  mongodb:
    ports:
      - "27018:27017"  # External port 27018 -> Internal 27017
  
  redis:
    ports:
      - "16379:6379"  # External port 16379 -> Internal 6379
```

**Note**: If you use different ports, you'll need to update your service configurations accordingly.

## 🔄 **After Cleanup**

Once ports are free, run the deployment:
```bash
cd /opt/letzgo
./deploy-infrastructure.sh
```

## 🛠️ **Prevention**

To prevent future conflicts:

1. **Use Docker Compose**: Always use docker-compose to manage services
2. **Avoid System Services**: Don't install PostgreSQL/MongoDB directly on the system
3. **Port Management**: Document which ports are used by which services
4. **Regular Cleanup**: Periodically clean up unused containers and networks

## 📋 **Common Scenarios**

### Scenario 1: Previous LetzGo Deployment
**Cause**: Old LetzGo containers still running
**Solution**: `docker-compose down` in the deployment directory

### Scenario 2: System Database Services
**Cause**: PostgreSQL/MongoDB installed via apt/yum
**Solution**: Stop and disable system services

### Scenario 3: Other Applications
**Cause**: Other applications using the same ports
**Solution**: Either stop them or use different ports for LetzGo

### Scenario 4: Development Environment
**Cause**: Local development databases running
**Solution**: Use different ports or stop development services

## 🆘 **Emergency Recovery**

If all else fails:
```bash
# Nuclear option - stop all containers
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)

# Reboot the server
reboot
```

---

**🎯 The cleanup script should resolve most port conflicts automatically. Run it first before trying manual fixes!**
