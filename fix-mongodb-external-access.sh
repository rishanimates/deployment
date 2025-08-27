#!/bin/bash

# MongoDB External Access Fix Script
# This script diagnoses and fixes MongoDB external connectivity issues

set -e

echo "🔍 MongoDB External Access Diagnosis"
echo "===================================="
echo ""

# Check if MongoDB container is running
echo "📋 Step 1: Check MongoDB Container Status"
echo "-----------------------------------------"
if docker ps | grep -q mongo; then
    echo "✅ MongoDB container is running"
    MONGO_CONTAINER=$(docker ps --format "table {{.Names}}\t{{.Ports}}" | grep mongo | head -1)
    echo "   Container info: $MONGO_CONTAINER"
else
    echo "❌ MongoDB container is not running"
    echo "   Available containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    exit 1
fi
echo ""

# Check Docker port binding
echo "📋 Step 2: Check Docker Port Binding"
echo "------------------------------------"
MONGO_PORTS=$(docker ps --format "{{.Ports}}" | grep mongo | head -1)
echo "MongoDB container ports: $MONGO_PORTS"

if echo "$MONGO_PORTS" | grep -q "0.0.0.0:27017"; then
    echo "✅ MongoDB is bound to external interface (0.0.0.0:27017)"
elif echo "$MONGO_PORTS" | grep -q "127.0.0.1:27017"; then
    echo "❌ MongoDB is only bound to localhost (127.0.0.1:27017)"
    echo "   This prevents external access"
elif echo "$MONGO_PORTS" | grep -q "27017"; then
    echo "⚠️ MongoDB port binding detected but may not be external"
else
    echo "❌ MongoDB port 27017 is not exposed"
fi
echo ""

# Check MongoDB container details
echo "📋 Step 3: Detailed Container Inspection"
echo "----------------------------------------"
MONGO_CONTAINER_NAME=$(docker ps --format "{{.Names}}" | grep mongo | head -1)
if [ -n "$MONGO_CONTAINER_NAME" ]; then
    echo "Container name: $MONGO_CONTAINER_NAME"
    echo ""
    echo "Port mappings:"
    docker port "$MONGO_CONTAINER_NAME" || echo "No port mappings found"
    echo ""
    echo "Container network settings:"
    docker inspect "$MONGO_CONTAINER_NAME" --format='{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostIP}}:{{(index $conf 0).HostPort}}{{end}}' || echo "No network settings found"
fi
echo ""

# Check if MongoDB is listening on the right interface
echo "📋 Step 4: Check MongoDB Binding Inside Container"
echo "-------------------------------------------------"
if [ -n "$MONGO_CONTAINER_NAME" ]; then
    echo "Checking MongoDB process inside container:"
    docker exec "$MONGO_CONTAINER_NAME" netstat -tlnp 2>/dev/null | grep 27017 || echo "netstat not available, trying alternative..."
    
    # Alternative check
    echo "Checking if MongoDB is accessible inside container:"
    docker exec "$MONGO_CONTAINER_NAME" mongosh --eval "db.adminCommand('ping')" --quiet 2>/dev/null && echo "✅ MongoDB is responding inside container" || echo "❌ MongoDB is not responding inside container"
fi
echo ""

# Check external connectivity
echo "📋 Step 5: Test External Connectivity"
echo "-------------------------------------"
echo "Testing connection to localhost:27017..."
if timeout 5 bash -c "echo >/dev/tcp/localhost/27017" 2>/dev/null; then
    echo "✅ MongoDB is accessible on localhost:27017"
else
    echo "❌ MongoDB is NOT accessible on localhost:27017"
fi

echo ""
echo "Testing connection to 0.0.0.0:27017..."
if timeout 5 bash -c "echo >/dev/tcp/0.0.0.0/27017" 2>/dev/null; then
    echo "✅ MongoDB is accessible on 0.0.0.0:27017"
