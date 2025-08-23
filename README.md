# LetzGo Local Development Setup

This directory contains the scripts and configuration to set up the complete LetzGo local development environment.

## Prerequisites

- macOS
- [Homebrew](https://brew.sh/) (will be installed automatically if not found)
- [Docker](https://www.docker.com/products/docker-desktop) (will be installed automatically if not found)

## Installation

To set up the local environment, run the `install.sh` script from the root of the project:

```bash
./install/install.sh
```

## What the Script Does

1.  **Checks for Dependencies**: Verifies that Homebrew and Docker are installed. If they are not found, it will attempt to install them.
2.  **Starts Services**: Starts all required databases and messaging services using Docker Compose. This includes:
    - PostgreSQL
    - MongoDB
    - Redis
    - RabbitMQ
3.  **Installs Dependencies**: Runs `npm install` for all microservices.
4.  **Creates Environment Files**: Creates `.env` files for each service with default local development values.

## After Running the Script

After the script completes, you will need to:

1.  **Review `.env` files**: Check the newly created `.env` files in each service directory.
2.  **Add Secrets**: Fill in any missing secrets, such as `JWT_SECRET` and any API keys for external services (e.g., Razorpay, AWS, etc.).

## Starting and Stopping Services

-   **To start all services**:
    ```bash
    docker-compose -f install/docker-compose.yml up -d
    ```
-   **To stop all services**:
    ```bash
    docker-compose -f install/docker-compose.yml down
    ``` 
