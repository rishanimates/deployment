#!/bin/bash

# ==============================================================================
# LetzGo Local Development Environment Setup Script
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Colors for logging ---
C_BLUE="\033[0;34m"
C_GREEN="\033[0;32m"
C_RED="\033[0;31m"
C_YELLOW="\033[0;33m"
C_RESET="\033[0m"

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

# --- Check for Dependencies ---
check_dependencies() {
    log_info "Checking for required dependencies..."

    # Check for Homebrew
    if ! command -v brew &> /dev/null; then
        log_warning "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        log_success "Homebrew installed successfully."
    else
        log_success "Homebrew is already installed."
    fi

    # Check for Docker
    if ! command -v docker &> /dev/null; then
        log_warning "Docker not found. Installing Docker..."
        brew install --cask docker
        log_success "Docker installed successfully."
        log_info "Please start the Docker Desktop application and then re-run this script."
        exit 0
    else
        log_success "Docker is already installed."
    fi
}

# --- Start Docker and Services ---
start_services() {
    log_info "Starting Docker services..."

    # Start Docker daemon
    if ! docker info &> /dev/null; then
        log_info "Starting Docker daemon..."
        open --background -a Docker
        while ! docker info &> /dev/null; do
            log_info "Waiting for Docker to start..."
            sleep 5
        done
        log_success "Docker started successfully."
    fi

    # Start database and messaging services from the root install directory
    docker-compose -f install/docker-compose.yml up -d
    log_success "All services started successfully."
}

# --- Install NPM Dependencies ---
install_dependencies() {
    log_info "Installing npm dependencies for all services..."
    
    services=("auth-service" "user-service" "chat-service" "event-service" "splitz-service" "shared-service")
    for service in "${services[@]}"; do
        log_info "Installing dependencies for $service..."
        (cd "$service" && npm install)
    done

    log_success "All npm dependencies installed successfully."
}

# --- Create Environment Files ---
create_env_files() {
    log_info "Creating .env files for all services..."

    # Generate a shared JWT secret and a service API key
    log_info "Generating shared secrets..."
    JWT_SECRET=$(openssl rand -hex 32)
    SERVICE_API_KEY=$(openssl rand -hex 32)
    log_success "Shared secrets generated."

    # --- auth-service ---
    cat > auth-service/.env << EOL
PORT=3000
POSTGRES_URL=postgresql://postgres:postgres123@localhost:5432/letzgo_db?sslmode=disable
PGHOST=localhost
PGPORT=5432
PGUSER=postgres
PGPASSWORD=postgres123
PGDATABASE=letzgo_db
DB_SCHEMA=auth
NODE_ENV=development
JWT_SECRET=${JWT_SECRET}
SERVICE_API_KEY=${SERVICE_API_KEY}
EOL

    # --- user-service ---
    cat > user-service/.env << EOL
PORT=3001
POSTGRES_URL=postgresql://postgres:postgres123@localhost:5432/letzgo_db?sslmode=disable
PGHOST=localhost
PGPORT=5432
PGUSER=postgres
PGPASSWORD=postgres123
PGDATABASE=letzgo_db
DB_SCHEMA=users
NODE_ENV=development
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
JWT_SECRET=${JWT_SECRET}
SERVICE_API_KEY=${SERVICE_API_KEY}
USER_SERVICE_URL=http://localhost:3001
AUTH_SERVICE_URL=http://localhost:3000
CHAT_SERVICE_URL=http://localhost:3002
EVENT_SERVICE_URL=http://localhost:3003
SHARED_SERVICE_URL=http://localhost:3004
SPLITZ_SERVICE_URL=http://localhost:3005
EOL

    # --- chat-service ---
    echo "Creating chat-service/.env..."
    cat > "chat-service/.env" <<EOL
NODE_ENV=development
PORT=3002
MONGO_URI=mongodb://localhost:27017/letzgo-chat
RABBITMQ_URL=amqp://admin:admin123@localhost:5672
USER_SERVICE_URL=http://localhost:3001/v1
JWT_SECRET=${JWT_SECRET}
SERVICE_API_KEY=${SERVICE_API_KEY}
EOL

    # --- event-service ---
    cat > event-service/.env << EOL
NODE_ENV=development
PORT=3003
POSTGRES_URL=postgresql://postgres:postgres123@localhost:5432/letzgo_db?sslmode=disable
DB_HOST=localhost
DB_PORT=5432
DB_NAME=letzgo_db
DB_USER=postgres
DB_PASSWORD=postgres123
DB_SCHEMA=events
JWT_SECRET=${JWT_SECRET}
SERVICE_API_KEY=${SERVICE_API_KEY}
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
EOL

    # --- splitz-service ---
    cat > splitz-service/.env << EOL
NODE_ENV=development
PORT=3005
MONGODB_URI=mongodb://localhost:27017/splitz-service
POSTGRES_URL=postgresql://postgres:postgres123@localhost:5432/letzgo_db?sslmode=disable
DB_SCHEMA=splitz
REDIS_HOST=localhost
REDIS_PORT=6379
JWT_SECRET=${JWT_SECRET}
SERVICE_API_KEY=${SERVICE_API_KEY}
EOL
    
    # --- shared-service ---
    cat > shared-service/.env << EOL
NODE_ENV=development
PORT=3004
STORAGE_PROVIDER=local
POSTGRES_URL=postgresql://postgres:postgres123@localhost:5432/letzgo_db?sslmode=disable
DB_HOST=localhost
DB_PORT=5432
DB_NAME=letzgo_db
DB_USER=postgres
DB_PASSWORD=postgres123
DB_SCHEMA=shared
REDIS_HOST=localhost
REDIS_PORT=6379
SERVICE_API_KEY=${SERVICE_API_KEY}
EOL

    log_success "All .env files created successfully."
    log_warning "Please review the .env files and fill in any missing values (e.g., API keys, secrets)."
}

