# Phase 1 Implementation Plan: Phoenix + Ash Foundation

## Overview

This document provides a detailed implementation plan for Phase 1 of the Sertantai documentation strategy. Phase 1 focuses on establishing the foundational Phoenix application with Ash Framework integration, MDEx markdown processing, and basic Petal Components styling.

**Duration**: 1-2 weeks  
**Goal**: Create a functional documentation application that can render markdown files with consistent styling

## Phase 1 Objectives

1. **Create Phoenix docs application** with Ash Framework integration
2. **Set up MDEx markdown processing** pipeline for high-performance rendering
3. **Implement basic Petal Components** layout and styling
4. **Configure Ash resources** for content management
5. **Set up database** (optional) for user analytics and content metadata

## Prerequisites

- Elixir 1.15+
- Phoenix 1.7+
- PostgreSQL (for Ash resources, if using database features)
- Node.js/npm (for asset compilation)

## Implementation Steps

### Step 1: Project Structure Setup (Day 1)

#### 1.1 Create the Documentation Application Directory
```bash
# From the sertantai root directory
mkdir docs-app
cd docs-app
```

#### 1.2 Initialize Phoenix Application
```bash
# Create Phoenix app without Ecto (we'll use Ash instead)
mix phx.new . --app sertantai_docs --module SertantaiDocs --no-ecto --no-dashboard
```

#### 1.3 Update Directory Structure
Create the recommended directory structure:
```
docs-app/
├── lib/
│   ├── sertantai_docs/
│   │   ├── application.ex          # Main application module
│   │   ├── docs/                   # Ash domain directory
│   │   ├── markdown_processor.ex   # MDEx processing module
│   │   └── integration.ex          # Main app integration
│   └── sertantai_docs_web/
│       ├── controllers/
│       ├── live/                   # LiveView components
│       ├── components/             # Petal Components integration
│       └── templates/
├── priv/
│   ├── static/docs/               # Markdown content files
│   │   ├── dev/                   # Developer documentation
│   │   └── user/                  # User documentation
│   └── repo/                      # Database migrations (if using)
├── assets/                        # Frontend assets
├── config/                        # Application configuration
└── mix.exs                        # Dependencies and project config
```

### Step 2: Dependencies Configuration (Day 1)

#### 2.1 Update mix.exs
Add the required dependencies to `mix.exs`:

**Key Dependencies to Add:**
- `{:ash, "~> 3.0"}` - Core Ash framework
- `{:ash_phoenix, "~> 2.0"}` - Phoenix integration
- `{:ash_postgres, "~> 2.0"}` - PostgreSQL data layer (optional)
- `{:mdex, "~> 0.8"}` - High-performance markdown processing
- `{:petal_components, "~> 1.8"}` - UI component library
- `{:heroicons, "~> 0.5"}` - Icon library

#### 2.2 Install Dependencies
```bash
mix deps.get
```

#### 2.3 Configure Application
Update `config/config.exs` and environment-specific configurations.

### Step 3: Ash Framework Setup (Day 2)

#### 3.1 Create Ash Domain Structure
Create the basic Ash domain for documentation management:

**Files to Create:**
- `lib/sertantai_docs/docs.ex` - Ash domain definition
- `lib/sertantai_docs/docs/article.ex` - Article resource
- `lib/sertantai_docs/repo.ex` - Repository (if using database)

#### 3.2 Database Setup (Optional)
If using database features:
- Configure PostgreSQL connection
- Set up migrations
- Create initial schemas

#### 3.3 Basic Article Resource
Create a basic Ash resource for managing documentation articles with:
- UUID primary key
- Title, slug, content_path attributes
- Category (dev/user/api) classification
- Tags for organization
- View count tracking
- Timestamps

### Step 4: MDEx Markdown Processing (Day 3)

#### 4.1 Create Markdown Processor Module
Implement `SertantaiDocs.MarkdownProcessor` with:

**Core Features:**
- Frontmatter extraction
- GitHub Flavored Markdown support
- Syntax highlighting for code blocks
- Table, strikethrough, and task list support
- Custom link processing for cross-references

#### 4.2 Configuration Options
Set up MDEx with optimal configuration for documentation:
- Enable all relevant GFM extensions
- Configure safe HTML rendering
- Set up syntax highlighting
- Enable smart typography

#### 4.3 Testing Setup
Create basic tests for markdown processing:
- Test frontmatter extraction
- Verify GFM feature rendering
- Test custom link processing

### Step 5: Petal Components Integration (Day 4)

#### 5.1 Asset Configuration
Update `assets/tailwind.config.js` to include:
- Petal Components styles
- Typography plugin for prose content
- Custom documentation styles

#### 5.2 Component Structure
Create component modules:
- `core_components.ex` - Basic Petal Components setup
- `layout_components.ex` - Documentation-specific layouts
- `doc_components.ex` - Content-specific components

#### 5.3 Basic Layout Implementation
Create a basic documentation layout with:
- Responsive navigation sidebar
- Main content area with prose styling
- Optional table of contents sidebar
- Consistent header and footer

### Step 6: Basic Content Rendering (Day 5)

#### 6.1 Controller Setup
Create `DocController` with basic actions:
- `index` - Documentation home page
- `show` - Individual documentation page rendering
- Error handling for missing files

