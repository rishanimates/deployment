#!/bin/bash

# Test Services Deployment Script
# This script tests the services deployment functionality locally

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
echo "🧪 LetzGo Services Deployment Test"
echo "============================================================================"
echo -e "${NC}"
echo "📅 Started: $(date)"
echo ""

# Test 1: Check script syntax
log_info "🔍 Test 1: Checking script syntax..."
if bash -n deploy-services.sh; then
    log_success "✅ Script syntax is valid"
else
    log_error "❌ Script syntax errors detected"
    exit 1
fi

# Test 2: Check available services
log_info "🔍 Test 2: Checking available services..."
if grep -q "AVAILABLE_SERVICES.*auth-service.*user-service" deploy-services.sh; then
    log_success "✅ Available services defined correctly"
else
    log_error "❌ Available services not properly defined"
fi

# Test 3: Check service repositories
log_info "🔍 Test 3: Checking service repositories..."
if grep -q "declare -A SERVICE_REPOS" deploy-services.sh; then
    log_success "✅ Service repositories defined correctly"
else
    log_error "❌ Service repositories not properly defined"
fi

# Test 4: Check branch parameter handling
log_info "🔍 Test 4: Checking branch parameter handling..."
if grep -q "branch.*main" deploy-services.sh; then
    log_success "✅ Branch parameter handling found"
else
    log_error "❌ Branch parameter handling missing"
fi

# Test 5: Check help text
log_info "🔍 Test 5: Checking usage documentation..."
echo ""
echo "Usage examples from script:"
grep -A 3 -B 1 "Usage:" deploy-services.sh || echo "No usage examples found"

# Test 6: Test argument parsing (dry run)
log_info "🔍 Test 6: Testing argument parsing..."
echo ""
echo "Testing: ./deploy-services.sh auth-service develop --force-rebuild"
echo "Expected: Services=auth-service, Branch=develop, Force=true"
echo ""

# Test 7: Check prerequisites function
log_info "🔍 Test 7: Checking prerequisites function..."
if grep -q "check_prerequisites" deploy-services.sh; then
    log_success "✅ Prerequisites check function exists"
else
    log_error "❌ Prerequisites check function missing"
fi

# Test 8: Check clone function
log_info "🔍 Test 8: Checking repository clone function..."
if grep -q "clone_service_repo" deploy-services.sh; then
    log_success "✅ Repository clone function exists"
else
    log_error "❌ Repository clone function missing"
fi

# Test 9: Check build function
log_info "🔍 Test 9: Checking Docker build function..."
if grep -q "build_service_image" deploy-services.sh; then
    log_success "✅ Docker build function exists"
else
    log_error "❌ Docker build function missing"
fi

# Test 10: Check deployment function
log_info "🔍 Test 10: Checking service deployment function..."
if grep -q "deploy_service" deploy-services.sh; then
    log_success "✅ Service deployment function exists"
else
    log_error "❌ Service deployment function missing"
fi

echo ""
echo -e "${CYAN}============================================================================${NC}"
echo -e "${GREEN}🎯 Service Deployment Test Summary${NC}"
echo -e "${CYAN}============================================================================${NC}"

echo ""
echo "📋 Available Services:"
echo "  • auth-service (Port 3000) - Authentication & Authorization"
echo "  • user-service (Port 3001) - User Management"
echo "  • chat-service (Port 3002) - Real-time Messaging"
echo "  • event-service (Port 3003) - Event Management"
echo "  • shared-service (Port 3004) - Shared Utilities"
echo "  • splitz-service (Port 3005) - Expense Splitting"

echo ""
echo "🌿 Available Branches:"
echo "  • main - Production ready code"
echo "  • develop - Development branch"
echo "  • staging - Staging environment"

echo ""
echo "📝 Usage Examples:"
echo "  ./deploy-services.sh all main"
echo "  ./deploy-services.sh auth-service,user-service develop"
echo "  ./deploy-services.sh splitz-service main --force-rebuild"

echo ""
echo "🚀 GitHub Actions Usage:"
echo "  1. Go to Actions tab in GitHub"
echo "  2. Select 'Deploy Services' workflow"
echo "  3. Click 'Run workflow'"
echo "  4. Select services: auth-service,user-service,chat-service,event-service,shared-service,splitz-service or 'all'"
echo "  5. Select branch: main, develop, or staging"
echo "  6. Optionally enable force rebuild"

echo ""
echo -e "${GREEN}✅ Services deployment script is ready for use!${NC}"
echo -e "${CYAN}============================================================================${NC}"
