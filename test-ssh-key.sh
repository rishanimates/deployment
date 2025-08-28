#!/bin/bash

# Test SSH Key Configuration Script
# This script helps verify that your SSH key is properly configured

echo "🔧 SSH Key Configuration Test"
echo "=============================="
echo ""

# Check if we can connect to the VPS
VPS_HOST="103.168.19.241"
VPS_PORT="7576"
VPS_USER="root"

echo "🔍 Testing SSH connection to VPS..."
echo "Host: $VPS_HOST"
echo "Port: $VPS_PORT"
echo "User: $VPS_USER"
echo ""

# Test basic connectivity
echo "1️⃣ Testing port connectivity..."
if nc -zv $VPS_HOST $VPS_PORT 2>/dev/null; then
    echo "✅ Port $VPS_PORT is accessible"
else
    echo "❌ Port $VPS_PORT is not accessible"
    echo "   Please check firewall settings"
    exit 1
fi

echo ""

# Test SSH connection (will prompt for password if key auth fails)
echo "2️⃣ Testing SSH connection..."
echo "   (If this prompts for password, your SSH key is not properly configured)"
echo ""

ssh -p $VPS_PORT -o ConnectTimeout=10 -o BatchMode=yes $VPS_USER@$VPS_HOST "echo 'SSH key authentication successful!'" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ SSH key authentication successful!"
    echo ""
    
    # Test infrastructure deployment requirements
    echo "3️⃣ Testing deployment requirements..."
    ssh -p $VPS_PORT $VPS_USER@$VPS_HOST "
        echo 'Checking Docker...'
        if command -v docker >/dev/null 2>&1; then
            echo '✅ Docker is installed'
            docker --version
        else
            echo '❌ Docker is not installed'
        fi
        
        echo ''
        echo 'Checking Docker Compose...'
        if command -v docker-compose >/dev/null 2>&1; then
            echo '✅ Docker Compose is installed'
            docker-compose --version
        else
            echo '❌ Docker Compose is not installed'
        fi
        
        echo ''
        echo 'Checking /opt/letzgo directory...'
        if [ -d '/opt/letzgo' ]; then
            echo '✅ /opt/letzgo directory exists'
            ls -la /opt/letzgo/
        else
            echo '⚠️  /opt/letzgo directory does not exist (will be created during deployment)'
        fi
        
        echo ''
        echo 'Checking for .env.staging file...'
        if [ -f '/opt/letzgo/.env.staging' ]; then
            echo '✅ .env.staging file exists'
        else
            echo '⚠️  .env.staging file does not exist (will be created during infrastructure deployment)'
        fi
    "
    
else
    echo "❌ SSH key authentication failed!"
    echo ""
    echo "🔧 To fix this issue:"
    echo "1. Generate a new SSH key pair:"
    echo "   ssh-keygen -t rsa -b 4096 -f ~/.ssh/letzgo_deploy_key -N \"\""
    echo ""
    echo "2. Copy the public key to the VPS:"
    echo "   ssh-copy-id -i ~/.ssh/letzgo_deploy_key.pub -p $VPS_PORT $VPS_USER@$VPS_HOST"
    echo ""
    echo "3. Display the private key for GitHub Secrets:"
    echo "   cat ~/.ssh/letzgo_deploy_key"
    echo ""
    echo "4. Add the complete private key to GitHub Secrets as VPS_SSH_KEY"
    echo ""
fi

echo ""
echo "🎯 Summary:"
echo "- If SSH key authentication works, your GitHub workflows should work"
echo "- If it fails, follow the steps above to generate and configure a new SSH key"
echo "- Make sure the complete private key (including headers/footers) is in GitHub Secrets"
