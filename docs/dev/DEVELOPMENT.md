# Development Guide

## Getting Started

### Initial Setup (Run Once)

For first-time setup or clean environment:

```bash
./scripts/setup_dev_complete.sh
```

This comprehensive script will:
- Start PostgreSQL with Docker
- Create and migrate the local database
- Import 1000 test records from Supabase
- Seed with test users and sample data
- Install and build assets
- Run the test suite

### Daily Development Workflow

#### Quick Start (Recommended)

Add this function to your shell for one-command startup:

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

### Database Configuration

#### Environment Variables

The application supports two database configurations:

**Local PostgreSQL (Development):**
```bash
export USE_LOCAL_DB=true
source .env.local
```

**Supabase (Production):**
```bash
unset USE_LOCAL_DB
source .env
```

#### Switching Databases

```bash
# Switch to local development
export USE_LOCAL_DB=true
source .env.local
mix ecto.migrate

# Switch to Supabase
unset USE_LOCAL_DB
source .env
```

### Development Commands

#### Database Operations
```bash
mix ecto.create              # Create database
mix ecto.migrate             # Run migrations
mix ecto.reset               # Drop, create, and migrate
mix run priv/repo/seeds.exs  # Seed with test data
```

#### Asset Management
```bash
mix assets.setup             # Install Tailwind and ESBuild
mix assets.build             # Build assets for development
mix assets.deploy            # Build and minify for production
```

#### Testing
```bash
mix test                     # Run all tests
mix test --only auth         # Run authentication tests
mix test test/sertantai_web/live/auth_live_test.exs  # Run specific test file
```

### Data Management

#### Importing Data from Supabase

```bash
cd priv/repo
elixir data_migration.exs    # Import 1000 diverse records
elixir data_migration.exs stats  # Show import statistics
```

#### Database Statistics

```bash
cd priv/repo
elixir data_migration.exs stats
```

### Test Accounts

After running the setup or seeding, you can login with:

- **Admin User (admin role):**
  - Email: `admin@sertantai.com`
  - Password: `admin123!`
  - Role: `admin` - Full system access, user management, admin interface access

- **Support User (support role):**
  - Email: `demo@sertantai.com`
  - Password: `demo123!`
  - Role: `support` - Customer support access, read-only admin interface

- **Professional User (professional role):**
  - Email: `test@sertantai.com`
  - Password: `test123!`
  - Role: `professional` - Paid subscription features, AI screening, sync tools

- **Member User (member role):**
  - Email: `member@sertantai.com`
  - Password: `member123!`
  - Role: `member` - Basic registered user, limited features, no AI or sync

- **Guest User (guest role):**
  - Email: `guest@sertantai.com`
  - Password: `guest123!`
  - Role: `guest` - Minimal access, pre-registration state

**Note:** If you have issues logging in, run `mix run scripts/fix_user_passwords.exs` to ensure passwords are properly hashed.

#### Role Hierarchy & Permissions

The system implements a 5-tier role hierarchy:

1. **admin** - Full system access, can manage all resources and users
2. **support** - Customer support team, read access to help users, limited admin access
3. **professional** - Paid users with AI features and sync capabilities
4. **member** - Basic registered users with limited features
5. **guest** - Default role for new users before registration

#### Admin Interface Access

- **Admin URL:** http://localhost:4000/admin
- **Access:** Only `admin` and `support` roles can access
- **Professional/Member users:** Will be redirected to dashboard with error message

### Stopping the Development Environment

#### Stop Phoenix Server
```bash
Ctrl+C  # Graceful shutdown (press once or twice if needed)
```

#### Stop PostgreSQL Container
```bash
# Option 1: Stop but keep container
docker-compose stop postgres

# Option 2: Stop and remove containers (data persists)
docker-compose down
```

#### Recommended Daily Workflow

1. **Start development:** `sertantai-dev`
2. **Quick restart:** `Ctrl+C` → `sertantai-dev`
3. **End of day cleanup:** `Ctrl+C` → `docker-compose down`

### Troubleshooting

#### PostgreSQL Connection Issues

```bash
# Check if container is running
docker ps | grep postgres

# Check container logs
docker-compose logs postgres

# Restart container
docker-compose restart postgres
```

#### Database Reset

```bash
# Full reset with fresh data
./scripts/setup_dev_complete.sh

# Quick reset
mix ecto.reset
mix run priv/repo/seeds.exs
```

#### Port Conflicts

If port 4000 is in use:
```bash
# Check what's using the port
lsof -i :4000

# Start on different port
PORT=4001 mix phx.server
```

### Development URLs

- **Application:** http://localhost:4000
- **Login:** http://localhost:4000/login
- **LiveDashboard:** http://localhost:4000/dev/dashboard
- **Mailbox Preview:** http://localhost:4000/dev/mailbox

### Project Structure

```
lib/
├── sertantai/                 # Core business logic
│   ├── accounts/              # User authentication
│   ├── sync/                  # Sync configurations
│   └── uk_lrt.ex             # UK LRT records
├── sertantai_web/            # Web interface
│   ├── live/                 # LiveView components
│   ├── controllers/          # Phoenix controllers
│   └── components/           # Reusable UI components
priv/
├── repo/
│   ├── migrations/           # Database migrations
│   ├── seeds.exs            # Development data
│   └── data_migration.exs   # Supabase import script
test/                        # Test files
scripts/                     # Development scripts
```

### Code Quality

#### Running Tests
```bash
mix test                     # All tests
mix test --coverage          # With coverage report
mix test --only integration  # Integration tests only
```

#### Code Formatting
```bash
mix format                   # Format all Elixir code
mix format --check-formatted # Check if code is formatted
```

#### Static Analysis
```bash
mix credo                    # Code analysis
mix dialyzer                 # Type checking (if configured)
```

### Environment Files

- `.env` - Supabase configuration (production)
- `.env.local` - Local development configuration
- `docker-compose.yml` - Local PostgreSQL setup
- `config/dev.exs` - Development configuration
- `config/prod.exs` - Production configuration

### Getting Help

- Check `CLAUDE.md` for Phoenix and Ash framework specifics
- Review test files for usage examples
- Use `iex -S mix phx.server` for interactive development
- Check Phoenix and Ash documentation for advanced features