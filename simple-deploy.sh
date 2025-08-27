#!/bin/bash

# ============================================================================
# Simple Fresh Infrastructure Deployment Script
# ============================================================================

set -e

VPS_HOST="103.168.19.241"
VPS_PORT="7576"
VPS_USER="root"

echo "🚀 Starting Fresh Infrastructure Deployment"

# Step 1: Clean old infrastructure
echo "🗑️ Cleaning old infrastructure..."
ssh -p $VPS_PORT $VPS_USER@$VPS_HOST << 'EOF'
cd /opt/letzgo 2>/dev/null || true
docker-compose -f docker-compose.prod.yml down --volumes --remove-orphans 2>/dev/null || true
docker ps -a | grep letzgo | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
docker images | grep letzgo | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true
docker volume ls | grep letzgo | awk '{print $2}' | xargs -r docker volume rm 2>/dev/null || true
docker network rm letzgo-network 2>/dev/null || true
rm -rf /opt/letzgo/logs/* /opt/letzgo/uploads/* 2>/dev/null || true
echo "✅ Old infrastructure cleaned"
EOF

# Step 2: Setup directories
echo "📁 Setting up directories..."
ssh -p $VPS_PORT $VPS_USER@$VPS_HOST << 'EOF'
mkdir -p /opt/letzgo/{database,logs,uploads,nginx/conf.d,ssl}
chown -R 1001:1001 /opt/letzgo/logs /opt/letzgo/uploads
chmod -R 755 /opt/letzgo/logs /opt/letzgo/uploads
echo "✅ Directories ready"
EOF

# Step 3: Copy files
echo "📋 Copying files..."
scp -P $VPS_PORT -r database/ $VPS_USER@$VPS_HOST:/opt/letzgo/
scp -P $VPS_PORT docker-compose.prod.yml $VPS_USER@$VPS_HOST:/opt/letzgo/
scp -P $VPS_PORT env.template $VPS_USER@$VPS_HOST:/opt/letzgo/

# Step 4: Generate environment
echo "🔧 Generating environment..."
ssh -p $VPS_PORT $VPS_USER@$VPS_HOST << 'EOF'
cd /opt/letzgo
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/')
MONGODB_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/')
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/')
RABBITMQ_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/')
JWT_SECRET=$(openssl rand -base64 64 | tr -d '=+/')
SERVICE_API_KEY=$(openssl rand -hex 32)

cp env.template .env
sed -i "s/POSTGRES_PASSWORD_PLACEHOLDER/$POSTGRES_PASSWORD/g" .env
sed -i "s/MONGODB_PASSWORD_PLACEHOLDER/$MONGODB_PASSWORD/g" .env
sed -i "s/REDIS_PASSWORD_PLACEHOLDER/$REDIS_PASSWORD/g" .env
sed -i "s/RABBITMQ_PASSWORD_PLACEHOLDER/$RABBITMQ_PASSWORD/g" .env
sed -i "s/JWT_SECRET_PLACEHOLDER/$JWT_SECRET/g" .env
sed -i "s/SERVICE_API_KEY_PLACEHOLDER/$SERVICE_API_KEY/g" .env
chmod 600 .env
echo "✅ Environment configured"
EOF

# Step 5: Deploy databases
echo "🏗️ Deploying databases..."
ssh -p $VPS_PORT $VPS_USER@$VPS_HOST << 'EOF'
cd /opt/letzgo
docker network create letzgo-network 2>/dev/null || true
docker-compose -f docker-compose.prod.yml up -d postgres mongodb redis rabbitmq
echo "⏳ Waiting for databases..."
sleep 60
echo "✅ Databases deployed"
EOF

# Step 6: Deploy services
echo "🚀 Deploying services..."
ssh -p $VPS_PORT $VPS_USER@$VPS_HOST << 'EOF'
cd /opt/letzgo
docker-compose -f docker-compose.prod.yml up -d auth-service
sleep 20
docker-compose -f docker-compose.prod.yml up -d user-service
sleep 20
docker-compose -f docker-compose.prod.yml up -d event-service
sleep 20
docker-compose -f docker-compose.prod.yml up -d shared-service
sleep 20
docker-compose -f docker-compose.prod.yml up -d chat-service
sleep 20
docker-compose -f docker-compose.prod.yml up -d splitz-service
sleep 20
docker-compose -f docker-compose.prod.yml up -d nginx
echo "✅ All services deployed"
EOF

# Step 7: Health check
echo "🔍 Health check..."
ssh -p $VPS_PORT $VPS_USER@$VPS_HOST << 'EOF'
cd /opt/letzgo
echo "📊 Container Status:"
docker-compose -f docker-compose.prod.yml ps
echo ""
echo "🌐 Testing connectivity:"
curl -f http://localhost:3000/health 2>/dev/null && echo "✅ Auth Service OK" || echo "❌ Auth Service failed"
curl -f http://localhost:3001/health 2>/dev/null && echo "✅ User Service OK" || echo "❌ User Service failed"
echo ""
echo "🎉 Deployment completed!"
EOF

echo "🎉 Fresh infrastructure deployment completed!"
echo "🧪 Test with: curl http://$VPS_HOST:3000/health"