# --- Verify Database Setup ---
verify_database_setup() {
    log_info "Verifying database setup..."
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    until docker exec letzgo-postgres pg_isready -U postgres; do
        echo "Waiting for PostgreSQL container to start..."
        sleep 2
    done

    # Wait for the unified database to be created by the init script
    log_info "Waiting for the 'letzgo_db' database to be created..."
    until docker exec letzgo-postgres psql -U postgres -d letzgo_db -c 'SELECT 1;' >/dev/null 2>&1; do
        echo "Waiting for database creation..."
        sleep 2
    done

    # Verify extensions
    log_info "Verifying PostgreSQL extensions..."
    docker exec letzgo-postgres psql -U postgres -d letzgo_db -c "\dx" | grep -E "postgis|timescaledb|uuid-ossp" || {
        log_error "Required PostgreSQL extensions not found in letzgo_db. Please check the database initialization."
    }

    # Verify schemas exist
    log_info "Verifying database schemas..."
    docker exec letzgo-postgres psql -U postgres -d letzgo_db -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('auth', 'users', 'events', 'shared', 'chat', 'splitz');" | grep -E "auth|users|events|shared|chat|splitz" || {
        log_error "Required schemas not found in letzgo_db. Check the initialization script."
    }

    # Verify users table exists in users schema
    docker exec letzgo-postgres psql -U postgres -d letzgo_db -c "SELECT 1 FROM pg_tables WHERE schemaname = 'users' AND tablename = 'users';" | grep "1" || {
        log_warning "Users table not found in users schema. This may be normal if schemas are created but tables are not yet initialized."
    }

    log_success "Database setup verified successfully."
}

# --- Main Function ---
main() {
    # Get the directory of the script
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    # Move to the project root directory (one level up from the script's directory)
    cd "$SCRIPT_DIR/.."

    check_dependencies
    start_services
    verify_database_setup
    install_dependencies
    create_env_files
    log_success "LetzGo local development environment setup is complete!"
    
    echo -e "\n${C_YELLOW}--- Service Endpoints ---${C_RESET}"
    echo -e "${C_GREEN}auth-service:   http://localhost:3000${C_RESET}"
    echo -e "${C_GREEN}user-service:   http://localhost:3001${C_RESET}"
    echo -e "${C_GREEN}chat-service:   http://localhost:3002${C_RESET}"
    echo -e "${C_GREEN}event-service:  http://localhost:3003${C_RESET}"
    echo -e "${C_GREEN}shared-service: http://localhost:3004${C_RESET}"
    echo -e "${C_GREEN}splitz-service: http://localhost:3005${C_RESET}"
    echo -e "${C_YELLOW}-----------------------${C_RESET}\n"
}

main 