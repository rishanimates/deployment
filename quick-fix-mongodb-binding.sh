#!/bin/bash

# Quick Fix for MongoDB External Binding
# Run this script on your VPS to fix MongoDB external access

set -e

echo "🔧 Quick Fix: MongoDB External Access"
echo "====================================="
echo ""

# Get current MongoDB container info
MONGO_CONTAINER=$(docker ps --format "{{.Names}}" | grep mongo | head -1)

if [ -z "$MONGO_CONTAINER" ]; then
    echo "❌ No MongoDB container found running"
    echo "Please run the infrastructure deployment first"
    exit 1
fi

echo "📋 Current MongoDB container: $MONGO_CONTAINER"
echo ""

# Check current port binding
CURRENT_PORTS=$(docker port "$MONGO_CONTAINER" 2>/dev/null || echo "No port mappings")
echo "📋 Current port binding: $CURRENT_PORTS"
echo ""

# Check if already properly bound
if echo "$CURRENT_PORTS" | grep -q "0.0.0.0:27017"; then
    echo "✅ MongoDB is already bound to 0.0.0.0:27017"
    echo "   The issue might be elsewhere. Try connecting with:"
    echo "   mongosh mongodb://admin:password@103.168.19.241:27017"
    exit 0
fi

echo "🔧 Fixing MongoDB port binding..."
echo ""

# Get MongoDB password from environment or container
MONGO_PASSWORD=""
if [ -f "/opt/letzgo/.env" ]; then
    MONGO_PASSWORD=$(grep MONGODB_PASSWORD /opt/letzgo/.env | cut -d'=' -f2 | tr -d '"' || echo "")
fi

if [ -z "$MONGO_PASSWORD" ]; then
    # Try to get from running container
    MONGO_PASSWORD=$(docker exec "$MONGO_CONTAINER" env | grep MONGO_INITDB_ROOT_PASSWORD | cut -d'=' -f2 || echo "admin123")
fi

echo "📋 Using MongoDB password: ${MONGO_PASSWORD:0:3}..."
echo ""

# Stop current container
echo "🛑 Stopping current MongoDB container..."
docker stop "$MONGO_CONTAINER"

# Remove current container
echo "🗑️ Removing current MongoDB container..."
docker rm "$MONGO_CONTAINER"

# Create volume if it doesn't exist
docker volume create mongodb_data 2>/dev/null || echo "Volume mongodb_data already exists"

# Run new container with proper binding
echo "🚀 Starting MongoDB with external binding..."
docker run -d \
  --name letzgo-mongodb \
  --network letzgo-network \
  --restart unless-stopped \
  -p 0.0.0.0:27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD="$MONGO_PASSWORD" \
  -v mongodb_data:/data/db \
  mongo:7.0

echo ""
echo "⏳ Waiting for MongoDB to start..."
sleep 10

# Test connection
echo "🔍 Testing MongoDB connection..."
if docker exec letzgo-mongodb mongosh --eval "db.adminCommand('ping')" --quiet 2>/dev/null; then
    echo "✅ MongoDB is running and responding"
else
    echo "⚠️ MongoDB may still be starting up..."
fi

# Show new port binding
echo ""
echo "📋 New port binding:"
docker port letzgo-mongodb

echo ""
echo "🎉 MongoDB External Access Fix Complete!"
echo ""
echo "🔗 You can now connect using:"
echo "   mongosh mongodb://admin:$MONGO_PASSWORD@103.168.19.241:27017"
echo ""
echo "🧪 Test connection:"
echo "   telnet 103.168.19.241 27017"
echo ""

