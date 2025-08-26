#!/bin/bash

# ==============================================================================
# Check if GitHub Repositories Exist
# ==============================================================================

GITHUB_ORG="rishanimates"
SERVICES=("auth-service" "user-service" "chat-service" "event-service" "shared-service" "splitz-service")

echo "🔍 Checking GitHub repositories..."
echo

for service in "${SERVICES[@]}"; do
    echo -n "Checking $GITHUB_ORG/$service... "
    
    # Check if repository exists using curl
    if curl -s -f -I "https://github.com/$GITHUB_ORG/$service" > /dev/null 2>&1; then
        echo "✅ EXISTS"
    else
        echo "❌ NOT FOUND"
    fi
done

echo
echo "📋 Repository URLs:"
for service in "${SERVICES[@]}"; do
    echo "• https://github.com/$GITHUB_ORG/$service"
done

echo
echo "🔗 SSH Clone URLs:"
for service in "${SERVICES[@]}"; do
    echo "• git@github.com:$GITHUB_ORG/$service.git"
done
