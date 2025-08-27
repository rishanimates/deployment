#!/bin/bash

# Fixed PostgreSQL connection issue - using correct network
# This script will restart the auth-service on the same network as infrastructure

set -e

echo "🔧 Fixing PostgreSQL connection for auth-service (v2)..."

cd /opt/letzgo

# Load environment variables
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
else
    echo "❌ Environment file not found!"
    exit 1
fi

# Stop existing container
echo "🛑 Stopping existing auth-service..."
docker stop letzgo-auth-service 2>/dev/null || true
docker rm letzgo-auth-service 2>/dev/null || true

# Use the same network as infrastructure containers (letzgo-network)
NETWORK_NAME="letzgo-network"

echo "🔍 Network verification:"
docker network ls | grep letzgo
echo ""
echo "🔍 Infrastructure containers network:"
docker ps --format "table {{.Names}}\t{{.Networks}}" | grep -E "(postgres|mongodb|redis|rabbitmq)"
echo ""

# Override database connection URLs with correct hostnames
POSTGRES_URL="postgresql://postgres:${POSTGRES_PASSWORD}@letzgo-postgres:5432/letzgo?sslmode=disable"
MONGODB_URL="mongodb://admin:${MONGODB_PASSWORD}@letzgo-mongodb:27017/letzgo?authSource=admin"
MONGODB_URI="mongodb://admin:${MONGODB_PASSWORD}@letzgo-mongodb:27017/letzgo?authSource=admin"
REDIS_URL="redis://:${REDIS_PASSWORD}@letzgo-redis:6379"
RABBITMQ_URL="amqp://admin:${RABBITMQ_PASSWORD}@letzgo-rabbitmq:5672"

echo "🔍 Database URLs to be used:"
echo "POSTGRES_URL: $POSTGRES_URL"
echo "NETWORK_NAME: $NETWORK_NAME"
echo ""

# Run new container with corrected database URLs on the SAME network as infrastructure
echo "🚀 Starting auth-service on network: $NETWORK_NAME"
docker run -d \
  --name letzgo-auth-service \
  --network "$NETWORK_NAME" \
  -p 3000:3000 \
  -e NODE_ENV=staging \
  -e PORT=3000 \
  -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -e MONGODB_PASSWORD="$MONGODB_PASSWORD" \
  -e REDIS_PASSWORD="$REDIS_PASSWORD" \
  -e RABBITMQ_PASSWORD="$RABBITMQ_PASSWORD" \
  -e JWT_SECRET="$JWT_SECRET" \
  -e SERVICE_API_KEY="$SERVICE_API_KEY" \
  -e POSTGRES_URL="$POSTGRES_URL" \
  -e MONGODB_URL="$MONGODB_URL" \
  -e MONGODB_URI="$MONGODB_URI" \
  -e REDIS_URL="$REDIS_URL" \
  -e RABBITMQ_URL="$RABBITMQ_URL" \
  -e POSTGRES_HOST=letzgo-postgres \
  -e MONGODB_HOST=letzgo-mongodb \
  -e REDIS_HOST=letzgo-redis \
  -e RABBITMQ_HOST=letzgo-rabbitmq \
  -e POSTGRES_PORT=5432 \
  -e MONGODB_PORT=27017 \
  -e REDIS_PORT=6379 \
  -e RABBITMQ_PORT=5672 \
  -e POSTGRES_DATABASE=letzgo \
  -e MONGODB_DATABASE=letzgo \
  -e POSTGRES_USERNAME=postgres \
  -e MONGODB_USERNAME=admin \
  -e RABBITMQ_USERNAME=admin \
  -e DB_SCHEMA=public \
  -e DOMAIN_NAME="$DOMAIN_NAME" \
  -e API_DOMAIN="$API_DOMAIN" \
  -v /opt/letzgo/logs:/app/logs \
  -v /opt/letzgo/uploads:/app/uploads \
  --restart unless-stopped \
  letzgo-auth-service:latest

echo "✅ Auth-service restarted on correct network"

# Verify network connectivity
echo "🔍 Network connectivity test:"
echo "Auth-service network:"
docker ps --format "table {{.Names}}\t{{.Networks}}" | grep letzgo-auth
echo ""

# Test network connectivity from auth-service to postgres
echo "🔍 Testing network connectivity from auth-service to letzgo-postgres:"
docker exec letzgo-auth-service nslookup letzgo-postgres || echo "❌ DNS lookup failed"
docker exec letzgo-auth-service ping -c 2 letzgo-postgres || echo "❌ Ping failed"

# Wait for health check
echo "⏳ Waiting for auth-service to be healthy..."
max_attempts=10
attempt=1

while [ $attempt -le $max_attempts ]; do
    # Check if container is running first
    if ! docker ps | grep -q letzgo-auth-service; then
        echo "⚠️ Container letzgo-auth-service is not running"
        docker logs letzgo-auth-service --tail 10
        echo "Attempt $attempt/$max_attempts - waiting 3 seconds..."
        sleep 3
        attempt=$((attempt + 1))
        continue
    fi
    
    # Test health endpoint
    if curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
        echo "✅ auth-service is healthy!"
        curl -s http://localhost:3000/health
        break
    fi
    
    if [ $attempt -eq $max_attempts ]; then
        echo "❌ auth-service failed to become healthy after $max_attempts attempts"
        echo "📋 Container logs (last 30 lines):"
        docker logs letzgo-auth-service --tail 30
        echo ""
        echo "📋 Environment variables check:"
        docker exec letzgo-auth-service env | grep -E "(POSTGRES|MONGODB)" | sort
        echo ""
        echo "📋 Network connectivity from inside container:"
        docker exec letzgo-auth-service nslookup letzgo-postgres || echo "DNS lookup failed"
        exit 1
    fi
    
    echo "Attempt $attempt/$max_attempts - waiting 3 seconds..."
    sleep 3
    attempt=$((attempt + 1))
done

echo "🎉 PostgreSQL connection fix applied successfully!"
