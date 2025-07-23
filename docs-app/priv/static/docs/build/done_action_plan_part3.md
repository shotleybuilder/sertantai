# Action Plan Part 3: Authentication UI & Local Development Setup

## Overview
This plan covers building a complete authentication frontend, setting up local PostgreSQL for development, and migrating test data from Supabase.

## Current State Analysis

### Authentication Infrastructure (Already Implemented)
- ✅ **Ash Authentication** configured with password strategy
- ✅ **User resource** with email/password authentication
- ✅ **Token management** with JTI session identifiers
- ✅ **AuthController** with success/failure handlers
- ✅ **Router setup** with protected routes
- ✅ **Database schema** with users and tokens tables

### Missing Components
- ❌ **Authentication UI** (login, register, password reset forms)
- ❌ **User profile management** interface
- ❌ **Local PostgreSQL** setup for development
- ❌ **Data migration** from Supabase to local dev

## Phase 1: Authentication UI Development

### 1.1 Create Authentication LiveView Components
**Priority:** High | **Estimated Time:** 4-6 hours

#### Components to Build:
1. **LoginLive** (`/login`) - User sign-in form
2. **RegisterLive** (`/register`) - User registration form  
3. **ResetPasswordLive** (`/reset-password`) - Password reset request
4. **ProfileLive** (`/profile`) - User profile management
5. **ChangePasswordLive** (`/change-password`) - Password change form

#### Implementation Details:
```elixir
# File: lib/sertantai_web/live/auth_live.ex
defmodule SertantaiWeb.AuthLive do
  use SertantaiWeb, :live_view
  # Login form with email/password validation
  # Integration with AshAuthentication
  # Flash messages for errors/success
  # Redirect handling for protected routes
end
```

#### Templates & Styling:
- Use **Tailwind CSS** for consistent styling
- **Responsive design** for mobile compatibility
- **Accessibility** features (ARIA labels, keyboard navigation)
- **Error handling** with clear user feedback

### 1.2 Update Router Configuration
**Priority:** High | **Estimated Time:** 1 hour

```elixir
# File: lib/sertantai_web/router.ex
scope "/", SertantaiWeb do
  pipe_through :browser
  
  # Replace generated auth routes with custom LiveViews
  live "/login", AuthLive, :login
  live "/register", AuthLive, :register
  live "/reset-password", AuthLive, :reset_password
  live "/profile", AuthLive, :profile
  live "/change-password", AuthLive, :change_password
  
  # Keep existing routes
  get "/", PageController, :home
  sign_out_route AuthController
end
```

### 1.3 Enhanced User Experience Features
**Priority:** Medium | **Estimated Time:** 2-3 hours

- **Remember me** functionality with longer session tokens
- **Email verification** workflow (optional)
- **Social login** preparation (OAuth2 setup)
- **Password strength** indicators
- **Login rate limiting** protection

## Phase 2: Local PostgreSQL Setup

### 2.1 Development Database Configuration
**Priority:** High | **Estimated Time:** 2-3 hours

#### Install PostgreSQL Locally:
```bash
# Ubuntu/Debian
sudo apt-get install postgresql postgresql-contrib

# macOS
brew install postgresql

# Start service
sudo systemctl start postgresql  # Linux
brew services start postgresql   # macOS
```

#### Create Development Database:
```bash
sudo -u postgres createuser --interactive --pwprompt sertantai_dev
sudo -u postgres createdb -O sertantai_dev sertantai_dev
```

### 2.2 Update Development Configuration
**Priority:** High | **Estimated Time:** 1 hour

```elixir
# File: config/dev.exs
config :sertantai, Sertantai.Repo,
  username: "sertantai_dev",
  password: "dev_password",
  hostname: "localhost",
  database: "sertantai_dev",
  port: 5432,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Keep Supabase config commented for quick switching
# config :sertantai, Sertantai.Repo,
#   username: "postgres.laqakhlqqmakacqgwrnh",
#   password: System.get_env("SUPABASE_PASSWORD"),
#   hostname: "aws-0-eu-west-2.pooler.supabase.com",
#   database: System.get_env("SUPABASE_DATABASE") || "postgres",
#   port: 6543,
#   parameters: [pgbouncer: "true"],
#   ssl: true,
#   ssl_opts: [verify: :verify_none]
```

