#!/bin/bash

# ==============================================================================
# Update All Service Dockerfiles to Node.js 20 and Yarn
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

SERVICES=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")

echo -e "${C_BLUE}===================================================${C_RESET}"
echo -e "${C_BLUE}    Update Dockerfiles to Node.js 20 and Yarn${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

echo -e "\n${C_YELLOW}🐳 Updating Dockerfiles for Node.js 20 compatibility...${C_RESET}"
echo

# Function to update a service Dockerfile
update_dockerfile() {
    local service=$1
    local service_dir="../$service"
    local dockerfile="$service_dir/Dockerfile"
    
    log_info "Updating Dockerfile for $service..."
    
    if [ ! -d "$service_dir" ]; then
        log_warning "Directory $service_dir not found, skipping"
        return 0
    fi
    
    if [ ! -f "$dockerfile" ]; then
        log_warning "No Dockerfile found in $service, creating new one..."
        create_new_dockerfile "$service_dir" "$service"
        return 0
    fi
    
    # Backup original Dockerfile
    cp "$dockerfile" "$dockerfile.backup"
    
    # Update Dockerfile
    log_info "Updating $service Dockerfile..."
    
    # Create updated Dockerfile
    cat > "$dockerfile" << EOF
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY yarn.lock ./

# Install dependencies with yarn
RUN yarn install --frozen-lockfile --production

# Copy source code
COPY . .

# Create logs directory
RUN mkdir -p logs

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \\
    adduser -S appuser -u 1001 -G nodejs

# Change ownership
RUN chown -R appuser:nodejs /app
USER appuser

# Expose port (will be overridden by environment)
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["node", "src/server.js"]
EOF
    
    log_success "✅ Updated Dockerfile for $service"
}

# Function to create new Dockerfile
create_new_dockerfile() {
    local service_dir=$1
    local service=$2
    local dockerfile="$service_dir/Dockerfile"
    
    cat > "$dockerfile" << EOF
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY yarn.lock ./

# Install dependencies with yarn
RUN yarn install --frozen-lockfile --production

# Copy source code
COPY . .

# Create logs directory
RUN mkdir -p logs

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \\
    adduser -S appuser -u 1001 -G nodejs

# Change ownership
RUN chown -R appuser:nodejs /app
USER appuser

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["node", "src/server.js"]
EOF
    
    log_success "✅ Created new Dockerfile for $service"
}

# Update all service Dockerfiles
for service in "${SERVICES[@]}"; do
    update_dockerfile "$service"
    echo
done

echo -e "${C_YELLOW}🔍 Verification - checking updated Dockerfiles...${C_RESET}"
echo

# Verify updates
for service in "${SERVICES[@]}"; do
    service_dir="../$service"
    dockerfile="$service_dir/Dockerfile"
    
    echo -n "Checking $service... "
    
    if [ -f "$dockerfile" ]; then
        if grep -q "FROM node:20-alpine" "$dockerfile" && grep -q "yarn install" "$dockerfile"; then
            log_success "✅ Updated to Node.js 20 + Yarn"
        elif grep -q "FROM node:20-alpine" "$dockerfile"; then
            log_warning "⚠️  Node.js 20 but still using npm"
        else
            log_warning "⚠️  Still using old Node.js version"
        fi
    else
        log_warning "⚠️  No Dockerfile found"
    fi
done

echo -e "\n${C_YELLOW}📝 Dockerfile Changes Made:${C_RESET}"
echo "✅ Updated base image: node:18-alpine → node:20-alpine"
echo "✅ Changed package manager: npm → yarn"
echo "✅ Updated install command: npm ci → yarn install --frozen-lockfile"
echo "✅ Added non-root user for security"
echo "✅ Added health check endpoint"
echo "✅ Added logs directory creation"

echo -e "\n${C_YELLOW}📋 Next Steps - Commit Changes:${C_RESET}"
echo "Run these commands to commit the updated Dockerfiles:"
echo

for service in "${SERVICES[@]}"; do
    service_dir="../$service"
    if [ -f "$service_dir/Dockerfile" ]; then
        cat << EOF
# $service
cd ../$service
git add Dockerfile
git commit -m "Update Dockerfile to Node.js 20 and Yarn

- Upgrade base image from node:18-alpine to node:20-alpine
- Switch from npm to yarn for dependency management
- Add non-root user for improved security
- Add health check endpoint
- Add logs directory creation"
git push origin develop
git push origin main

EOF
    fi
done

echo -e "\n${C_YELLOW}🧪 Testing Updated Dockerfiles:${C_RESET}"
echo "Test locally before pushing:"
echo
for service in "${SERVICES[@]}"; do
    echo "# Test $service"
    echo "cd ../$service"
    echo "docker build -t test-$service ."
    echo "docker run --rm -p 3000:3000 test-$service"
    echo
done

echo -e "\n${C_YELLOW}🔄 Rollback Instructions (if needed):${C_RESET}"
echo "If there are issues, restore from backups:"
echo
for service in "${SERVICES[@]}"; do
    echo "cd ../$service && mv Dockerfile.backup Dockerfile"
done

echo -e "\n${C_GREEN}===================================================${C_RESET}"
echo -e "${C_GREEN}    Dockerfile Updates Complete!${C_RESET}"
echo -e "${C_GREEN}===================================================${C_RESET}"

echo -e "\n${C_GREEN}🎉 All Dockerfiles updated for Node.js 20 and Yarn compatibility!${C_RESET}"
echo -e "${C_YELLOW}📤 Don't forget to commit and push the changes to your repositories.${C_RESET}"