#### 6.2 Route Configuration
Set up basic routing in `router.ex`:
- Root documentation route
- Category-based routes (dev/user)
- Catch-all for individual pages

#### 6.3 Template Creation
Create basic templates:
- Layout template with Petal Components
- Content template for rendered markdown
- Navigation template for sidebar

### Step 7: File System Integration (Day 6)

#### 7.1 Content Organization
Set up the content directory structure:
```
priv/static/docs/
├── dev/
│   ├── index.md
│   ├── setup.md
│   └── architecture.md
└── user/
    ├── index.md
    ├── getting-started.md
    └── features.md
```

#### 7.2 Navigation Generation
Implement basic navigation generation:
- Scan file system for available documents
- Generate navigation structure
- Handle nested directories

#### 7.3 Content Metadata
Implement frontmatter processing for:
- Page titles
- Categories and tags
- Last modified dates
- Custom attributes

### Step 8: Integration with Main Application (Day 7)

#### 8.1 Content Synchronization
Create basic integration module:
- File system monitoring
- Content metadata updates
- ExDoc integration planning

#### 8.2 Cross-Reference Setup
Implement basic cross-referencing:
- Links to main application routes
- ExDoc integration placeholders
- Ash resource references

#### 8.3 Development Workflow
Set up development conveniences:
- Live reload for markdown files
- Auto-regeneration of navigation
- Development-specific routing

### Step 9: Testing and Documentation (Day 8)

#### 9.1 Test Suite Creation
Create comprehensive tests:
- Unit tests for markdown processing
- Integration tests for rendering pipeline
- Component tests for Petal integration
- End-to-end tests for user flows

#### 9.2 Development Documentation
Document the setup process:
- Local development instructions
- Configuration options
- Troubleshooting guide
- Contributing guidelines

#### 9.3 Performance Baseline
Establish performance benchmarks:
- Markdown rendering speed
- Page load times
- Memory usage patterns

### Step 10: Production Readiness (Day 9-10)

#### 10.1 Configuration Management
Set up environment-specific configurations:
- Production database settings
- Asset compilation settings
- Security configurations

#### 10.2 Basic Deployment Setup
Prepare for deployment:
- Docker configuration (optional)
- Environment variable documentation
- Basic CI/CD pipeline setup

#### 10.3 Monitoring and Logging
Implement basic observability:
- Application logging
- Error tracking
- Performance monitoring setup

## Deliverables

### Primary Deliverables
1. **Functional Phoenix Documentation Application**
   - Renders markdown files using MDEx
   - Styled with Petal Components
   - Responsive navigation
   - Basic Ash resources configured

2. **Content Management System**
   - File-based content organization
   - Frontmatter metadata support
   - Navigation auto-generation
   - Basic cross-referencing

3. **Development Environment**
   - Local development setup
   - Live reload capabilities
   - Testing framework
   - Documentation for contributors

### Secondary Deliverables
1. **Performance Benchmarks**
   - Rendering speed metrics
   - Memory usage profiles
   - Load time measurements

2. **Integration Foundations**
   - Main application connection points
   - ExDoc integration architecture
   - Content synchronization framework

## Success Criteria

### Functional Requirements
- [ ] Phoenix application starts successfully
- [ ] Markdown files render correctly with MDEx
- [ ] Petal Components display properly
- [ ] Navigation generates from file structure
- [ ] Responsive design works on mobile/desktop
- [ ] Basic Ash resources function correctly

### Technical Requirements
- [ ] All tests pass
- [ ] Performance meets baseline requirements
- [ ] Code follows Elixir best practices
- [ ] Documentation is comprehensive
- [ ] Error handling is robust

### Integration Requirements
- [ ] File system changes trigger updates
- [ ] Cross-references resolve correctly
- [ ] Development workflow is smooth
- [ ] Production deployment is possible

## Risk Mitigation

### Technical Risks
1. **MDEx Compatibility Issues**
   - Mitigation: Test with sample content early
   - Fallback: Earmark as alternative

2. **Petal Components Integration Complexity**
   - Mitigation: Start with basic components
   - Fallback: Custom TailwindCSS styling

3. **Ash Framework Learning Curve**
   - Mitigation: Begin with simple resources
   - Fallback: Plain Phoenix without Ash

### Timeline Risks
1. **Dependency Configuration Issues**
   - Mitigation: Allocate extra time for setup
   - Plan: Have backup dependency versions ready

2. **Integration Complexity**
   - Mitigation: Implement core features first
   - Plan: Defer advanced integration to Phase 2

## Next Steps (Phase 2 Preview)

Phase 1 completion enables Phase 2 development:
- LiveView components for real-time search
- Advanced navigation features
- ExDoc integration
- Authentication system
- Analytics and tracking

## Resources and References

### Documentation
- [Phoenix Framework Guides](https://hexdocs.pm/phoenix/)
- [Ash Framework Documentation](https://hexdocs.pm/ash/)
- [MDEx Library Documentation](https://hexdocs.pm/mdex/)
- [Petal Components Guide](https://petal.build/)

### Code Examples
- Example implementations will be provided during development
- Reference patterns from main Sertantai application
- Community examples from similar projects

### Support
- Elixir Forum for community support
- GitHub issues for dependency-specific problems
- Team knowledge sharing sessions