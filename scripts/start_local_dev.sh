#!/bin/bash

# Start local development environment
echo "Starting local PostgreSQL with Docker..."

# Start Docker Compose
docker-compose up -d postgres

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
sleep 10

# Set environment variables for local development
export USE_LOCAL_DB=true
export DB_USERNAME=postgres
export DB_PASSWORD=postgres
export DB_HOSTNAME=localhost
export DB_NAME=sertantai_dev
export DB_PORT=5432

# Source the existing .env file for other variables
if [ -f .env ]; then
    source .env
fi

echo "Local development environment started!"
echo "Database URL: postgresql://postgres:postgres@localhost:5432/sertantai_dev"
echo ""
echo "To use local database, run:"
echo "export USE_LOCAL_DB=true"
echo "source .env"
echo "mix ecto.create"
echo "mix ecto.migrate"
echo "mix run priv/repo/seeds.exs"
echo "mix phx.server"