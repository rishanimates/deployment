#!/bin/bash

# Verify Script Paths for GitHub Actions
# This script verifies that all deployment scripts exist at the expected paths

echo "🔍 Verifying deployment script paths..."

# Check from deployment directory perspective (current location)
echo ""
echo "📁 From deployment/ directory:"
echo "Current directory: $(pwd)"

if [ -f "scripts/deploy-infrastructure-via-actions.sh" ]; then
    echo "✅ scripts/deploy-infrastructure-via-actions.sh exists"
else
    echo "❌ scripts/deploy-infrastructure-via-actions.sh NOT FOUND"
fi

if [ -f "scripts/deploy-service-with-fixes.sh" ]; then
    echo "✅ scripts/deploy-service-with-fixes.sh exists"
else
    echo "❌ scripts/deploy-service-with-fixes.sh NOT FOUND"
fi

if [ -f "scripts/diagnose-and-fix-service-health.sh" ]; then
    echo "✅ scripts/diagnose-and-fix-service-health.sh exists"
else
    echo "❌ scripts/diagnose-and-fix-service-health.sh NOT FOUND"
fi

# Check from repository root perspective (GitHub Actions working directory)
echo ""
echo "📁 From repository root perspective:"
cd ..
echo "Current directory: $(pwd)"

if [ -f "deployment/scripts/deploy-infrastructure-via-actions.sh" ]; then
    echo "✅ deployment/scripts/deploy-infrastructure-via-actions.sh exists"
else
    echo "❌ deployment/scripts/deploy-infrastructure-via-actions.sh NOT FOUND"
fi

if [ -f "deployment/scripts/deploy-service-with-fixes.sh" ]; then
    echo "✅ deployment/scripts/deploy-service-with-fixes.sh exists"
else
    echo "❌ deployment/scripts/deploy-service-with-fixes.sh NOT FOUND"
fi

if [ -f "deployment/scripts/diagnose-and-fix-service-health.sh" ]; then
    echo "✅ deployment/scripts/diagnose-and-fix-service-health.sh exists"
else
    echo "❌ deployment/scripts/diagnose-and-fix-service-health.sh NOT FOUND"
fi

echo ""
echo "📊 File sizes:"
ls -lh deployment/scripts/*.sh 2>/dev/null || echo "No scripts found"

echo ""
echo "🎯 GitHub Actions should use paths like: deployment/scripts/script-name.sh"
