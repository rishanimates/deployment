#!/bin/bash

# ==============================================================================
# Setup Environment File for LetzGo Deployment
# ==============================================================================

set -e

# --- Colors for logging ---
C_BLUE="\033[0;34m"
C_GREEN="\033[0;32m"
C_RED="\033[0;31m"
C_YELLOW="\033[0;33m"
C_RESET="\033[0m"

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

# VPS connection details
VPS_HOST="103.168.19.241"
VPS_PORT="7576"
VPS_USER="root"
DEPLOY_PATH="/opt/letzgo"

echo -e "${C_BLUE}===================================================${C_RESET}"
echo -e "${C_BLUE}    Setup Environment File on VPS${C_RESET}"
echo -e "${C_BLUE}===================================================${C_RESET}"

# Check if env.template exists
if [ ! -f "env.template" ]; then
    log_error "env.template file not found in current directory"
    log_info "Please run this script from the deployment directory"
    exit 1
fi

log_info "Environment template found. Setting up .env file on VPS..."

# Check if SSH key exists
if [ ! -f ~/.ssh/id_rsa ]; then
    log_error "SSH key not found. Please run setup-ssh.sh first."
    exit 1
fi

# Generate secure random passwords
log_info "Generating secure passwords..."
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
MONGODB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
RABBITMQ_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
JWT_SECRET=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-32)
SERVICE_API_KEY=$(openssl rand -base64 48 | tr -d "=+/" | cut -c1-32)

log_success "✅ Generated secure passwords"

# Create .env file locally with generated values
log_info "Creating .env file with generated values..."

cat > .env << EOF
# ==============================================================================
# LetzGo Staging Environment Configuration
# ==============================================================================
# Generated on $(date)

# --- Environment ---
NODE_ENV=staging

# --- Database Passwords ---
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
MONGODB_PASSWORD=$MONGODB_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD

# --- Application Secrets ---
JWT_SECRET=$JWT_SECRET
SERVICE_API_KEY=$SERVICE_API_KEY

# --- Payment Gateway (Razorpay) ---
# TODO: Replace with actual Razorpay credentials
RAZORPAY_KEY_ID=rzp_test_your_key_id_here
RAZORPAY_KEY_SECRET=your_razorpay_key_secret_here

# --- Storage Configuration ---
STORAGE_PROVIDER=local

# --- AWS S3 Configuration (if needed) ---
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=us-east-1
AWS_S3_BUCKET=

# --- Cloudinary Configuration (if needed) ---
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=

# --- Email Configuration (Optional) ---
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=

# --- SMS Configuration (Optional - Twilio) ---
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_PHONE_NUMBER=

# --- Push Notifications (Optional - Firebase) ---
FIREBASE_PROJECT_ID=
FIREBASE_PRIVATE_KEY=
FIREBASE_CLIENT_EMAIL=

# --- SSL Configuration (Optional) ---
SSL_CERT_PATH=/opt/letzgo/ssl/letzgo.crt
SSL_KEY_PATH=/opt/letzgo/ssl/letzgo.key

# --- Monitoring & Analytics (Optional) ---
SENTRY_DSN=
GOOGLE_ANALYTICS_ID=

# --- Domain Configuration ---
DOMAIN_NAME=103.168.19.241
API_DOMAIN=103.168.19.241

# --- Backup Configuration ---
BACKUP_RETENTION_DAYS=30
BACKUP_S3_BUCKET=

# --- Database Connection URLs (Auto-generated) ---
POSTGRES_URL=postgresql://postgres:$POSTGRES_PASSWORD@letzgo-postgres:5432/letzgo_db
MONGODB_URL=mongodb://admin:$MONGODB_PASSWORD@letzgo-mongodb:27017/letzgo_db?authSource=admin
REDIS_URL=redis://:$REDIS_PASSWORD@letzgo-redis:6379
RABBITMQ_URL=amqp://admin:$RABBITMQ_PASSWORD@letzgo-rabbitmq:5672

# --- Service Ports ---
AUTH_SERVICE_PORT=3000
USER_SERVICE_PORT=3001
CHAT_SERVICE_PORT=3002
EVENT_SERVICE_PORT=3003
SHARED_SERVICE_PORT=3004
SPLITZ_SERVICE_PORT=3005

