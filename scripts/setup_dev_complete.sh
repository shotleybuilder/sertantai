#!/bin/bash

# Complete development setup script
set -e

echo "🚀 Setting up complete development environment for Sertantai..."

# Check if Docker is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose not found. Please install Docker and Docker Compose."
    exit 1
fi

# Start PostgreSQL with Docker
echo "📦 Starting PostgreSQL with Docker..."
docker-compose up -d postgres

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 10

# Source environment variables
echo "🔧 Setting up environment variables..."
export USE_LOCAL_DB=true
export DB_USERNAME=postgres
export DB_PASSWORD=postgres
export DB_HOSTNAME=localhost
export DB_NAME=sertantai_dev
export DB_PORT=5432

# Source the existing .env file for other variables
if [ -f .env ]; then
    echo "📄 Loading existing .env file..."
    source .env
fi

# Create and migrate database
echo "🗄️ Creating and migrating database..."
mix ecto.create
mix ecto.migrate

# Run data migration from Supabase (if SUPABASE_PASSWORD is set)
if [ -n "$SUPABASE_PASSWORD" ]; then
    echo "📊 Migrating data from Supabase..."
    cd priv/repo
    elixir data_migration.exs
    cd ../..
else
    echo "⚠️ SUPABASE_PASSWORD not set, skipping data migration"
fi

# Seed the database with test data
echo "🌱 Seeding database with test data..."
mix run priv/repo/seeds.exs

# Show database statistics
echo "📈 Database statistics:"
cd priv/repo
elixir data_migration.exs stats
cd ../..

# Compile assets
echo "🎨 Compiling assets..."
mix assets.setup
mix assets.build

# Run tests
echo "🧪 Running tests..."
mix test

# Show completion message
echo ""
echo "✅ Development environment setup complete!"
echo ""
echo "🎯 Next steps:"
echo "1. Start the server: mix phx.server"
echo "2. Open browser: http://localhost:4000"
echo "3. Login with:"
echo "   - Email: admin@sertantai.com"
echo "   - Password: admin123!"
echo ""
echo "🔄 To switch between databases:"
echo "   - Use local: export USE_LOCAL_DB=true && source .env.local"
echo "   - Use Supabase: unset USE_LOCAL_DB && source .env"
echo ""
echo "🐳 To stop local PostgreSQL:"
echo "   docker-compose down"