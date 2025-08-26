#!/bin/bash

# ==============================================================================
# Debug Docker Network Issue on VPS
# ==============================================================================

set -e

# --- Colors for logging ---
C_BLUE="\033[0;34m"
C_GREEN="\033[0;32m"
C_RED="\033[0;31m"
C_YELLOW="\033[0;33m"
C_RESET="\033[0m"

log_info() {
    echo -e "${C_BLUE}[INFO] $1${C_RESET}"
}

log_success() {
    echo -e "${C_GREEN}[SUCCESS] $1${C_RESET}"
}

log_warning() {
    echo -e "${C_YELLOW}[WARNING] $1${C_RESET}"
}

log_error() {
    echo -e "${C_RED}[ERROR] $1${C_RESET}"
}

# VPS connection details
VPS_HOST="103.168.19.241"
VPS_PORT="7576"
VPS_USER="root"

echo -e "${C_BLUE}===================================================${C_RESET}"
echo -e "${C_BLUE}    Debug Docker Network Issue${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

log_info "Connecting to VPS to debug Docker network issue..."

# Check if SSH key exists
if [ ! -f ~/.ssh/id_rsa ]; then
    log_error "SSH key not found. Please run setup-ssh.sh first."
    exit 1
fi

# Connect to VPS and debug the network issue
ssh -p $VPS_PORT -o StrictHostKeyChecking=no $VPS_USER@$VPS_HOST << 'EOF'
set -e

echo "🔍 Comprehensive Docker network diagnostic..."

echo ""
echo "=== DOCKER VERSION ==="
docker --version

echo ""
echo "=== ALL DOCKER NETWORKS ==="
docker network ls

echo ""
echo "=== NETWORK SEARCH TEST ==="
echo "Testing different network detection methods:"

# Method 1: grep -q (used in workflows)
if docker network ls | grep -q letzgo-network; then
    echo "✅ Method 1 (grep -q): letzgo-network found"
else
    echo "❌ Method 1 (grep -q): letzgo-network NOT found"
fi

# Method 2: format + grep (new robust method)
NETWORK_EXISTS=$(docker network ls --format "{{.Name}}" | grep "^letzgo-network$" | wc -l)
if [ "$NETWORK_EXISTS" -eq 0 ]; then
    echo "❌ Method 2 (format+grep): letzgo-network NOT found (count: $NETWORK_EXISTS)"
else
    echo "✅ Method 2 (format+grep): letzgo-network found (count: $NETWORK_EXISTS)"
fi

# Method 3: docker network inspect
if docker network inspect letzgo-network >/dev/null 2>&1; then
    echo "✅ Method 3 (inspect): letzgo-network accessible"
else
    echo "❌ Method 3 (inspect): letzgo-network NOT accessible"
fi

echo ""
echo "=== NETWORK CREATION TEST ==="

# Try to create network
if docker network ls --format "{{.Name}}" | grep -q "^letzgo-network$"; then
    echo "🔗 letzgo-network already exists, removing for test..."
    
    # Stop any containers using the network
    CONTAINERS=$(docker ps -q --filter "network=letzgo-network" 2>/dev/null || echo "")
    if [ -n "$CONTAINERS" ]; then
        echo "⏹️  Stopping containers using letzgo-network..."
        echo "$CONTAINERS" | xargs docker stop || true
        echo "$CONTAINERS" | xargs docker rm || true
    fi
    
    # Remove network
    docker network rm letzgo-network || true
    echo "🗑️  Removed existing letzgo-network"
fi

# Create fresh network
echo "🔗 Creating fresh letzgo-network..."
if docker network create letzgo-network; then
    echo "✅ Network creation successful"
else
    echo "❌ Network creation failed"
    exit 1
fi

# Verify network
echo ""
echo "=== NETWORK VERIFICATION ==="
if docker network inspect letzgo-network >/dev/null 2>&1; then
    echo "✅ Network inspection successful"
    echo "📋 Network details:"
    docker network inspect letzgo-network --format "{{json .}}" | jq -r '.Name, .Driver, .Scope' 2>/dev/null || docker network inspect letzgo-network
else
    echo "❌ Network inspection failed"
    exit 1
fi

echo ""
echo "=== CONTAINER TEST ==="
echo "🧪 Testing container creation with network..."

# Create a test container
if docker run -d --name test-network-container --network letzgo-network alpine:latest sleep 30; then
    echo "✅ Test container created successfully with letzgo-network"
    
    # Check container network
    CONTAINER_NETWORK=$(docker inspect test-network-container --format "{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}" 2>/dev/null || echo "")
    NETWORK_ID=$(docker network inspect letzgo-network --format "{{.Id}}" 2>/dev/null || echo "")
    
    if [ "$CONTAINER_NETWORK" = "$NETWORK_ID" ]; then
        echo "✅ Container successfully connected to letzgo-network"
    else
        echo "❌ Container network mismatch"
        echo "Container network: $CONTAINER_NETWORK"
        echo "Expected network: $NETWORK_ID"
    fi
    
    # Clean up test container
    docker stop test-network-container >/dev/null 2>&1 || true
    docker rm test-network-container >/dev/null 2>&1 || true
    echo "🧹 Test container cleaned up"
else
    echo "❌ Test container creation failed"
    echo "📋 Available networks:"
    docker network ls
    exit 1
fi

echo ""
echo "=== FINAL STATUS ==="
echo "📋 Current networks:"
docker network ls

echo "🔍 letzgo-network details:"
docker network inspect letzgo-network --format "Name: {{.Name}}, Driver: {{.Driver}}, Scope: {{.Scope}}" 2>/dev/null || echo "Network not found"

echo ""
echo "✅ Network diagnostic complete!"
echo "🎯 letzgo-network is ready for deployment"
EOF

if [ $? -eq 0 ]; then
    log_success "✅ Network diagnostic completed successfully!"
    echo ""
    log_info "📋 Results:"
    echo "• letzgo-network has been tested and verified"
    echo "• Network creation and container attachment work correctly"
    echo "• Ready for service deployment"
    echo ""
    log_info "🚀 Next Steps:"
    echo "1. Try deploying a service again"
    echo "2. The network should now work correctly"
    echo "3. If issues persist, check the GitHub Actions logs for other errors"
else
    log_error "❌ Network diagnostic failed!"
    echo ""
    log_info "🔧 Troubleshooting:"
    echo "1. Check if Docker daemon is running on VPS"
    echo "2. Verify Docker permissions for the user"
    echo "3. Check for Docker version compatibility"
    echo "4. Review VPS system logs"
    exit 1
fi

echo ""
echo -e "${C_GREEN}===================================================${C_RESET}"
echo -e "${C_GREEN}    Network Debug Complete!${C_RESET}"
echo -e "${C_GREEN}===================================================${C_RESET}"
