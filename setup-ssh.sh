#!/bin/bash

# ==============================================================================
# SSH Key Setup Script for LetzGo VPS Deployment
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
    exit 1
}

# --- Generate SSH Key ---
generate_ssh_key() {
    log_info "Generating SSH key for GitHub Actions..."
    
    # Create .ssh directory if it doesn't exist
    mkdir -p ~/.ssh
    
    # Generate SSH key
    SSH_KEY_PATH="$HOME/.ssh/letzgo_deploy_key"
    
    if [ -f "$SSH_KEY_PATH" ]; then
        log_warning "SSH key already exists at $SSH_KEY_PATH"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Using existing SSH key..."
            return 0
        fi
    fi
    
    # Generate new SSH key
    ssh-keygen -t ed25519 -C "letzgo-github-actions" -f "$SSH_KEY_PATH" -N ""
    
    log_success "SSH key generated successfully!"
    log_info "Public key location: ${SSH_KEY_PATH}.pub"
    log_info "Private key location: $SSH_KEY_PATH"
}

# --- Install SSH Key on VPS ---
install_ssh_key_on_vps() {
    log_info "Installing SSH key on VPS..."
    
    SSH_KEY_PATH="$HOME/.ssh/letzgo_deploy_key"
    
    if [ ! -f "${SSH_KEY_PATH}.pub" ]; then
        log_error "SSH public key not found at ${SSH_KEY_PATH}.pub"
    fi
    
    # Read the public key
    PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")
    
    log_info "Connecting to VPS at $VPS_IP:$SSH_PORT..."
    log_warning "You will be prompted for the root password to install the SSH key."
    
    # Install the SSH key on the VPS
    ssh -p $SSH_PORT $SSH_USER@$VPS_IP "
        # Create .ssh directory if it doesn't exist
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        
        # Add the public key to authorized_keys
        echo '$PUBLIC_KEY' >> ~/.ssh/authorized_keys
        
        # Set proper permissions
        chmod 600 ~/.ssh/authorized_keys
        
        # Ensure SSH service is configured properly
        if ! grep -q 'PubkeyAuthentication yes' /etc/ssh/sshd_config; then
            echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config
            systemctl reload sshd
        fi
        
        echo 'SSH key installed successfully!'
    "
    
    log_success "SSH key installed on VPS!"
}

# --- Test SSH Connection ---
test_ssh_connection() {
    log_info "Testing SSH connection..."
    
    SSH_KEY_PATH="$HOME/.ssh/letzgo_deploy_key"
    
    # Test the connection
    if ssh -i "$SSH_KEY_PATH" -p $SSH_PORT -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SSH_USER@$VPS_IP "echo 'SSH connection successful!'" > /dev/null 2>&1; then
        log_success "SSH connection test passed!"
        return 0
    else
        log_error "SSH connection test failed!"
        return 1
    fi
}

# --- Setup VPS Environment ---
setup_vps_environment() {
    log_info "Setting up VPS environment..."
    
    SSH_KEY_PATH="$HOME/.ssh/letzgo_deploy_key"
    
    ssh -i "$SSH_KEY_PATH" -p $SSH_PORT $SSH_USER@$VPS_IP "
        # Update system
        apt-get update -y
        
        # Install required packages
        apt-get install -y curl git unzip
        
        # Install Docker if not present
        if ! command -v docker &> /dev/null; then
            echo 'Installing Docker...'
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            systemctl enable docker
            systemctl start docker
        fi
        
        # Install Docker Compose if not present
        if ! command -v docker-compose &> /dev/null; then
            echo 'Installing Docker Compose...'
            curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
        fi
        
        # Create deployment directory
        mkdir -p /opt/letzgo
        chown root:root /opt/letzgo
        
        # Create logs directory
        mkdir -p /opt/letzgo/logs
        
        # Create environment files directory
        mkdir -p /opt/letzgo/config
        
        echo 'VPS environment setup completed!'
    "
    
    log_success "VPS environment setup completed!"
}

# --- Display GitHub Secrets ---
display_github_secrets() {
    log_info "Setting up GitHub Secrets..."
    
    SSH_KEY_PATH="$HOME/.ssh/letzgo_deploy_key"
    
    echo -e "\n${C_YELLOW}=== GitHub Repository Secrets ===${C_RESET}"
    echo -e "${C_YELLOW}Add these secrets to your GitHub repository settings:${C_RESET}\n"
    
    echo -e "${C_GREEN}VPS_HOST:${C_RESET} $VPS_IP"
    echo -e "${C_GREEN}VPS_PORT:${C_RESET} $SSH_PORT"
    echo -e "${C_GREEN}VPS_USER:${C_RESET} $SSH_USER"
    echo
    echo -e "${C_GREEN}VPS_SSH_KEY:${C_RESET}"
    echo "$(cat $SSH_KEY_PATH)"
    echo
    
    echo -e "${C_YELLOW}=== Instructions ===${C_RESET}"
    echo "1. Go to your GitHub repository"
    echo "2. Navigate to Settings > Secrets and variables > Actions"
    echo "3. Add the above secrets as Repository secrets"
    echo "4. The GitHub Actions workflow will use these secrets for deployment"
    echo
}

# --- Main Function ---
main() {
    echo -e "${C_BLUE}===================================================${C_RESET}"
    echo -e "${C_BLUE}    LetzGo VPS SSH Setup Script${C_RESET}"
    echo -e "${C_BLUE}===================================================${C_RESET}"
    echo
    echo -e "VPS IP: ${C_GREEN}$VPS_IP${C_RESET}"
    echo -e "SSH Port: ${C_GREEN}$SSH_PORT${C_RESET}"
    echo -e "SSH User: ${C_GREEN}$SSH_USER${C_RESET}"
    echo
    
    # Confirm before proceeding
    read -p "Do you want to proceed with SSH key setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled."
        exit 0
    fi
    
    # Execute setup steps
    generate_ssh_key
    install_ssh_key_on_vps
    test_ssh_connection
    setup_vps_environment
    display_github_secrets
    
    log_success "SSH setup completed successfully!"
    echo
    echo -e "${C_YELLOW}Next Steps:${C_RESET}"
    echo "1. Add the GitHub secrets shown above to your repository"
    echo "2. Push your code to trigger the GitHub Actions deployment"
    echo "3. Monitor the deployment in the Actions tab of your repository"
}

# Execute main function
main
