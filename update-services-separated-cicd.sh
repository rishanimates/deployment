#!/bin/bash

# Update all services with separated CI/CD jobs

services=("user-service:3001" "chat-service:3002" "event-service:3003" "shared-service:3004" "splitz-service:3005")

for service_info in "${services[@]}"; do
    IFS=':' read -r service port <<< "$service_info"
    service_dir="../$service"
    
    if [ -d "$service_dir" ]; then
        echo "✅ Updating $service with separated CI/CD workflow..."
        
        # Copy the separated CI/CD workflow from auth-service
        cp ../auth-service/.github/workflows/deploy.yml "$service_dir/.github/workflows/deploy.yml"
        
        # Update service-specific details
        service_title=$(echo $service | sed 's/-/ /g' | sed 's/\b\w/\U&/g')
        
        # Replace service name and port
        sed -i '' "s/Deploy Auth Service/Deploy $service_title/g" "$service_dir/.github/workflows/deploy.yml"
        sed -i '' "s/auth-service/$service/g" "$service_dir/.github/workflows/deploy.yml"
        sed -i '' "s/SERVICE_PORT: 3000/SERVICE_PORT: $port/g" "$service_dir/.github/workflows/deploy.yml"
        
        echo "✅ Updated $service with separated CI/CD (port: $port)"
    else
        echo "❌ Service directory not found: $service_dir"
    fi
done

echo ""
echo "🎉 All services updated with separated CI/CD jobs!"
echo ""
echo "📋 CI/CD Structure:"
echo "1. 🏗️ CI Job (Build):"
echo "   - Checkout code"
echo "   - Set metadata"
echo "   - Build Docker image"
echo "   - Test Docker image"
echo "   - Push to registry"
echo ""
echo "2. 🚀 CD Job (Deploy):"
echo "   - Setup SSH (depends on CI success)"
echo "   - Deploy to VPS"
echo "   - Verify deployment"
echo ""
echo "✅ Benefits:"
echo "- Clear separation of concerns"
echo "- Easy to debug (know if build or deploy failed)"
echo "- CI runs independently"
echo "- CD only runs if CI succeeds"
echo "- Better visibility in GitHub Actions UI"
