# Database Connection Variables Fix

## Issue Summary

The `splitz-service` was failing to start with the error:
```
❌ Failed to start server: connect ECONNREFUSED ::1:27017, connect ECONNREFUSED 127.0.0.1:27017
MongooseServerSelectionError: connect ECONNREFUSED ::1:27017, connect ECONNREFUSED 127.0.0.1:27017
```

This indicated that the service was trying to connect to `localhost:27017` instead of the Docker internal service name `letzgo-mongodb:27017`.

## Root Cause

Different services were expecting different environment variable names:

1. **splitz-service** expected: `MONGODB_URI`, `REDIS_HOST`, `REDIS_PORT`
2. **Other services** expected: `MONGODB_URL`, `REDIS_URL`
3. **Our deployment** was only generating: `MONGODB_URL`, `REDIS_URL`

## Solution Implemented

### 1. Updated Environment Variable Generation

**File**: `deployment/deploy-infrastructure.sh`

Added comprehensive database connection variables to support all services:

```bash
# --- Database Connection URLs ---
POSTGRES_URL=postgresql://postgres:$POSTGRES_PASSWORD@letzgo-postgres:5432/letzgo_db
MONGODB_URL=mongodb://admin:$MONGODB_PASSWORD@letzgo-mongodb:27017/letzgo_db?authSource=admin
MONGODB_URI=mongodb://admin:$MONGODB_PASSWORD@letzgo-mongodb:27017/letzgo_db?authSource=admin
REDIS_URL=redis://:$REDIS_PASSWORD@letzgo-redis:6379
RABBITMQ_URL=amqp://admin:$RABBITMQ_PASSWORD@letzgo-rabbitmq:5672

# --- Individual Database Connection Parameters ---
# MongoDB
MONGODB_HOST=letzgo-mongodb
MONGODB_PORT=27017
MONGODB_DATABASE=letzgo_db
MONGODB_USERNAME=admin

# Redis  
REDIS_HOST=letzgo-redis
REDIS_PORT=6379

# PostgreSQL
POSTGRES_HOST=letzgo-postgres
POSTGRES_PORT=5432
POSTGRES_DATABASE=letzgo_db
POSTGRES_USERNAME=postgres

# RabbitMQ
RABBITMQ_HOST=letzgo-rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USERNAME=admin
```

### 2. Updated Environment Template

**File**: `deployment/env.template`

Added the same comprehensive set of variables to the template for consistency.

### 3. Service Restart with Updated Environment

**Issue**: Existing containers were running with the old environment variables.

**Solution**: Created `restart-all-services.sh` script that:
1. Stops and removes all service containers
2. Starts new containers with the updated `.env` file
3. Verifies health of all services

## Results

All services are now **HEALTHY** and connecting properly to their dependencies:

```
🏥 Checking health of all services:
event-service (port 3003): ✅ HEALTHY
splitz-service (port 3005): ✅ HEALTHY
auth-service (port 3000): ✅ HEALTHY
user-service (port 3001): ✅ HEALTHY
chat-service (port 3002): ✅ HEALTHY
shared-service (port 3004): ✅ HEALTHY
```

## Service-Specific Configurations

### splitz-service
- **Expected**: `MONGODB_URI`, `REDIS_HOST`, `REDIS_PORT`
- **Config files**: `src/config/index.js`, `src/utils/config.js`
- **Validation**: `src/utils/validateEnv.js`

### Other services
- **Expected**: `MONGODB_URL`, `REDIS_URL`
- **Fallback**: Individual host/port parameters when URL format not available

## Prevention for Future Deployments

### 1. Comprehensive Environment Generation
The `deploy-infrastructure.sh` now generates both URL and individual parameter formats to support all service configurations.

### 2. Container Restart Integration
Future deployments will automatically restart containers when environment variables are updated.

### 3. Environment Variable Validation
Services should validate their required environment variables on startup and provide clear error messages.

## Files Updated

1. `deployment/deploy-infrastructure.sh` - Added comprehensive database connection variables
2. `deployment/env.template` - Updated template with all required variables  
3. `deployment/fix-splitz-env.sh` - Script to fix environment for existing deployments
4. `deployment/restart-all-services.sh` - Script to restart all services with updated environment
5. `deployment/DATABASE_CONNECTION_FIX.md` - This documentation

## Verification Commands

```bash
# Check all service health
for port in 3000 3001 3002 3003 3004 3005; do
  echo -n "Port $port: "
  curl -s http://localhost:$port/health | jq -r .status 2>/dev/null || echo "not responding"
done

# Check environment variables in containers
docker exec letzgo-splitz-service env | grep -E "MONGODB_URI|REDIS_HOST"
docker exec letzgo-auth-service env | grep -E "MONGODB_URL|REDIS_URL"

# Check container status
docker ps --format "table {{.Names}}\t{{.Status}}" | grep letzgo-
```

## Key Learnings

1. **Service Compatibility**: Different services may expect different environment variable formats
2. **Container Restart Required**: Environment variable changes require container restarts to take effect
3. **Comprehensive Testing**: All services should be tested after environment changes
4. **Documentation**: Environment variable requirements should be documented per service
5. **Soft Dependencies**: Services should handle database connection failures gracefully during startup
