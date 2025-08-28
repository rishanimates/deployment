#!/bin/bash

# Update all service repositories with proper CI/CD deployment

services=("user-service:3001" "chat-service:3002" "event-service:3003" "shared-service:3004" "splitz-service:3005")

for service_info in "${services[@]}"; do
    IFS=':' read -r service port <<< "$service_info"
    service_dir="../$service"
    
    if [ -d "$service_dir" ]; then
        echo "✅ Updating $service with proper CI/CD workflow..."
        
        # Copy the workflow from auth-service
        cp ../auth-service/.github/workflows/deploy.yml "$service_dir/.github/workflows/deploy.yml"
        
        # Update service-specific details
        service_title=$(echo $service | sed 's/-/ /g' | sed 's/\b\w/\U&/g')
        
        # Replace service name and port
        sed -i '' "s/Deploy Auth Service/Deploy $service_title/g" "$service_dir/.github/workflows/deploy.yml"
        sed -i '' "s/auth-service/$service/g" "$service_dir/.github/workflows/deploy.yml"
        sed -i '' "s/SERVICE_PORT: 3000/SERVICE_PORT: $port/g" "$service_dir/.github/workflows/deploy.yml"
        
        # Copy Dockerfile from auth-service
        cp ../auth-service/Dockerfile "$service_dir/Dockerfile"
        
        echo "✅ Updated $service with proper CI/CD (port: $port)"
    else
        echo "❌ Service directory not found: $service_dir"
    fi
done

echo ""
echo "🎉 All services updated with proper CI/CD workflow!"
