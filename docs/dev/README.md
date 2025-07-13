# Developer Documentation

Technical documentation and guides for developers working on Sertantai.

## Getting Started

### 🚀 [Development Setup](./DEVELOPMENT.md)
Complete guide for setting up your development environment, including:
- Database setup (local PostgreSQL vs Supabase)
- Environment configuration
- Asset compilation
- Running tests

## Architecture & Implementation

### 📋 [Multi-Location Organizations](./multi-location-organization-plan.md)
Comprehensive implementation plan for multi-location organization support:
- Data model design
- Database migrations
- Business logic implementation
- UI/UX considerations
- Backward compatibility strategy

### 💾 [Record Selections Persistence](./persistence/record_selections_persistence_plan.md)
Implementation plan for persistent user record selections:
- ETS + database hybrid approach
- User session management
- Performance considerations

## Troubleshooting

### 🔧 [Authentication Issues](./authentication-troubleshooting.md)
Common authentication problems and solutions:
- PostgreSQL citext extension issues
- LiveView authentication patterns
- User session debugging

## Development Workflow

1. **Setup**: Follow the [Development Setup](./DEVELOPMENT.md) guide
2. **Database**: Use `mix ash.codegen --check` before migrations
3. **Testing**: Run tests with `mix test`
4. **Assets**: Build with `mix assets.deploy`

## Architecture Overview

Sertantai is built with:
- **Phoenix 1.7+** with LiveView
- **Ash Framework 3.0+** for business logic
- **PostgreSQL** for data persistence
- **Tailwind CSS** for styling

## Contributing

When making changes:
1. Update relevant documentation
2. Run the full test suite
3. Check for breaking changes
4. Update migration guides if needed