#!/bin/bash
set -e

echo "🔧 Fixing environment variables for splitz-service..."
cd /opt/letzgo

# Backup existing .env
if [ -f ".env" ]; then
    cp .env .env.backup
    echo "✅ Backed up existing .env to .env.backup"
fi

# Extract existing passwords from current .env if it exists
if [ -f ".env" ]; then
    POSTGRES_PASSWORD=$(grep "^POSTGRES_PASSWORD=" .env | cut -d'=' -f2)
    MONGODB_PASSWORD=$(grep "^MONGODB_PASSWORD=" .env | cut -d'=' -f2)
    REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" .env | cut -d'=' -f2)
    RABBITMQ_PASSWORD=$(grep "^RABBITMQ_PASSWORD=" .env | cut -d'=' -f2)
    JWT_SECRET=$(grep "^JWT_SECRET=" .env | cut -d'=' -f2)
    SERVICE_API_KEY=$(grep "^SERVICE_API_KEY=" .env | cut -d'=' -f2)
else
    echo "❌ No existing .env found - need to regenerate from scratch"
    exit 1
fi

echo "🔄 Adding missing environment variables to .env..."

# Add the missing variables that splitz-service needs
cat >> .env << 'ENVEOF'

# --- Additional variables for splitz-service compatibility ---
MONGODB_URI=mongodb://admin:${MONGODB_PASSWORD}@letzgo-mongodb:27017/letzgo_db?authSource=admin
MONGODB_HOST=letzgo-mongodb
MONGODB_PORT=27017
MONGODB_DATABASE=letzgo_db
MONGODB_USERNAME=admin
REDIS_HOST=letzgo-redis
REDIS_PORT=6379
ENVEOF

# Replace ${MONGODB_PASSWORD} with actual password
sed -i "s/\${MONGODB_PASSWORD}/$MONGODB_PASSWORD/g" .env

echo "✅ Environment file updated successfully"

echo "🔍 Verifying new environment variables..."
echo "MONGODB_URI: $(grep "^MONGODB_URI=" .env | cut -d'=' -f2 | head -1)"
echo "REDIS_HOST: $(grep "^REDIS_HOST=" .env | cut -d'=' -f2 | head -1)"
echo "REDIS_PORT: $(grep "^REDIS_PORT=" .env | cut -d'=' -f2 | head -1)"

echo "🔄 Restarting splitz-service with new environment..."
docker restart letzgo-splitz-service

echo "⏳ Waiting 10 seconds for service to start..."
sleep 10

echo "🏥 Checking splitz-service health..."
if curl -f -s http://localhost:3005/health > /dev/null 2>&1; then
    echo "✅ splitz-service is now healthy!"
    curl -s http://localhost:3005/health | head -3
else
    echo "⚠️ splitz-service still not healthy, checking logs..."
    docker logs letzgo-splitz-service --tail 10
fi
