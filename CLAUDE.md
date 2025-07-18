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

## ⚠️ CRITICAL ASH FRAMEWORK RULES

**🚫 NEVER USE STANDARD ECTO/PHOENIX PATTERNS - ALWAYS USE ASH PATTERNS**

### Database Operations
- **NEVER**: `Ecto.Changeset.cast/3`, `Repo.insert/1`, `Repo.update/1`, `Repo.get/2`
- **ALWAYS**: `Ash.create/2`, `Ash.update/2`, `Ash.read/2`, `Ash.get/2`, `Ash.destroy/2`

### Forms and Changesets
- **NEVER**: `Ecto.Changeset.change/2`, `Phoenix.HTML.Form` with Ecto changesets
- **ALWAYS**: `AshPhoenix.Form.for_create/3`, `AshPhoenix.Form.for_update/3`, `AshPhoenix.Form.validate/2`, `AshPhoenix.Form.submit/2`

### Data Queries
- **NEVER**: `from(u in User, where: u.role == :admin) |> Repo.all()`
- **ALWAYS**: `Ash.read(User, actor: current_user)` with Ash queries and filters

### Resource Actions
- **NEVER**: Define custom functions that bypass Ash actions
- **ALWAYS**: Use defined Ash actions like `:register_with_password`, `:update_role`, etc.

### Authentication Integration
- **NEVER**: Custom authentication logic bypassing Ash policies
- **ALWAYS**: Use `actor: current_user` parameter in all Ash calls for policy enforcement

### Error Handling
- **NEVER**: `{:error, %Ecto.Changeset{}}` pattern matching
- **ALWAYS**: `{:error, %Ash.Error{}}` and `AshPhoenix.Form` error handling

### Pre-Development Checklist
**Before writing ANY code that interacts with data:**
1. ✅ Check existing Ash resource definitions in `lib/sertantai/`
2. ✅ Identify available Ash actions (`:create`, `:read`, `:update`, `:destroy`, custom actions)
3. ✅ Use `AshPhoenix.Form` for all form handling
4. ✅ Use `Ash.*` functions for all database operations
5. ✅ Include `actor: current_user` in all calls for authorization
6. ✅ Test with Ash policies and authorization in mind

### Common Ash Patterns
```elixir
# Forms
form = AshPhoenix.Form.for_create(User, :register_with_password, forms: [auto?: false])
form = AshPhoenix.Form.for_update(user, :update, forms: [auto?: false])
form = AshPhoenix.Form.validate(form, params)
{:ok, user} = AshPhoenix.Form.submit(form, params: params)

# Database Operations
{:ok, users} = Ash.read(User, actor: current_user)
{:ok, user} = Ash.get(User, id, actor: current_user)
{:ok, user} = Ash.create(User, params, action: :register_with_password, actor: current_user)
{:ok, user} = Ash.update(user, params, action: :update, actor: current_user)
:ok = Ash.destroy(user, actor: current_user)
```

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

**⚠️ GOLDEN RULE**: After any code changes involving Ash resources, ALWAYS run:
1. `mix ash.codegen --check` (generate any needed migrations)
2. `mix ecto.migrate` (apply pending migrations)
3. THEN start the server with `mix phx.server`

**Never let the app run ahead of the database schema!**

### Testing
**🚨 CRITICAL RULE: NO BUILD IS COMPLETE UNTIL ALL TESTS PASS**
- **A feature implementation is NOT finished until all related tests are passing**
- **Never consider a task complete if there are failing tests in the affected area**
- **All test failures must be investigated and fixed, not dismissed as "non-critical"**
- **If tests are failing, the code is not ready for production**

**⚠️ ASH DOMAIN AUTHORIZATION TESTING RULES:**
- **ALL tests for Ash domains with `require_actor? true` MUST include actor support**
- **ALWAYS create admin user in test setup**: `Ash.create(User, attrs, action: :register_with_password)`
- **ALWAYS include `actor: admin_user` parameter** in ALL Ash operations (create, read, update, destroy, load)
- **Use `password_confirmation` field** when creating users with `:register_with_password` action

**⚠️ ASH QUERY COMPILATION REQUIREMENTS:**
- **ALWAYS add `require Ash.Query` and `import Ash.Expr`** at the top of test files using Ash queries
- **Required for filter expressions**: `Ash.Query.filter(active == true)` won't compile without these imports
- **Enables query building**: Without these, variables like `active` in filters cause "undefined variable" errors
- **Add BEFORE any Ash.Query operations**: Place after other aliases but before describe blocks

**⚠️ TERMINAL CRASH ISSUE**: Direct test execution causes terminal crashes. Use manual Tidewave MCP approach instead.

**MANUAL TESTING APPROACH (Recommended):**
1. **Use Tidewave MCP** to examine test results and outputs instead of running tests directly
2. **Access via**: /home/jason/mcp-proxy http://localhost:4000/tidewave/mcp
3. **Query test files** and examine expected vs actual behavior through MCP interface
4. **Validate functionality** by examining code paths and test assertions manually

**Traditional Testing Commands (Use with caution - may crash terminal):**
```bash
mix test                    # Run all tests (with database setup) - TERMINAL CRASH RISK
mix test --only <tag>       # Run specific tagged tests - TERMINAL CRASH RISK  
mix test test/path/file.exs # Run specific test file - TERMINAL CRASH RISK
```

**⚠️ PORT CONFLICT RULE**: 
- **Port 4000 is reserved** for Tidewave MCP server integration
- **Always test Phoenix server on port 4001** using `PORT=4001 mix phx.server`
- **Never kill processes on port 4000** - this breaks MCP connectivity

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

**⚠️ MIGRATION SAFETY RULES:**
- **ALWAYS check existing schema** before creating migrations with `mix ecto.migrations`
- **NEVER assume table structure** - use `\d table_name` in psql or check existing migrations
- **VERIFY resource snapshots** in `priv/resource_snapshots/` before running `mix ash.codegen`
- **TEST migrations safely** by checking generated SQL in migration files before applying
- **REMOVE EXISTING TABLES** from generated migrations if they already exist in the database

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

## Implementation Plan Progress Tracking Rules

**⚠️ PLAN PROGRESS TRACKING RULE:**
- **ALWAYS update implementation plan documents** with completion status as work progresses
- **MARK phases/sections as completed** with ✅ **COMPLETED** when fully implemented
- **MARK phases/sections as partially complete** with ⚠️ **PARTIALLY COMPLETE** when some work remains
- **MARK phases/sections as to-do** with 📋 **TO DO** when not yet started
- **UPDATE implementation timeline tables** with status columns showing current progress
- **ANNOTATE code sections** in plans with implementation notes and file locations

**📝 PHASE COMPLETION SUMMARY RULE:**
- **SAVE helpful phase completion summaries** from conversations to the correct section of implementation plans
- **DOCUMENT what was actually implemented** vs what was originally planned
- **INCLUDE file paths and key code locations** for implemented features
- **UPDATE conclusion sections** with current implementation status and remaining work
- **MAINTAIN implementation status percentages** (e.g., "85% complete") in plan summaries

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
