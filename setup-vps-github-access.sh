#!/bin/bash

# Setup VPS GitHub Access
# This script sets up SSH keys on VPS for GitHub repository access

set -e

echo "🔧 Setting up VPS GitHub Access"
echo "==============================="
echo ""

VPS_HOST="103.168.19.241"
VPS_PORT="7576"
VPS_USER="root"
SSH_KEY="~/.ssh/letzgo_deploy_key"

echo "📋 Configuration:"
echo "  VPS Host: $VPS_HOST"
echo "  VPS Port: $VPS_PORT"
echo "  VPS User: $VPS_USER"
echo "  SSH Key: $SSH_KEY"
echo ""

# Test SSH connection first
echo "🔍 Testing SSH connection to VPS..."
if ssh -i $SSH_KEY -p $VPS_PORT -o ConnectTimeout=10 $VPS_USER@$VPS_HOST "echo 'SSH connection successful'" >/dev/null 2>&1; then
    echo "✅ SSH connection to VPS is working"
else
    echo "❌ SSH connection to VPS failed"
    echo "Please ensure VPS_SSH_KEY secret is correctly set in GitHub"
    exit 1
fi
echo ""

# Setup SSH keys on VPS for GitHub access
echo "🔑 Setting up GitHub SSH access on VPS..."

ssh -i $SSH_KEY -p $VPS_PORT $VPS_USER@$VPS_HOST << 'VPS_SETUP'

echo "📁 Setting up SSH directory on VPS..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh

echo "🔑 Generating SSH key for GitHub access..."
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "letzgo-vps-github-access"
    echo "✅ New SSH key generated"
else
    echo "✅ SSH key already exists"
fi

chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

echo "🌐 Adding GitHub to known hosts..."
if ! grep -q "github.com" ~/.ssh/known_hosts 2>/dev/null; then
    ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
    echo "✅ GitHub added to known_hosts"
else
    echo "✅ GitHub already in known_hosts"
fi

echo "⚙️ Configuring Git for SSH..."
git config --global user.name "LetzGo VPS"
git config --global user.email "vps@letzgo.com"
git config --global url."git@github.com:".insteadOf "https://github.com/"

echo ""
echo "🔑 VPS SSH Public Key (Add this to GitHub):"
echo "=========================================="
cat ~/.ssh/id_rsa.pub
echo "=========================================="
echo ""

VPS_SETUP

echo ""
echo "🎯 VPS GitHub Access Setup Complete!"
echo ""
echo "📋 Manual Steps Required:"
echo "========================="
echo ""
echo "1. **Add SSH Key to GitHub Account:**"
echo "   - Copy the SSH public key shown above"
echo "   - Go to: https://github.com/settings/keys"
echo "   - Click 'New SSH key'"
echo "   - Title: 'LetzGo VPS Server'"
echo "   - Paste the public key"
echo "   - Click 'Add SSH key'"
echo ""
echo "2. **Or Add as Deploy Keys (for private repos):**"
echo "   For each repository (auth-service, user-service, etc.):"
echo "   - Go to: https://github.com/rhushirajpatil/REPO_NAME/settings/keys"
echo "   - Click 'Add deploy key'"
echo "   - Title: 'LetzGo VPS Deploy Key'"
echo "   - Paste the same public key"
echo "   - Check 'Allow write access' if needed"
echo "   - Click 'Add key'"
echo ""
echo "🚀 After adding the SSH key to GitHub, try the deployment again!"

