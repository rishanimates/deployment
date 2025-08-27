#!/bin/bash

# Quick Fix for Missing Service Repositories
# This script creates local service repositories when GitHub repos don't exist

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🔧 Quick Fix: Creating Missing Service Repositories"
echo "=================================================="

# Configuration
DEPLOY_PATH="/opt/letzgo"
SERVICES=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")

# Get service port
get_service_port() {
    local service="$1"
    case "$service" in
        "auth-service") echo "3000" ;;
        "user-service") echo "3001" ;;
        "chat-service") echo "3002" ;;
        "event-service") echo "3003" ;;
        "shared-service") echo "3004" ;;
        "splitz-service") echo "3005" ;;
        *) echo "3000" ;;
    esac
}

# Create minimal service repository
create_service() {
    local service="$1"
    local port=$(get_service_port "$service")
    local service_dir="$DEPLOY_PATH/services/$service"
    
    log_info "Creating $service repository..."
    
    # Remove existing directory
    rm -rf "$service_dir"
    mkdir -p "$service_dir"
    cd "$service_dir"
    
    # Initialize git
    git init >/dev/null 2>&1
    
    # Create package.json
    cat > package.json << EOF
{
  "name": "$service",
  "version": "1.0.0",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5"
  }
}
EOF
    
    # Create empty yarn.lock
    touch yarn.lock
    
    # Create Dockerfile
    cat > Dockerfile << 'EOF'
FROM node:20-alpine
WORKDIR /app
RUN apk add --no-cache curl
COPY package*.json ./
COPY yarn.lock ./
RUN yarn install --production
COPY . .
EXPOSE 3000
HEALTHCHECK CMD curl -f http://localhost:3000/health || exit 1
CMD ["yarn", "start"]
EOF
    
    # Create source code
    mkdir -p src
    cat > src/app.js << EOF
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || $port;

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        service: '$service',
        timestamp: new Date().toISOString(),
        port: PORT
    });
});

app.get('/api/v1/status', (req, res) => {
    res.json({
        service: '$service',
        status: 'running',
        timestamp: new Date().toISOString()
    });
});

app.get('/', (req, res) => {
    res.json({
        message: 'LetzGo $service is running',
        endpoints: ['/health', '/api/v1/status']
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(\`🚀 $service listening on port \${PORT}\`);
});
EOF
    
    # Commit
    git add . >/dev/null 2>&1
    git commit -m "Quick fix: Initial $service setup" >/dev/null 2>&1
    
    log_success "✅ $service created"
}

# Main execution
main() {
    # Create services directory
    mkdir -p "$DEPLOY_PATH/services"
    
    # Create each service
    for service in "${SERVICES[@]}"; do
        create_service "$service"
    done
    
    echo ""
    log_success "🎉 All service repositories created!"
    echo ""
    echo "📋 Created services:"
    for service in "${SERVICES[@]}"; do
        local port=$(get_service_port "$service")
        echo "  ✅ $service (Port $port)"
    done
    
    echo ""
    echo "🚀 You can now run: ./deploy-services.sh all main"
}

main "$@"