# --- External Service URLs ---
AUTH_SERVICE_URL=http://letzgo-auth-service:3000
USER_SERVICE_URL=http://letzgo-user-service:3001
CHAT_SERVICE_URL=http://letzgo-chat-service:3002
EVENT_SERVICE_URL=http://letzgo-event-service:3003
SHARED_SERVICE_URL=http://letzgo-shared-service:3004
SPLITZ_SERVICE_URL=http://letzgo-splitz-service:3005
EOF

log_success "✅ Created .env file locally"

# Transfer .env file to VPS
log_info "Transferring .env file to VPS..."

# Connect to VPS and setup environment
ssh -p $VPS_PORT -o StrictHostKeyChecking=no $VPS_USER@$VPS_HOST << EOF
set -e

echo "🔧 Setting up deployment directory..."

# Create deployment directory if it doesn't exist
mkdir -p $DEPLOY_PATH

# Create required subdirectories
mkdir -p $DEPLOY_PATH/logs
mkdir -p $DEPLOY_PATH/uploads
mkdir -p $DEPLOY_PATH/ssl
mkdir -p $DEPLOY_PATH/backups

echo "✅ Deployment directories created"

# Set proper permissions
chown -R root:root $DEPLOY_PATH
chmod 755 $DEPLOY_PATH
chmod 755 $DEPLOY_PATH/logs
chmod 755 $DEPLOY_PATH/uploads
chmod 700 $DEPLOY_PATH/ssl

echo "✅ Directory permissions set"
EOF

# Copy .env file to VPS
scp -P $VPS_PORT -o StrictHostKeyChecking=no .env $VPS_USER@$VPS_HOST:$DEPLOY_PATH/

# Verify .env file on VPS
ssh -p $VPS_PORT -o StrictHostKeyChecking=no $VPS_USER@$VPS_HOST << EOF
set -e

echo "🔍 Verifying .env file on VPS..."

if [ -f "$DEPLOY_PATH/.env" ]; then
    echo "✅ .env file found at $DEPLOY_PATH/.env"
    
    # Show file size and permissions
    ls -la $DEPLOY_PATH/.env
    
    # Set secure permissions
    chmod 600 $DEPLOY_PATH/.env
    echo "✅ Set secure permissions (600) on .env file"
    
    # Show first few lines (without sensitive data)
    echo "📋 .env file content preview:"
    head -n 10 $DEPLOY_PATH/.env | grep -E "^#|^NODE_ENV|^STORAGE_PROVIDER"
    
    echo "✅ Environment file setup complete"
else
    echo "❌ .env file not found on VPS"
    exit 1
fi
EOF

if [ $? -eq 0 ]; then
    log_success "✅ Environment file setup completed successfully!"
    echo ""
    log_info "📋 Generated Configuration:"
    echo "• Postgres Password: $POSTGRES_PASSWORD"
    echo "• MongoDB Password: $MONGODB_PASSWORD"
    echo "• Redis Password: $REDIS_PASSWORD"
    echo "• RabbitMQ Password: $RABBITMQ_PASSWORD"
    echo "• JWT Secret: ${JWT_SECRET:0:8}... (32 chars)"
    echo "• Service API Key: ${SERVICE_API_KEY:0:8}... (32 chars)"
    echo ""
    log_warning "⚠️  IMPORTANT: Save these passwords securely!"
    echo ""
    log_info "📝 Next Steps:"
    echo "1. Update Razorpay credentials in .env file if needed"
    echo "2. Configure email/SMS/push notification settings if needed"
    echo "3. Deploy infrastructure: GitHub Actions → Deploy Infrastructure"
    echo "4. Deploy services: GitHub Actions → Service deployments"
    echo ""
    log_info "🔧 To update .env file later:"
    echo "• Edit the local .env file"
    echo "• Run: scp -P $VPS_PORT .env $VPS_USER@$VPS_HOST:$DEPLOY_PATH/"
    echo ""
    log_success "🎉 Environment setup complete! Ready for deployment."
else
    log_error "❌ Environment file setup failed!"
    exit 1
fi

# Clean up local .env file for security
log_info "🧹 Cleaning up local .env file..."
rm -f .env
log_success "✅ Local .env file removed for security"

echo ""
echo -e "${C_GREEN}===================================================${C_RESET}"
echo -e "${C_GREEN}    Environment Setup Complete!${C_RESET}"
echo -e "${C_GREEN}===================================================${C_RESET}"
