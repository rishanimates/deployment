# Soft Dependencies Integration

## Overview

This document explains how the deployment system has been enhanced to handle **soft dependencies** automatically, ensuring services can start and run even when some dependencies are temporarily unavailable.

## Key Principles

1. **Non-blocking startup**: Services should start even if dependent services are not yet available
2. **Graceful degradation**: Services should handle missing dependencies gracefully at runtime
3. **Automatic recovery**: Services should reconnect to dependencies when they become available
4. **Informative logging**: Clear distinction between soft and hard dependency failures

## Automated Fixes Implemented

### 1. Container Permissions Fix

**Problem**: Services failed to start due to log file permission errors (`EACCES: permission denied, open 'logs/error-2025-08-26.log'`)

**Solution**: Automatically fix container permissions during deployment

#### Infrastructure Deployment (`deploy-infrastructure.sh`)
```bash
# Set proper permissions for container access (non-root user 1001:1001)
log_info "Setting container permissions for logs and uploads..."
chown -R 1001:1001 "/opt/letzgo/logs" "/opt/letzgo/uploads" 2>/dev/null || true
chmod -R 755 "/opt/letzgo/logs" "/opt/letzgo/uploads" 2>/dev/null || true
```

#### Service Deployment (All GitHub Actions workflows)
```bash
# Ensure proper permissions for container volumes (non-root user 1001:1001)
echo "🔧 Setting container permissions for logs and uploads..."
chown -R 1001:1001 logs/ uploads/ 2>/dev/null || true
chmod -R 755 logs/ uploads/ 2>/dev/null || true
```

### 2. Enhanced Health Checks

**Problem**: Health checks failed immediately when services had soft dependency issues

**Solution**: Improved health check logic that distinguishes between container startup issues and soft dependency delays

#### Staging Deployment (`auto-deploy-staging.yml`)
```bash
while [ $attempt -le $max_attempts ]; do
  # Check if container is running first
  if ! docker ps | grep -q "letzgo-$SERVICE_NAME"; then
    echo "⚠️  Container letzgo-$SERVICE_NAME is not running"
    # Handle container startup failure
  elif curl -f -s http://localhost:$PORT/health > /dev/null 2>&1; then
    echo "✅ $SERVICE_NAME is healthy on staging!"
    break
  else
    # Service is running but not healthy yet - this is normal for soft dependencies
    echo "⏳ $SERVICE_NAME starting... (soft dependencies may be initializing)"
    # Continue waiting - soft dependency failures are acceptable
  fi
done
```

#### Production Deployment (`auto-deploy-production.yml`)
- Same enhanced health check logic
- **Plus automatic rollback** if service fails to become healthy
- Preserves production stability while handling soft dependencies

### 3. Service Configuration

Services are designed with soft dependencies in mind:

#### Environment Variables
```bash
# Internal Docker service URLs (automatically generated)
AUTH_SERVICE_URL=http://letzgo-auth-service:3000
USER_SERVICE_URL=http://letzgo-user-service:3001
CHAT_SERVICE_URL=http://letzgo-chat-service:3002
EVENT_SERVICE_URL=http://letzgo-event-service:3003
SHARED_SERVICE_URL=http://letzgo-shared-service:3004
SPLITZ_SERVICE_URL=http://letzgo-splitz-service:3005

# Database connections
POSTGRES_URL=postgresql://postgres:$POSTGRES_PASSWORD@letzgo-postgres:5432/letzgo_db
MONGODB_URL=mongodb://admin:$MONGODB_PASSWORD@letzgo-mongodb:27017/letzgo_db
REDIS_URL=redis://:$REDIS_PASSWORD@letzgo-redis:6379
RABBITMQ_URL=amqp://admin:$RABBITMQ_PASSWORD@letzgo-rabbitmq:5672
```

## Service Behavior with Soft Dependencies

### Expected Behavior
1. **Service starts successfully** even if dependencies are unavailable
2. **Health endpoint responds** with service status
3. **Logs indicate** connection attempts and retries
4. **Automatic reconnection** when dependencies become available
5. **Graceful error handling** for missing services

### Example Logs (Normal Soft Dependency Behavior)
```
info: 🚀 Starting Auth Service...
info: 🌍 Environment: staging
info: 📍 Port: 3000
info: 🏠 Host: 0.0.0.0
⚠️ Redis connection closed
🔄 Redis reconnecting...
info: ✅ PostgreSQL connection established
info: ⚠️ User service not available, will retry later
```

### Health Check Response (Soft Dependencies)
```json
{
  "status": "healthy",
  "service": "auth-service",
  "version": "1.0.0",
  "timestamp": "2025-08-26T15:15:47.151Z",
  "dependencies": {
    "postgres": {"status": "healthy"},
    "redis": {"status": "reconnecting"},
    "userService": {"status": "unavailable", "fallback": true}
  }
}
```

## Deployment Workflow Integration

### Infrastructure First
1. Deploy databases and messaging services
2. Set up proper directory permissions
3. Generate environment configuration

### Service Deployment
1. **Pre-deployment**: Fix container permissions automatically
2. **Container startup**: Use proper user (1001:1001) for security
3. **Health checks**: Wait for service to be responsive (not all dependencies)
4. **Monitoring**: Distinguish between startup issues and soft dependency delays

### Rollback Strategy (Production)
- **Soft dependency issues**: Continue deployment (services handle gracefully)
- **Hard startup failures**: Automatic rollback to previous version
- **Container failures**: Immediate rollback and alerting

## Files Updated

### Infrastructure
- `deployment/deploy-infrastructure.sh` - Added permission fixes to `setup_directories()`

### GitHub Actions Workflows
- `deployment/.github/workflows/auto-deploy-staging.yml` - Enhanced health checks + permissions
- `deployment/.github/workflows/auto-deploy-production.yml` - Enhanced health checks + permissions + rollback
- `deployment/.github/workflows/deploy-services-multi-repo.yml` - Added permissions fix

### Documentation
- `deployment/SOFT_DEPENDENCIES_INTEGRATION.md` - This document

## Benefits

1. **Reliability**: Services start consistently regardless of dependency timing
2. **Scalability**: Services can be deployed independently without coordination
3. **Maintainability**: Clear separation between hard and soft dependency failures
4. **Monitoring**: Better visibility into service health and dependency status
5. **Automation**: No manual intervention required for common permission issues

## Monitoring and Troubleshooting

### Health Check Commands
```bash
# Check all service health
for port in 3000 3001 3002 3003 3004 3005; do
  echo -n "Port $port: "
  curl -s http://localhost:$port/health | jq -r .status 2>/dev/null || echo "not responding"
done

# Check container logs for soft dependency issues
docker logs letzgo-auth-service --tail 20

# Check container permissions
ls -la /opt/letzgo/logs/
ls -la /opt/letzgo/uploads/
```

### Expected vs Problematic Logs

#### ✅ Good (Soft Dependencies)
```
⚠️ Redis connection closed
🔄 Redis reconnecting...
info: ✅ Service started successfully
info: ⚠️ User service not available, using fallback
```

#### ❌ Bad (Hard Dependencies)
```
💥 Uncaught Exception: EACCES: permission denied
error: 🔥 Unable to connect to the PostgreSQL database
💥 Fatal: Configuration error - missing required JWT_SECRET
```

## Conclusion

The deployment system now automatically handles:
- **Container permissions** for non-root users
- **Soft dependency failures** during startup
- **Service health monitoring** with appropriate timeouts
- **Automatic recovery** when dependencies become available

This ensures robust, reliable deployments that don't fail due to timing issues or soft dependency unavailability.