else
    echo "❌ MongoDB is NOT accessible on 0.0.0.0:27017"
fi
echo ""

# Check firewall status
echo "📋 Step 6: Firewall Configuration"
echo "---------------------------------"
echo "Checking firewall rules for port 27017:"
firewall-cmd --list-ports | grep -q 27017 && echo "✅ Port 27017 is open in firewall" || echo "❌ Port 27017 is not open in firewall"

echo ""
echo "Active firewall ports:"
firewall-cmd --list-ports
echo ""

# Check what's listening on port 27017
echo "📋 Step 7: What's Listening on Port 27017"
echo "-----------------------------------------"
echo "Processes listening on port 27017:"
netstat -tlnp | grep 27017 || ss -tlnp | grep 27017 || echo "No processes found listening on port 27017"
echo ""

# Provide fix recommendations
echo "🔧 Fix Recommendations"
echo "======================"
echo ""

# Check current docker-compose or run command
if [ -f "/opt/letzgo/docker-compose.yml" ]; then
    echo "Found docker-compose.yml, checking MongoDB configuration..."
    echo ""
    echo "Current MongoDB configuration in docker-compose.yml:"
    grep -A 10 -B 2 "mongo" /opt/letzgo/docker-compose.yml || echo "MongoDB not found in docker-compose.yml"
    echo ""
fi

echo "🔧 Solution Options:"
echo ""

echo "Option 1: Fix Docker Port Binding"
echo "---------------------------------"
echo "If MongoDB is not bound to 0.0.0.0:27017, you need to:"
echo ""
echo "1. Stop the current MongoDB container:"
echo "   docker stop $MONGO_CONTAINER_NAME"
echo ""
echo "2. Remove the container:"
echo "   docker rm $MONGO_CONTAINER_NAME"
echo ""
echo "3. Run MongoDB with proper port binding:"
echo "   docker run -d \\"
echo "     --name letzgo-mongodb \\"
echo "     --network letzgo-network \\"
echo "     --restart unless-stopped \\"
echo "     -p 0.0.0.0:27017:27017 \\"
echo "     -e MONGO_INITDB_ROOT_USERNAME=admin \\"
echo "     -e MONGO_INITDB_ROOT_PASSWORD=\${MONGODB_PASSWORD} \\"
echo "     -v mongodb_data:/data/db \\"
echo "     mongo:7.0"
echo ""

echo "Option 2: Update docker-compose.yml"
echo "-----------------------------------"
echo "If using docker-compose, ensure MongoDB service has:"
echo ""
echo "services:"
echo "  mongodb:"
echo "    image: mongo:7.0"
echo "    ports:"
echo "      - \"0.0.0.0:27017:27017\"  # This ensures external binding"
echo "    # ... other configuration"
echo ""

echo "Option 3: Quick Fix Command"
echo "---------------------------"
echo "Run this command to fix the port binding immediately:"
echo ""
echo "# Stop and remove current container"
echo "docker stop \$(docker ps --format '{{.Names}}' | grep mongo) || true"
echo "docker rm \$(docker ps -a --format '{{.Names}}' | grep mongo) || true"
echo ""
echo "# Run with correct port binding"
echo "docker run -d \\"
echo "  --name letzgo-mongodb \\"
echo "  --network letzgo-network \\"
echo "  --restart unless-stopped \\"
echo "  -p 0.0.0.0:27017:27017 \\"
echo "  -e MONGO_INITDB_ROOT_USERNAME=admin \\"
echo "  -e MONGO_INITDB_ROOT_PASSWORD=your_password_here \\"
echo "  mongo:7.0"
echo ""

echo "After applying the fix:"
echo "1. Test connection: mongosh mongodb://admin:password@103.168.19.241:27017"
echo "2. Or test with telnet: telnet 103.168.19.241 27017"
echo ""

echo "🎯 MongoDB External Access Diagnosis Complete!"
echo "=============================================="

