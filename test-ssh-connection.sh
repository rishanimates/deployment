#!/bin/bash

# ==============================================================================
# Test SSH Connection to VPS
# ==============================================================================

set -e

# --- Colors for logging ---
C_BLUE="\033[0;34m"
C_GREEN="\033[0;32m"
C_RED="\033[0;31m"
C_YELLOW="\033[0;33m"
C_RESET="\033[0m"

# --- VPS Configuration ---
VPS_IP="103.168.19.241"
SSH_PORT="7576"
SSH_USER="root"

# --- Helper Functions ---
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

# --- Test SSH Connection ---
test_ssh_connection() {
    log_info "Testing SSH connection to VPS..."
    
    echo -e "${C_YELLOW}VPS Details:${C_RESET}"
    echo "IP: $VPS_IP"
    echo "Port: $SSH_PORT"
    echo "User: $SSH_USER"
    echo
    
    # Test basic connectivity
    log_info "Testing basic connectivity..."
    if nc -z -w5 $VPS_IP $SSH_PORT 2>/dev/null; then
        log_success "VPS is reachable on port $SSH_PORT"
    else
        log_error "Cannot reach VPS on port $SSH_PORT"
        log_info "Please check:"
        echo "  1. VPS is running"
        echo "  2. SSH service is running"
        echo "  3. Port $SSH_PORT is open"
        echo "  4. Firewall allows connections"
        return 1
    fi
    
    # Test SSH connection with password
    log_info "Testing SSH connection (you'll be prompted for password)..."
    if ssh -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SSH_USER@$VPS_IP "echo 'SSH connection successful!'" 2>/dev/null; then
        log_success "SSH connection with password works!"
    else
        log_warning "SSH connection with password failed or requires setup"
        log_info "This is normal if you haven't set up password authentication"
    fi
    
    # Test SSH key connection if key exists
    SSH_KEY_PATH="$HOME/.ssh/letzgo_deploy_key"
    if [ -f "$SSH_KEY_PATH" ]; then
        log_info "Testing SSH key connection..."
        if ssh -i "$SSH_KEY_PATH" -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SSH_USER@$VPS_IP "echo 'SSH key connection successful!'" 2>/dev/null; then
            log_success "SSH key connection works!"
            
            # Show the private key for GitHub secrets
            echo
            log_info "SSH Private Key for GitHub Secrets:"
            echo -e "${C_YELLOW}Copy this entire key (including BEGIN/END lines) to GitHub secret VPS_SSH_KEY:${C_RESET}"
            echo "----------------------------------------"
            cat "$SSH_KEY_PATH"
            echo "----------------------------------------"
            
        else
            log_warning "SSH key connection failed"
            log_info "Key exists but connection failed. Check:"
            echo "  1. Public key is installed on VPS"
            echo "  2. VPS allows key authentication"
            echo "  3. Key permissions are correct"
        fi
    else
        log_warning "No SSH key found at $SSH_KEY_PATH"
        log_info "Run ./setup-ssh.sh to generate and install SSH keys"
    fi
}

# --- Show GitHub Secrets ---
show_github_secrets() {
    echo
    log_info "GitHub Repository Secrets to Add:"
    echo -e "${C_YELLOW}Go to: GitHub Repository → Settings → Secrets and variables → Actions${C_RESET}"
    echo
    echo -e "${C_GREEN}VPS_HOST:${C_RESET} $VPS_IP"
    echo -e "${C_GREEN}VPS_PORT:${C_RESET} $SSH_PORT"
    echo -e "${C_GREEN}VPS_USER:${C_RESET} $SSH_USER"
    echo -e "${C_GREEN}VPS_SSH_KEY:${C_RESET} <copy the private key shown above>"
    echo
}

# --- Main Function ---
main() {
    echo -e "${C_BLUE}===================================================${C_RESET}"
    echo -e "${C_BLUE}    LetzGo VPS SSH Connection Test${C_RESET}"
    echo -e "${C_BLUE}===================================================${C_RESET}"
    echo
    
    # Check if nc (netcat) is available
    if ! command -v nc &> /dev/null; then
        log_warning "netcat (nc) not found - skipping connectivity test"
    fi
    
    test_ssh_connection
    show_github_secrets
    
    echo
    log_info "Next Steps:"
    echo "1. If SSH key connection works, copy the private key to GitHub secrets"
    echo "2. If SSH connection fails, run ./setup-ssh.sh first"
    echo "3. Add all 4 secrets to GitHub repository"
    echo "4. Test deployment by pushing to main branch"
}

# Execute main function
main "$@"
