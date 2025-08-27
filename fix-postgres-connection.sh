#!/bin/bash

# Quick fix for PostgreSQL connection issue
# This script will restart the auth-service with corrected database URLs

set -e

echo "🔧 Fixing PostgreSQL connection for auth-service..."

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
docker stop letzgo-auth-service || true
docker rm letzgo-auth-service || true

# Override database connection URLs with correct hostnames
POSTGRES_URL="postgresql://postgres:${POSTGRES_PASSWORD}@letzgo-postgres:5432/letzgo?sslmode=disable"
MONGODB_URL="mongodb://admin:${MONGODB_PASSWORD}@letzgo-mongodb:27017/letzgo?authSource=admin"
MONGODB_URI="mongodb://admin:${MONGODB_PASSWORD}@letzgo-mongodb:27017/letzgo?authSource=admin"
REDIS_URL="redis://:${REDIS_PASSWORD}@letzgo-redis:6379"
RABBITMQ_URL="amqp://admin:${RABBITMQ_PASSWORD}@letzgo-rabbitmq:5672"

echo "🔍 Database URLs to be used:"
echo "POSTGRES_URL: $POSTGRES_URL"
echo "MONGODB_URL: $MONGODB_URL"

# Ensure network exists
NETWORK_NAME="letzgo-network"
if docker network ls --format "{{.Name}}" | grep -q "^letzgo_letzgo-network$"; then
    NETWORK_NAME="letzgo_letzgo-network"
elif docker network ls --format "{{.Name}}" | grep -q "^letzgo-network$"; then
    NETWORK_NAME="letzgo-network"
else
    echo "🔗 Creating letzgo-network..."
    docker network create letzgo-network
    NETWORK_NAME="letzgo-network"
fi

echo "🔗 Using network: $NETWORK_NAME"

# Run new container with corrected database URLs
echo "🚀 Starting auth-service with corrected database URLs..."
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

echo "✅ Auth-service restarted with corrected database URLs"

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
        echo "📋 Container logs (last 20 lines):"
        docker logs letzgo-auth-service --tail 20
        echo "📋 Environment variables check:"
        docker exec letzgo-auth-service env | grep -i postgres
        exit 1
    fi
    
    echo "Attempt $attempt/$max_attempts - waiting 3 seconds..."
    sleep 3
    attempt=$((attempt + 1))
done

echo "🎉 PostgreSQL connection fix applied successfully!"
