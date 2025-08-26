#!/bin/bash

# ==============================================================================
# Fix Docker Network Issue on VPS
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
DEPLOY_PATH="/opt/letzgo"

echo -e "${C_BLUE}===================================================${C_RESET}"
echo -e "${C_BLUE}    Fix Docker Network Issue on VPS${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

log_info "Connecting to VPS to fix Docker network issue..."

# Check if SSH key exists
if [ ! -f ~/.ssh/id_rsa ]; then
    log_error "SSH key not found. Please run setup-ssh.sh first."
    exit 1
fi

# Connect to VPS and fix the network issue
ssh -p $VPS_PORT -o StrictHostKeyChecking=no $VPS_USER@$VPS_HOST << 'EOF'
set -e

echo "🔍 Checking Docker network status..."

# Check if letzgo-network exists
if docker network ls | grep -q letzgo-network; then
    echo "✅ letzgo-network already exists"
    docker network ls | grep letzgo-network
else
    echo "🔗 Creating letzgo-network..."
    docker network create letzgo-network
    echo "✅ letzgo-network created successfully"
fi

echo ""
echo "📋 Current Docker networks:"
docker network ls

echo ""
echo "🐳 Current Docker containers:"
docker ps -a

echo ""
echo "📦 Current Docker images:"
docker images | grep letzgo || echo "No letzgo images found"

echo ""
echo "📁 Checking deployment directory:"
ls -la /opt/letzgo/ || echo "Deployment directory not found"

echo ""
echo "🔧 Checking if infrastructure is running:"
cd /opt/letzgo 2>/dev/null || { echo "❌ /opt/letzgo directory not found"; exit 1; }

if [ -f "docker-compose.prod.yml" ]; then
    echo "📋 Infrastructure status:"
    docker-compose -f docker-compose.prod.yml ps
else
    echo "❌ docker-compose.prod.yml not found"
fi

echo ""
echo "✅ Network diagnostic complete!"
EOF

if [ $? -eq 0 ]; then
    log_success "✅ Network diagnostic completed successfully!"
    echo ""
    log_info "📋 Next Steps:"
    echo "1. The letzgo-network should now be available"
    echo "2. Try deploying a service again"
    echo "3. If infrastructure is not running, deploy infrastructure first:"
    echo "   - Go to GitHub Actions"
    echo "   - Run 'Deploy Infrastructure' workflow"
    echo "   - Then try deploying services"
else
    log_error "❌ Network diagnostic failed!"
    exit 1
fi

echo ""
echo -e "${C_GREEN}===================================================${C_RESET}"
echo -e "${C_GREEN}    Network Issue Fix Complete!${C_RESET}"
echo -e "${C_GREEN}===================================================${C_RESET}"
