#!/bin/bash

# ==============================================================================
# Setup Script for Individual Service Repositories
# Run this script in each service repository
# ==============================================================================

set -e

SERVICE_NAME=$(basename $(pwd))
GITHUB_ORG="rishanimates"
DEPLOYMENT_REPO="auth-service"

echo "Setting up webhook for service: $SERVICE_NAME"

# Create .github/workflows directory
mkdir -p .github/workflows

# Copy the webhook workflow
cp "../deployment/service-webhook-workflows/${SERVICE_NAME}-webhook.yml" ".github/workflows/deploy-on-merge.yml"

echo "✅ Webhook workflow installed for $SERVICE_NAME"
echo "📋 Next steps:"
echo "1. Add DEPLOYMENT_TOKEN secret to this repository"
echo "2. Commit and push the workflow file"
echo "3. Test by merging to develop branch"

