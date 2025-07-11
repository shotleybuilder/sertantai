# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Phoenix/Elixir web application named "Sertantai" that uses the Ash framework for business logic and data modeling. It's a standard Phoenix 1.7+ application with LiveView support.

## Key Dependencies

- **Phoenix 1.7+** - Web framework
- **Ash 3.0+** - Data modeling and business logic framework
- **Ash Phoenix** - Phoenix integration for Ash
- **LiveView** - Real-time UI components
- **Ecto/PostgreSQL** - Database layer
- **Tailwind CSS** - Styling framework
- **ESBuild** - JavaScript bundling

## Common Commands

### Development Setup

#### Using Supabase (Default)
```bash
source .env                 # Load Supabase environment variables
mix setup                   # Full setup: deps, database, assets
mix phx.server              # Start development server
iex -S mix phx.server       # Start server in interactive shell
```

#### Using Local PostgreSQL (Docker Container)
```bash
sertantai-dev                # Recommended: Start PostgreSQL + Phoenix (one command)
# OR manually:
docker-compose up -d postgres # Start PostgreSQL Docker container
source .env.local            # Load local environment variables  
mix ecto.migrate             # Run any pending migrations
mix phx.server               # Start development server
```

**Note**: The local dev database contains 19K+ UK LRT records imported from production.

#### Switch Between Databases
```bash
# To use local database:
export USE_LOCAL_DB=true
source .env.local

# To use Supabase:
unset USE_LOCAL_DB
source .env
```

### Database Operations
```bash
mix ecto.create             # Create database
mix ecto.migrate            # Run migrations
mix ecto.reset              # Drop and recreate database
mix ecto.setup              # Create, migrate, and seed database
```

### Testing
```bash
mix test                    # Run all tests (with database setup)
mix test --only <tag>       # Run specific tagged tests
mix test test/path/file.exs # Run specific test file
```

### Asset Management
```bash
mix assets.setup            # Install Tailwind and ESBuild
mix assets.build            # Build assets for development
mix assets.deploy           # Build and minify assets for production
```

### Asset-specific Commands
```bash
mix tailwind sertantai      # Build Tailwind CSS
mix esbuild sertantai       # Build JavaScript with ESBuild
```

## Architecture

### Application Structure
- **lib/sertantai/** - Core business logic and Ash resources
- **lib/sertantai_web/** - Phoenix web layer (controllers, views, templates)
- **assets/** - Frontend assets (CSS, JS, Tailwind config)
- **config/** - Environment-specific configuration
- **priv/repo/** - Database migrations and seeds
- **test/** - Test files organized by web/core separation

### Key Files
- **lib/sertantai/application.ex** - OTP application startup
- **lib/sertantai_web/router.ex** - Route definitions
- **lib/sertantai_web/endpoint.ex** - Phoenix endpoint configuration
- **mix.exs** - Project dependencies and aliases
- **config/config.exs** - Base configuration with Ash and Spark settings

### Web Layer
- Uses Phoenix pipelines (`:browser`, `:api`)
- LiveDashboard available at `/dev/dashboard` in development
- Swoosh mailbox preview at `/dev/mailbox` in development
- Standard Phoenix directory structure with controllers, views, and templates

### Ash Framework Integration
- Configured with specific Ash policies and defaults
- Includes Ash Phoenix for web integration
- Uses Spark formatter configuration for code formatting
- Configured for keyset pagination by default

## Development Notes

### Database
- Uses PostgreSQL with Ecto
- Configured for UTC timestamps
- Development environment includes automatic database setup in test alias

**⚠️ CRITICAL DATABASE RULES:**
- **LOCAL DEV DATABASE**: Runs in Docker container via `docker-compose.yml` 
- **NEVER DELETE** records from the dev database - contains 19K+ imported UK LRT records
- **NEVER CREATE MIGRATIONS** for tables that already exist in production
- **TO START LOCAL DB**: Use `sertantai-dev` command or `docker-compose up -d postgres`
- **CONNECTION**: `postgresql://postgres:postgres@localhost:5432/sertantai_dev`
- **PRODUCTION DB**: Supabase PostgreSQL (read-only access for data imports only)

**DATA IMPORT PROCESS:**
- **Initial import**: Use `scripts/import_uk_lrt_data.exs` to import data from Supabase production
- **Batch size**: 500 records per batch to avoid timeouts
- **Columns imported**: Only fields defined in `lib/sertantai/uk_lrt.ex` resource
- **Run with**: `source .env && mix run scripts/import_uk_lrt_data.exs`
- **Purpose**: For extending data model - first import base data, then add new columns/tables

### Frontend
- Tailwind CSS configured with custom config file
- ESBuild for JavaScript bundling
- LiveView for interactive components
- Heroicons for UI icons

### Development Tools
- Phoenix Live Reload for development
- Telemetry and metrics configured
- Swoosh for email handling (local adapter in development)
- Bandit as the HTTP adapter
- Using Supabase (for production)
- Using Local Docker PostgreSQL (for development)
- Switch Between Databases
- Using model context protocol (mcp) server tidewave: /home/jason/mcp-proxy http://localhost:4000/tidewave/mcp

<!-- usage-rules-start -->
<!-- usage-rules-header -->
# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below. 
Before attempting to use any of these packages or to discover if you should use them, review their 
usage rules to understand the correct patterns, conventions, and best practices.
<!-- usage-rules-header-end -->

<!-- ash-start -->
## ash usage
_A declarative, extensible framework for building Elixir applications.
_

[ash usage rules](deps/ash/usage-rules.md)
<!-- ash-end -->
<!-- ash_graphql-start -->
## ash_graphql usage
_The extension for building GraphQL APIs with Ash
_

[ash_graphql usage rules](deps/ash_graphql/usage-rules.md)
<!-- ash_graphql-end -->
<!-- ash_json_api-start -->
## ash_json_api usage
_The JSON:API extension for the Ash Framework.
_

[ash_json_api usage rules](deps/ash_json_api/usage-rules.md)
<!-- ash_json_api-end -->
<!-- ash_postgres-start -->
## ash_postgres usage
_The PostgreSQL data layer for Ash Framework
_

[ash_postgres usage rules](deps/ash_postgres/usage-rules.md)
<!-- ash_postgres-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
[usage_rules:elixir usage rules](deps/usage_rules/usage-rules/elixir.md)
<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
[usage_rules:otp usage rules](deps/usage_rules/usage-rules/otp.md)
<!-- usage_rules:otp-end -->
<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework
_

[igniter usage rules](deps/igniter/usage-rules.md)
<!-- igniter-end -->
<!-- ash_phoenix-start -->
## ash_phoenix usage
_Utilities for integrating Ash and Phoenix
_

[ash_phoenix usage rules](deps/ash_phoenix/usage-rules.md)
<!-- ash_phoenix-end -->
<!-- ash_authentication-start -->
## ash_authentication usage
_Authentication extension for the Ash Framework.
_

[ash_authentication usage rules](deps/ash_authentication/usage-rules.md)
<!-- ash_authentication-end -->
<!-- usage-rules-end -->