### 2.3 Environment-Specific Configuration
**Priority:** Medium | **Estimated Time:** 1 hour

#### Update .env for Development:
```bash
# File: .env.dev (new file)
DATABASE_URL="postgresql://sertantai_dev:dev_password@localhost:5432/sertantai_dev"
SECRET_KEY_BASE="generated_secret_key"
SUPABASE_HOST="laqakhlqqmakacqgwrnh.supabase.co"
SUPABASE_PASSWORD="N0GdLwQHJplAPGON"
```

#### Production Configuration:
```elixir
# File: config/runtime.exs
if config_env() == :prod do
  # Keep Supabase configuration for production
  config :sertantai, Sertantai.Repo,
    username: "postgres.laqakhlqqmakacqgwrnh",
    password: System.get_env("SUPABASE_PASSWORD"),
    hostname: "aws-0-eu-west-2.pooler.supabase.com",
    database: System.get_env("SUPABASE_DATABASE") || "postgres",
    port: 6543,
    parameters: [pgbouncer: "true"],
    ssl: true,
    ssl_opts: [verify: :verify_none]
end
```

## Phase 3: Data Migration & Test Data Setup

### 3.1 Create Migration Scripts
**Priority:** Medium | **Estimated Time:** 3-4 hours

#### Extract Data from Supabase:
```elixir
# File: priv/repo/data_migration.exs
defmodule DataMigration do
  @moduledoc """
  Script to migrate data from Supabase to local PostgreSQL
  """
  
  def migrate_uk_lrt_data do
    # Connect to Supabase
    supabase_config = [
      username: "postgres.laqakhlqqmakacqgwrnh",
      password: System.get_env("SUPABASE_PASSWORD"),
      hostname: "aws-0-eu-west-2.pooler.supabase.com",
      database: "postgres",
      port: 6543,
      parameters: [pgbouncer: "true"],
      ssl: true,
      ssl_opts: [verify: :verify_none]
    ]
    
    # Extract 1000 records with diverse data
    query = """
    SELECT * FROM uk_lrt 
    WHERE family IS NOT NULL 
    ORDER BY family, created_at 
    LIMIT 1000
    """
    
    # Insert into local database
    # Transform data as needed
    # Handle constraints and relationships
  end
end
```

### 3.2 Test Data Curation
**Priority:** Medium | **Estimated Time:** 2 hours

#### Selection Criteria for 1000 Records:
- **Family diversity**: Include all major family categories
- **Status variety**: Mix of active, revoked, and partially revoked
- **Year range**: Span multiple years (2015-2024)
- **Data completeness**: Prefer records with rich metadata
- **Representative sample**: Ensure typical use cases are covered

#### Data Seeding Script:
```elixir
# File: priv/repo/seeds.exs
# Create test users
users = [
  %{
    email: "admin@sertantai.com",
    password: "admin_password",
    first_name: "Admin",
    last_name: "User",
    timezone: "UTC"
  },
  %{
    email: "test@sertantai.com", 
    password: "test_password",
    first_name: "Test",
    last_name: "User",
    timezone: "Europe/London"
  }
]

# Insert UK LRT test data
# Create sample sync configurations
# Generate realistic selected records
```

### 3.3 Development Data Management
**Priority:** Low | **Estimated Time:** 1 hour

#### Database Reset Script:
```bash
# File: scripts/reset_dev_db.sh
#!/bin/bash
mix ecto.drop
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
echo "Development database reset complete"
```

## Phase 4: Testing & Quality Assurance

### 4.1 Authentication Testing
**Priority:** High | **Estimated Time:** 3-4 hours

#### Test Coverage:
- **Unit tests** for authentication logic
- **Integration tests** for login/logout flows
- **LiveView tests** for UI interactions
- **Security tests** for password handling
- **Session management** tests

