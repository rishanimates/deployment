#!/bin/bash
set -e

# Create the unified LetzGo database
echo "Creating unified database: letzgo_db"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE letzgo_db'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'letzgo_db')\gexec
EOSQL

# Create schemas within the unified database
echo "Creating schemas in letzgo_db database..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="letzgo_db" <<-EOSQL
    CREATE SCHEMA IF NOT EXISTS auth;
    CREATE SCHEMA IF NOT EXISTS users;
    CREATE SCHEMA IF NOT EXISTS events;
    CREATE SCHEMA IF NOT EXISTS shared;
    CREATE SCHEMA IF NOT EXISTS chat;
    CREATE SCHEMA IF NOT EXISTS splitz;
    
    -- Grant permissions on schemas
    GRANT ALL ON SCHEMA auth TO $POSTGRES_USER;
    GRANT ALL ON SCHEMA users TO $POSTGRES_USER;
    GRANT ALL ON SCHEMA events TO $POSTGRES_USER;
    GRANT ALL ON SCHEMA shared TO $POSTGRES_USER;
    GRANT ALL ON SCHEMA chat TO $POSTGRES_USER;
    GRANT ALL ON SCHEMA splitz TO $POSTGRES_USER;
EOSQL

# Create extensions in the unified database
echo "Creating extensions in letzgo_db database..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="letzgo_db" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE EXTENSION IF NOT EXISTS "postgis";
    CREATE EXTENSION IF NOT EXISTS "timescaledb";
EOSQL

# Execute schema files for the unified database with schema-specific setup
echo "Applying user-service schema to users schema in letzgo_db..."
if [ -f "/docker-entrypoint-initdb.d/01-user-schema.sql" ]; then
    # Set search_path to users schema and apply schema
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="letzgo_db" -c "SET search_path TO users;" -f "/docker-entrypoint-initdb.d/01-user-schema.sql"
fi

echo "Applying user-service stories schema to users schema in letzgo_db..."
if [ -f "/docker-entrypoint-initdb.d/01b-user-stories.sql" ]; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="letzgo_db" -c "SET search_path TO users;" -f "/docker-entrypoint-initdb.d/01b-user-stories.sql"
fi

echo "Applying event-service schema to events schema in letzgo_db..."
if [ -f "/docker-entrypoint-initdb.d/02-event-schema.sql" ]; then
    # Set search_path to events schema and apply schema
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="letzgo_db" -c "SET search_path TO events;" -f "/docker-entrypoint-initdb.d/02-event-schema.sql"
fi

echo "Creating hypertables in unified database..."
if [ -f "/docker-entrypoint-initdb.d/03-create-hypertable.sql" ]; then
    # Execute hypertable creation against unified database with proper schema paths
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="letzgo_db" -c "SET search_path TO users;" -f "/docker-entrypoint-initdb.d/03-create-hypertable.sql" || true
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname="letzgo_db" -c "SET search_path TO events;" -f "/docker-entrypoint-initdb.d/03-create-hypertable.sql" || true
fi

echo "Database initialization complete."
