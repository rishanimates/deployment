#!/bin/bash
set -e

echo "🔄 Restarting all services with updated environment variables..."
cd /opt/letzgo

# Define services and their ports
declare -A services=(
    ["auth-service"]="3000"
    ["user-service"]="3001"
    ["chat-service"]="3002"
    ["event-service"]="3003"
    ["shared-service"]="3004"
    ["splitz-service"]="3005"
)

# Function to restart a service
restart_service() {
    local service_name=$1
    local port=$2
    
    echo "🔄 Restarting $service_name..."
    
    # Stop and remove existing container
    docker stop letzgo-$service_name || true
    docker rm letzgo-$service_name || true
    
    # Start new container with updated environment
    docker run -d \
        --name letzgo-$service_name \
        --network letzgo-network \
        -p $port:$port \
        --env-file .env \
        -e NODE_ENV=staging \
        -e PORT=$port \
        -v /opt/letzgo/logs:/app/logs \
        -v /opt/letzgo/uploads:/app/uploads \
        --restart unless-stopped \
        letzgo-$service_name:latest
    
    echo "✅ $service_name restarted"
}

# Restart all services
for service in "${!services[@]}"; do
    port=${services[$service]}
    restart_service $service $port
    sleep 2  # Small delay between restarts
done

echo "⏳ Waiting 30 seconds for all services to initialize..."
sleep 30

echo "🏥 Checking health of all services:"
for service in "${!services[@]}"; do
    port=${services[$service]}
    echo -n "$service (port $port): "
    
    if curl -f -s http://localhost:$port/health > /dev/null 2>&1; then
        echo "✅ HEALTHY"
    else
        echo "⚠️ NOT READY (may still be starting)"
        # Show recent logs for debugging
        echo "📋 Recent logs for $service:"
        docker logs letzgo-$service --tail 5 | head -3
        echo ""
    fi
done

echo ""
echo "📋 Container status summary:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep letzgo- | head -6
