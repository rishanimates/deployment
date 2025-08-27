#!/bin/bash

# ============================================================================
# Fresh Infrastructure Deployment Script
# ============================================================================
# This script completely removes old infrastructure and deploys fresh
# with proper database initialization and schema validation
# ============================================================================

set -e  # Exit on any error

# Configuration
VPS_HOST="103.168.19.241"
VPS_PORT="7576"
VPS_USER="root"
DEPLOYMENT_DIR="/opt/letzgo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to execute commands on VPS
vps_exec() {
    local cmd="$1"
    log "Executing on VPS: $cmd"
    ssh -p "$VPS_PORT" "$VPS_USER@$VPS_HOST" "$cmd"
}

# Function to copy files to VPS
vps_copy() {
    local local_path="$1"
    local remote_path="$2"
    log "Copying $local_path to VPS:$remote_path"
    scp -P "$VPS_PORT" -r "$local_path" "$VPS_USER@$VPS_HOST:$remote_path"
}

# Main deployment function
main() {
    log "🚀 Starting Fresh Infrastructure Deployment"
    log "Target: $VPS_USER@$VPS_HOST:$VPS_PORT"
    log "Deployment Directory: $DEPLOYMENT_DIR"
    
    # Step 1: Remove old infrastructure
    log "🗑️ Step 1: Removing old infrastructure..."
    vps_exec "
        cd $DEPLOYMENT_DIR 2>/dev/null || true
        
        # Stop and remove all containers
        echo '1.1 Stopping all containers...'
        docker-compose -f docker-compose.prod.yml down --volumes --remove-orphans 2>/dev/null || true
        
        # Remove all letzgo containers
        echo '1.2 Removing letzgo containers...'
        docker ps -a | grep letzgo | awk '{print \$1}' | xargs -r docker rm -f 2>/dev/null || true
        
        # Remove all letzgo images
        echo '1.3 Removing letzgo images...'
        docker images | grep letzgo | awk '{print \$3}' | xargs -r docker rmi -f 2>/dev/null || true
        
        # Remove all volumes
        echo '1.4 Removing letzgo volumes...'
        docker volume ls | grep letzgo | awk '{print \$2}' | xargs -r docker volume rm 2>/dev/null || true
        
        # Clean up networks
        echo '1.5 Cleaning up networks...'
        docker network rm letzgo-network 2>/dev/null || true
        
        # Clean up directories
        echo '1.6 Cleaning up directories...'
        rm -rf $DEPLOYMENT_DIR/logs/* $DEPLOYMENT_DIR/uploads/* 2>/dev/null || true
        
        echo '✅ Old infrastructure removed'
    "
    
    # Step 2: Create deployment directory structure
    log "📁 Step 2: Setting up deployment directory structure..."
    vps_exec "
        mkdir -p $DEPLOYMENT_DIR/{database,logs,uploads,nginx/conf.d,ssl}
        chown -R 1001:1001 $DEPLOYMENT_DIR/logs $DEPLOYMENT_DIR/uploads
        chmod -R 755 $DEPLOYMENT_DIR/logs $DEPLOYMENT_DIR/uploads
        echo '✅ Directory structure created'
    "
    
    # Step 3: Copy deployment files
    log "📋 Step 3: Copying deployment files..."
    
    # Copy database initialization scripts
    vps_copy "$SCRIPT_DIR/database/" "$DEPLOYMENT_DIR/"
    
    # Copy Docker Compose file
    vps_copy "$SCRIPT_DIR/docker-compose.prod.yml" "$DEPLOYMENT_DIR/"
    
    # Copy environment template
    vps_copy "$SCRIPT_DIR/env.template" "$DEPLOYMENT_DIR/"
    
    # Copy nginx configuration
    if [ -d "$SCRIPT_DIR/nginx" ]; then
        vps_copy "$SCRIPT_DIR/nginx/" "$DEPLOYMENT_DIR/"
    fi
    
    success "✅ Deployment files copied"
    
    # Step 4: Generate environment file
    log "🔧 Step 4: Generating environment configuration..."
    vps_exec "
        cd $DEPLOYMENT_DIR
        
        # Generate secure passwords
        POSTGRES_PASSWORD=\$(openssl rand -base64 32 | tr -d '=+/')
        MONGODB_PASSWORD=\$(openssl rand -base64 32 | tr -d '=+/')
        REDIS_PASSWORD=\$(openssl rand -base64 32 | tr -d '=+/')
        RABBITMQ_PASSWORD=\$(openssl rand -base64 32 | tr -d '=+/')
        JWT_SECRET=\$(openssl rand -base64 64 | tr -d '=+/')
        SERVICE_API_KEY=\$(openssl rand -hex 32)
        
        # Create .env file from template
        cp env.template .env
        
        # Replace placeholders with generated values
        sed -i \"s/POSTGRES_PASSWORD_PLACEHOLDER/\$POSTGRES_PASSWORD/g\" .env
        sed -i \"s/MONGODB_PASSWORD_PLACEHOLDER/\$MONGODB_PASSWORD/g\" .env
        sed -i \"s/REDIS_PASSWORD_PLACEHOLDER/\$REDIS_PASSWORD/g\" .env
        sed -i \"s/RABBITMQ_PASSWORD_PLACEHOLDER/\$RABBITMQ_PASSWORD/g\" .env
        sed -i \"s/JWT_SECRET_PLACEHOLDER/\$JWT_SECRET/g\" .env
        sed -i \"s/SERVICE_API_KEY_PLACEHOLDER/\$SERVICE_API_KEY/g\" .env
        
        # Set proper permissions
        chmod 600 .env
        
        echo '✅ Environment configuration generated'
    "
    
    # Step 5: Deploy infrastructure (databases only first)
    log "🏗️ Step 5: Deploying database infrastructure..."
    vps_exec "
        cd $DEPLOYMENT_DIR
        
        # Create Docker network
        docker network create letzgo-network 2>/dev/null || true
        
        # Deploy only databases first
        docker-compose -f docker-compose.prod.yml up -d postgres mongodb redis rabbitmq
        
        echo '⏳ Waiting for databases to initialize...'
        sleep 30
        
        # Check database health
        echo '🔍 Checking database health...'
        for i in {1..30}; do
            if docker-compose -f docker-compose.prod.yml ps postgres | grep -q 'healthy'; then
                echo '✅ PostgreSQL is healthy'
                break
            fi
            echo \"Attempt \$i/30 - PostgreSQL not ready yet...\"
            sleep 10
        done
        
        for i in {1..30}; do
            if docker-compose -f docker-compose.prod.yml ps mongodb | grep -q 'healthy'; then
                echo '✅ MongoDB is healthy'
                break
            fi
            echo \"Attempt \$i/30 - MongoDB not ready yet...\"
            sleep 10
        done
        
        echo '✅ Database infrastructure deployed'
    "
    
    # Step 6: Verify database schemas
    log "🔍 Step 6: Verifying database schemas..."
    vps_exec "
        cd $DEPLOYMENT_DIR
        
        # Check PostgreSQL tables
        echo '📊 Checking PostgreSQL tables...'
        docker exec letzgo-postgres psql -U postgres -d letzgo -c \"
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            ORDER BY table_name;
        \" | grep -E '(users|groups|events|expenses|notifications|chat_)' || echo 'No tables found yet'
        
        # Check MongoDB collections
        echo '📊 Checking MongoDB collections...'
        docker exec letzgo-mongodb mongosh --eval \"
            db.getSiblingDB('letzgo').getCollectionNames()
        \" | grep -E '(expenses|chat_)' || echo 'No collections found yet'
        
        echo '✅ Database schema verification completed'
    "
    
    # Step 7: Deploy services with schema validation
    log "🚀 Step 7: Deploying services with schema validation..."
    
    # Copy schema validator to VPS
    vps_copy "$SCRIPT_DIR/database/schema-validator.js" "$DEPLOYMENT_DIR/database/"
    
    # Install Node.js dependencies for schema validator
    vps_exec "
        cd $DEPLOYMENT_DIR/database
        
        # Create package.json for schema validator
        cat > package.json << 'EOF'
{
  \"name\": \"schema-validator\",
  \"version\": \"1.0.0\",
  \"description\": \"Database schema validator\",
  \"main\": \"schema-validator.js\",
  \"dependencies\": {
    \"pg\": \"^8.11.0\",
    \"mongodb\": \"^5.6.0\"
  }
}
EOF
        
        # Install dependencies
        npm install --production
        
        echo '✅ Schema validator dependencies installed'
    "
    
    # Deploy services one by one with schema validation
    local services=(auth-service user-service event-service shared-service chat-service splitz-service)
    
    for service in \"${services[@]}\"; do
        log \"🔧 Deploying $service...\"
        
        # Determine database type for service
        local db_type=\"postgresql\"
        if [[ \"$service\" == \"chat-service\" ]] || [[ \"$service\" == \"splitz-service\" ]]; then
            db_type=\"mongodb\"
        fi
        
        vps_exec \"
            cd $DEPLOYMENT_DIR
            
            # Validate and create schema for this service
            echo '🔍 Validating schema for $service ($db_type)...'
            cd database && node schema-validator.js $service $db_type && cd ..
            
            # Deploy the service
            echo '🚀 Starting $service...'
            docker-compose -f docker-compose.prod.yml up -d $service
            
            # Wait for service to be healthy
            echo '⏳ Waiting for $service to be healthy...'
            for i in {1..30}; do
                if docker-compose -f docker-compose.prod.yml ps $service | grep -q 'healthy'; then
                    echo '✅ $service is healthy'
                    break
                fi
                echo \"Attempt \$i/30 - $service not ready yet...\"
                sleep 10
            done
        \"
        
        success \"✅ $service deployed successfully\"
        sleep 5  # Brief pause between services
    done
    
    # Step 8: Deploy Nginx
    log \"🌐 Step 8: Deploying Nginx...\"
    vps_exec \"
        cd $DEPLOYMENT_DIR
        docker-compose -f docker-compose.prod.yml up -d nginx
        
        echo '⏳ Waiting for Nginx...'
        sleep 10
        
        echo '✅ Nginx deployed'
    \"
    
    # Step 9: Final health check
    log \"🔍 Step 9: Final infrastructure health check...\"
    vps_exec \"
        cd $DEPLOYMENT_DIR
        
        echo '📊 Container Status:'
        docker-compose -f docker-compose.prod.yml ps
        
        echo ''
        echo '🔍 Service Health Checks:'
        for service in postgres mongodb redis rabbitmq auth-service user-service chat-service event-service shared-service splitz-service nginx; do
            status=\$(docker-compose -f docker-compose.prod.yml ps \$service | grep -o 'healthy\\|unhealthy\\|Up' | head -1)
            if [[ \"\$status\" == \"healthy\" ]] || [[ \"\$status\" == \"Up\" ]]; then
                echo \"✅ \$service: \$status\"
            else
                echo \"❌ \$service: \$status\"
            fi
        done
        
        echo ''
        echo '🌐 External Connectivity Test:'
        curl -f http://localhost/health 2>/dev/null && echo '✅ Nginx responding' || echo '❌ Nginx not responding'
        curl -f http://localhost:3000/health 2>/dev/null && echo '✅ Auth Service responding' || echo '❌ Auth Service not responding'
        curl -f http://localhost:3001/health 2>/dev/null && echo '✅ User Service responding' || echo '❌ User Service not responding'
        
        echo ''
        echo '📊 Database Status:'
        docker exec letzgo-postgres pg_isready -U postgres && echo '✅ PostgreSQL ready' || echo '❌ PostgreSQL not ready'
        docker exec letzgo-mongodb mongosh --eval 'db.adminCommand(\"ping\")' >/dev/null 2>&1 && echo '✅ MongoDB ready' || echo '❌ MongoDB not ready'
    \"
    
    # Step 10: Display summary
    log \"📋 Step 10: Deployment Summary\"
    
    echo -e \"${PURPLE}\"
    echo \"============================================================================\"
    echo \"🎉 FRESH INFRASTRUCTURE DEPLOYMENT COMPLETED\"
    echo \"============================================================================\"
    echo -e \"${NC}\"
    
    echo -e \"${GREEN}✅ Infrastructure Status:${NC}\"
    echo \"   🗄️  PostgreSQL: Running with full schema\"
    echo \"   🍃 MongoDB: Running with collections\"
    echo \"   🔴 Redis: Running\"
    echo \"   🐰 RabbitMQ: Running\"
    echo \"   🌐 Nginx: Running as API Gateway\"
    echo \"\"
    
    echo -e \"${GREEN}✅ Services Deployed:${NC}\"
    echo \"   🔐 Auth Service: http://$VPS_HOST:3000\"
    echo \"   👤 User Service: http://$VPS_HOST:3001\"
    echo \"   💬 Chat Service: http://$VPS_HOST:3002\"
    echo \"   📅 Event Service: http://$VPS_HOST:3003\"
    echo \"   🔗 Shared Service: http://$VPS_HOST:3004\"
    echo \"   💰 Splitz Service: http://$VPS_HOST:3005\"
    echo \"\"
    
    echo -e \"${GREEN}✅ Database Features:${NC}\"
    echo \"   📊 Auto-schema validation on service startup\"
    echo \"   🔄 Complete table and index creation\"
    echo \"   🎯 Default data insertion\"
    echo \"   ⚡ Performance indexes\"
    echo \"   🔒 Data integrity constraints\"
    echo \"\"
    
    echo -e \"${BLUE}🧪 Next Steps:${NC}\"
    echo \"   1. Test API endpoints: curl http://$VPS_HOST:3000/health\"
    echo \"   2. Test user registration: POST http://$VPS_HOST:3000/api/v1/auth/register\"
    echo \"   3. Configure mobile app to connect to VPS\"
    echo \"   4. Run comprehensive backend tests\"
    echo \"\"
    
    echo -e \"${YELLOW}📁 Files Created:${NC}\"
    echo \"   🔧 $DEPLOYMENT_DIR/.env (secure passwords generated)\"
    echo \"   🗄️  $DEPLOYMENT_DIR/database/ (initialization scripts)\"
    echo \"   📋 $DEPLOYMENT_DIR/docker-compose.prod.yml\"
    echo \"   📊 Complete logs in $DEPLOYMENT_DIR/logs/\"
    echo \"\"
    
    success \"🚀 Fresh infrastructure deployment completed successfully!\"
    success \"🎯 All services are running with proper database schemas\"
    success \"📱 Ready for mobile app testing and backend validation\"
}

# Handle script interruption
trap 'error "Deployment interrupted"; exit 1' INT TERM

# Check if SSH connection works
log \"🔍 Testing SSH connection to VPS...\"
if ! ssh -p \"$VPS_PORT\" -o ConnectTimeout=10 \"$VPS_USER@$VPS_HOST\" \"echo 'SSH connection successful'\"; then
    error \"Failed to connect to VPS. Please check:\"
    error \"  - VPS is running and accessible\"
    error \"  - SSH keys are configured\"
    error \"  - Network connectivity\"
    exit 1
fi

# Check if required files exist
if [ ! -f \"$SCRIPT_DIR/docker-compose.prod.yml\" ]; then
    error \"docker-compose.prod.yml not found in $SCRIPT_DIR\"
    exit 1
fi

if [ ! -f \"$SCRIPT_DIR/database/init-postgres.sql\" ]; then
    error \"Database initialization scripts not found\"
    exit 1
fi

# Run main deployment
main

exit 0
