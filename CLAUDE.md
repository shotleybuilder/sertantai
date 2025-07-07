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
```bash
mix setup                    # Full setup: deps, database, assets
mix phx.server              # Start development server
iex -S mix phx.server       # Start server in interactive shell
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