#### Test Files:
```elixir
# File: test/sertantai_web/live/auth_live_test.exs
defmodule SertantaiWeb.AuthLiveTest do
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  
  describe "login page" do
    test "renders login form", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/login")
      assert html =~ "Sign In"
      assert html =~ "Email"
      assert html =~ "Password"
    end
    
    test "successful login redirects to dashboard" do
      # Test implementation
    end
    
    test "invalid credentials show error" do
      # Test implementation
    end
  end
end
```

### 4.2 Database Migration Testing
**Priority:** Medium | **Estimated Time:** 2 hours

- **Data integrity** validation
- **Performance** testing with 1000 records
- **Migration rollback** testing
- **Cross-environment** compatibility

### 4.3 User Experience Testing
**Priority:** Medium | **Estimated Time:** 2 hours

- **Accessibility** compliance testing
- **Mobile responsiveness** validation
- **Cross-browser** compatibility
- **Performance** benchmarks

## Phase 5: Documentation & Deployment

### 5.1 Development Documentation
**Priority:** Medium | **Estimated Time:** 2 hours

#### Update CLAUDE.md:
```markdown
## Authentication Development

### Local Development Setup
1. Install PostgreSQL locally
2. Create development database
3. Run migrations and seeds
4. Start server with local database

### Authentication Features
- Login/Logout functionality
- User registration
- Password reset
- Profile management
- Session management

### Testing
- Run authentication tests: `mix test test/sertantai_web/live/auth_live_test.exs`
- Reset development database: `./scripts/reset_dev_db.sh`
```

### 5.2 Environment Configuration Guide
**Priority:** Low | **Estimated Time:** 1 hour

#### README Updates:
- **Local setup** instructions
- **Database configuration** options
- **Environment variables** documentation
- **Testing procedures** guide

## Implementation Timeline

### Week 1: Authentication UI (Days 1-3)
- Day 1: LoginLive and RegisterLive components
- Day 2: ResetPasswordLive and ProfileLive
- Day 3: Router integration and styling

### Week 1: Database Setup (Days 4-5)
- Day 4: PostgreSQL installation and configuration
- Day 5: Data migration script development

### Week 2: Testing & Polish (Days 6-7)
- Day 6: Test suite development and execution
- Day 7: Documentation and final testing

## Success Metrics

### Functionality Metrics:
- ✅ **User registration** working end-to-end
- ✅ **Login/logout** with session management
- ✅ **Password reset** flow functional
- ✅ **Local database** with 1000 test records
- ✅ **All tests passing** with >80% coverage

### User Experience Metrics:
- ✅ **Responsive design** on mobile/desktop
- ✅ **Accessibility** compliance (WCAG 2.1)
- ✅ **Performance** <2s page load times
- ✅ **Error handling** with clear messages

### Development Metrics:
- ✅ **Local development** environment functional
- ✅ **Production deployment** unchanged
- ✅ **Database migrations** reversible
- ✅ **Documentation** complete and accurate

## Risk Mitigation

### Technical Risks:
1. **Data migration complexity** - Mitigate with thorough testing
2. **Authentication security** - Use Ash Authentication best practices
3. **Database performance** - Optimize queries and indexes
4. **Session management** - Implement proper token lifecycle

### Timeline Risks:
1. **Scope creep** - Stick to core authentication features
2. **Technical debt** - Maintain code quality standards
3. **Integration issues** - Test early and often
4. **Documentation lag** - Update docs incrementally

## Future Enhancements

### Phase 4 Considerations:
- **Two-factor authentication** (2FA)
- **Social login** integration
- **Advanced user roles** and permissions
- **Audit logging** for security
- **API authentication** for mobile apps

## Conclusion

This plan provides a comprehensive approach to building a production-ready authentication system while maintaining a clean development environment. The phased approach ensures incremental progress with continuous testing and validation.

**Total Estimated Time:** 15-20 hours
**Priority:** High for authentication UI, Medium for local setup
**Dependencies:** PostgreSQL installation, Ash Authentication knowledge
**Deliverables:** Complete authentication system with local development environment