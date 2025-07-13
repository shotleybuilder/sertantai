# Sertantai

## Getting Started

### Initial Setup (Run Once)

For first-time setup or clean environment:

```bash
./scripts/setup_dev_complete.sh
```

This sets up PostgreSQL, database, migrations, test data, and everything needed for development.

### Daily Development

#### Quick Start (Recommended)
Add this alias to your shell for one-command startup:

```bash
echo 'sertantai-dev() {
    cd /home/jason/Desktop/sertantai
    
    # Check if PostgreSQL container is running
    if ! docker ps --format "table {{.Names}}" | grep -q "sertantai_postgres"; then
        echo "🐳 Starting PostgreSQL container..."
        docker-compose up -d postgres
        echo "⏳ Waiting for PostgreSQL to be ready..."
        sleep 5
    else
        echo "✅ PostgreSQL container already running"
    fi
    
    # Load environment and start Phoenix
    echo "🚀 Starting Sertantai development server..."
    source .env.local && mix phx.server
}' >> ~/.bashrc

source ~/.bashrc
```

Then from anywhere, just run:
```bash
sertantai-dev
```

#### Manual Start
```bash
docker-compose up -d postgres  # Start PostgreSQL
source .env.local              # Load local environment
mix phx.server                # Start Phoenix server
```

### Database Options

#### Using Local PostgreSQL (Default for Development)
```bash
export USE_LOCAL_DB=true
source .env.local
```

#### Using Supabase (Production)
```bash
unset USE_LOCAL_DB
source .env
```

### Stopping the Development Environment

**Stop Phoenix server:**
```bash
Ctrl+C  # Graceful shutdown (once or twice if needed)
```

**Stop PostgreSQL (optional):**
```bash
docker-compose stop postgres  # Stop but keep data
# OR
docker-compose down           # Stop and remove containers
```

**Recommended daily workflow:**
- **Start:** `sertantai-dev`
- **Restart:** `Ctrl+C` → `sertantai-dev` 
- **End of day:** `Ctrl+C` → `docker-compose down`

### Test Accounts

After setup, you can login with:
- **Admin:** `admin@sertantai.com` / `admin123!`
- **Test User:** `test@sertantai.com` / `test123!`

### Accessing the Application

Visit [`localhost:4000`](http://localhost:4000) from your browser.

## Documentation

📚 **[Complete Documentation](./docs/)** - Comprehensive guides and references

### Quick Links
- **🔧 [Developer Setup](./docs/dev/DEVELOPMENT.md)** - Detailed development environment setup
- **👥 [User Guide](./docs/user/)** - Platform features and usage
- **🏗️ [Architecture](./docs/dev/)** - Technical implementation details
- **🔍 [Troubleshooting](./docs/dev/authentication-troubleshooting.md)** - Common issues and solutions

### For Developers
- [Multi-Location Organizations](./docs/dev/multi-location-organization-plan.md) - Implementation plan
- [Authentication Issues](./docs/dev/authentication-troubleshooting.md) - Common auth problems
- [Persistence Strategy](./docs/dev/persistence/) - Data persistence architecture

### For Users
- [Getting Started](./docs/user/) - Platform overview and basic usage
- [Organization Management](./docs/user/) - Profile and location setup
- [Compliance Screening](./docs/user/) - Regulation discovery and assessment

## Technology Stack

- **Phoenix 1.7+** - Web framework with LiveView
- **Ash Framework 3.0+** - Business logic and data modeling
- **PostgreSQL** - Primary database
- **Tailwind CSS** - Styling framework
- **Docker** - Development environment
