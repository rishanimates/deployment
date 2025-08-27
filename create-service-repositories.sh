#!/bin/bash

# Create Service Repositories Script
# This script creates placeholder service repositories if they don't exist

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${CYAN}"
echo "============================================================================"
echo "🏗️ LetzGo Service Repositories Creator"
echo "============================================================================"
echo -e "${NC}"
echo "📅 Started: $(date)"
echo ""

# Configuration
GITHUB_USER="rhushirajpatil"
DEPLOY_PATH="/opt/letzgo"

# Services to create
SERVICES=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")

# Create local service repositories for testing
create_local_service_repo() {
    local service="$1"
    local service_dir="$DEPLOY_PATH/services/$service"
    local port=$(get_service_port "$service")
    
    log_info "📦 Creating local repository for $service..."
    
    # Create service directory
    mkdir -p "$service_dir"
    cd "$service_dir"
    
    # Initialize git repository
    git init
    
    # Create package.json
    cat > "package.json" << EOF
{
  "name": "$service",
  "version": "1.0.0",
  "description": "LetzGo $service microservice",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "dev": "nodemon src/app.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1",
    "pg": "^8.11.3",
    "mongodb": "^6.0.0",
    "redis": "^4.6.7",
    "amqplib": "^0.10.3",
    "bcrypt": "^5.1.1",
    "jsonwebtoken": "^9.0.2",
    "uuid": "^9.0.0",
    "joi": "^17.9.2",
    "axios": "^1.5.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.6.2"
  },
  "engines": {
    "node": ">=20.0.0"
  }
}
EOF
    
    # Create yarn.lock (empty for now)
    touch yarn.lock
    
    # Create Dockerfile
    cat > "Dockerfile" << 'EOF'
FROM node:20-alpine

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache curl netcat-openbsd

# Copy package files
COPY package*.json ./
COPY yarn.lock ./

# Install dependencies
RUN yarn install --frozen-lockfile --production

# Copy source code
COPY . .

# Create logs and uploads directories
RUN mkdir -p logs uploads && \
    chown -R node:node logs uploads && \
    chmod 755 logs uploads

# Switch to non-root user
USER node

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["yarn", "start"]
EOF
    
    # Create src directory and app.js
    mkdir -p src
    cat > "src/app.js" << EOF
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || $port;

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        service: '$service',
        version: '1.0.0',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV || 'development',
        port: PORT
    });
});

// API routes
app.get('/api/v1/status', (req, res) => {
    res.json({
        service: '$service',
        version: '1.0.0',
        status: 'running',
        timestamp: new Date().toISOString(),
        endpoints: ['/health', '/api/v1/status']
    });
});

// Service-specific routes placeholder
app.get('/api/v1/${service}', (req, res) => {
    res.json({
        message: 'LetzGo $service API',
        version: '1.0.0',
        endpoints: {
            health: '/health',
            status: '/api/v1/status',
            service: '/api/v1/${service}'
        }
    });
});

// Default route
app.get('/', (req, res) => {
    res.json({
        message: 'LetzGo $service is running',
        version: '1.0.0',
        service: '$service',
        port: PORT,
        endpoints: ['/health', '/api/v1/status', '/api/v1/${service}']
    });
});

// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({
        error: 'Not Found',
        message: 'The requested endpoint does not exist',
        service: '$service'
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Error:', err.stack);
    res.status(500).json({
        error: 'Internal Server Error',
        message: err.message,
        service: '$service'
    });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(\`🚀 \${new Date().toISOString()} - $service listening on port \${PORT}\`);
    console.log(\`🌍 Environment: \${process.env.NODE_ENV || 'development'}\`);
    console.log(\`🏥 Health check: http://localhost:\${PORT}/health\`);
    console.log(\`📡 API endpoint: http://localhost:\${PORT}/api/v1/${service}\`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    process.exit(0);
});
EOF
    
    # Create README
    cat > "README.md" << EOF
# $service

LetzGo $service microservice

## Description
This is the $service microservice for the LetzGo application.

## API Endpoints
- \`GET /health\` - Health check
- \`GET /api/v1/status\` - Service status
- \`GET /api/v1/${service}\` - Service-specific endpoint

## Development
\`\`\`bash
# Install dependencies
yarn install

# Start development server
yarn dev

# Start production server
yarn start
\`\`\`

## Docker
\`\`\`bash
# Build image
docker build -t letzgo-$service .

# Run container
docker run -p $port:$port letzgo-$service
\`\`\`

## Environment Variables
- \`PORT\` - Server port (default: $port)
- \`NODE_ENV\` - Environment (development/production)
EOF
    
    # Create .gitignore
    cat > ".gitignore" << EOF
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/
*.lcov

# nyc test coverage
.nyc_output

# Grunt intermediate storage
.grunt

# Bower dependency directory
bower_components

# node-waf configuration
.lock-wscript

# Compiled binary addons
build/Release

# Dependency directories
jspm_packages/

# TypeScript cache
*.tsbuildinfo

# Optional npm cache directory
.npm

# Optional eslint cache
.eslintcache

# Microbundle cache
.rpt2_cache/
.rts2_cache_cjs/
.rts2_cache_es/
.rts2_cache_umd/

# Optional REPL history
.node_repl_history

# Output of 'npm pack'
*.tgz

# Yarn Integrity file
.yarn-integrity

# dotenv environment variables file
.env
.env.test
.env.production
.env.local

# parcel-bundler cache
.cache
.parcel-cache

# Next.js build output
.next

# Nuxt.js build / generate output
.nuxt
dist

# Gatsby files
.cache/
public

# Storybook build outputs
.out
.storybook-out

# Temporary folders
tmp/
temp/

# Logs
logs
*.log

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
EOF
    
    # Add all files and commit
    git add .
    git commit -m "Initial commit for $service

- Basic Express.js setup with health endpoints
- Docker configuration
- Package.json with dependencies
- README with API documentation"
    
    # Create develop branch
    git checkout -b develop
    git checkout main
    
    log_success "✅ Local repository created for $service"
}

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

# Main execution
main() {
    log_info "🏗️ Creating service repositories..."
    
    # Create services directory
    mkdir -p "$DEPLOY_PATH/services"
    
    # Create each service repository
    for service in "${SERVICES[@]}"; do
        echo ""
        log_info "Creating $service..."
        create_local_service_repo "$service"
    done
    
    echo ""
    echo -e "${CYAN}============================================================================${NC}"
    echo -e "${GREEN}🎉 Service Repositories Created Successfully!${NC}"
    echo -e "${CYAN}============================================================================${NC}"
    echo ""
    
    echo "📦 Created services:"
    for service in "${SERVICES[@]}"; do
        local port=$(get_service_port "$service")
        echo "  ✅ $service (Port $port) - $DEPLOY_PATH/services/$service"
    done
    
    echo ""
    echo "🔧 Next steps:"
    echo "  1. The services are ready for deployment"
    echo "  2. Each service has a basic Express.js setup"
    echo "  3. Run deployment: ./deploy-services.sh all main"
    echo "  4. Test endpoints: curl http://localhost:PORT/health"
    echo ""
    echo "📝 Note: These are local repositories for testing."
    echo "   For production, push these to GitHub repositories."
}

main "$@"
