---
title: "How the Documentation System Works"
category: "dev"
tags: ["documentation", "system", "guide", "developers"]
author: "Development Team"
---

# How the Documentation System Works

This guide explains how the Sertantai documentation system is architected and how developers can create, organize, and maintain documentation.

<!-- TOC -->

## 📁 Document Structure & Location

### File Location
All documentation files are stored in:
```
docs-app/priv/static/docs/
```

### Directory Organization
Documents are organized by **category** into subdirectories:

```
priv/static/docs/
├── dev/           # Developer documentation
│   ├── index.md   # Category landing page
│   ├── setup.md
│   └── api.md
├── user/          # User-facing documentation
│   ├── index.md   # Category landing page
│   └── guide.md
└── admin/         # Admin documentation (future)
    └── index.md
```

**Key Rules:**
- Each category **must** have an `index.md` file as the landing page
- Categories become URL paths: `/dev`, `/user`, `/admin`
- File names become page URLs: `setup.md` → `/dev/setup`

## 📝 Document Format

### Frontmatter (Required)
Every markdown file must start with YAML frontmatter:

```yaml
---
title: "Page Title"           # Required: Display title
category: "dev"               # Required: Must match directory name
tags: ["tag1", "tag2"]        # Optional: For organization
author: "Author Name"         # Optional: Attribution
---
```

### Markdown Content
After the frontmatter, write standard **GitHub Flavored Markdown (GFM)**:

```markdown
# Main Heading

## Section Heading

Regular paragraph text with **bold** and *italic* formatting.

- Bullet points
- Work as expected

1. Numbered lists
2. Also supported

```elixir
# Code blocks with syntax highlighting
def example_function do
  "Hello, World!"
end
```

> Blockquotes for important notes

| Tables | Are | Supported |
|--------|-----|-----------|
| With   | Proper | Formatting |
```

## 📑 Table of Contents (TOC) Generation

The system includes automatic Table of Contents generation with multiple format options.

### Adding a TOC to Your Document

To include a Table of Contents in your document, simply add a TOC placeholder anywhere in your markdown content:

```markdown
<!-- TOC -->
```

**Requirements:**
- No special frontmatter tags are needed
- The document must have heading levels 2-6 (H2-H6) to generate TOC entries
- H1 headings are excluded from TOC (typically the page title)
- The placeholder will be automatically replaced with the rendered TOC

### TOC Placeholder Options

Multiple TOC formats are supported:

```markdown
<!-- TOC -->           # Standard navigation TOC (default)
<!-- TOC inline -->    # Collapsible inline TOC (future feature)
<!-- TOC sidebar -->   # Sticky sidebar TOC (future feature)
[TOC]                  # Alternative syntax
[[TOC]]                # Another alternative syntax
```

### How TOC Works

1. **Heading Extraction**: System scans markdown for heading levels (H2-H6)
2. **Hierarchy Building**: Creates nested structure based on heading levels
3. **ID Generation**: Generates unique anchor IDs for each heading (e.g., `#overview`, `#technical-architecture`)
4. **Link Creation**: TOC entries link to their corresponding headings
5. **Styling**: Applies responsive CSS styling with hover effects

### TOC Appearance

The generated TOC includes:
- **Title**: "Table of Contents" heading
- **Hierarchical Structure**: Nested lists showing document structure
- **Clickable Links**: Each entry links to the corresponding section
- **Responsive Design**: Works on desktop and mobile
- **Hover Effects**: Visual feedback on link interaction
- **Accessibility**: Proper semantic HTML and ARIA attributes

### Example TOC Output

When you add `<!-- TOC -->` to a document with sections like:

```markdown
## Overview
## Architecture
### Core Components  
### Integration Flow
## Development Workflow
```

The system generates a styled navigation menu with proper nesting and links.

**Note**: This document includes a TOC above - you can see it in action!

## 🔗 Cross-References & Links

The system supports special link types for better integration:

### Internal Documentation Links
Link to other docs using relative paths:
```markdown
[Setup Guide](setup.md)
[User Guide](../user/guide.md)
```

### Ash Resource Links (Future Feature)
Link to Ash resource documentation:
```markdown
[User Resource](ash:User)
[Organization Resource](ash:Organization)
```

### ExDoc Links (Future Feature)
Link to generated ExDoc documentation:
```markdown
[MarkdownProcessor](exdoc:SertantaiDocs.MarkdownProcessor)
```

### Main App Links
Link to the main Sertantai application:
```markdown
[User Dashboard](main:users/dashboard)
[Settings Page](main:settings)
```

## ⚙️ How the System Works

### 1. File Processing Pipeline
```
Markdown File → MarkdownProcessor → HTML → Template → Browser
```

1. **File Reading**: System reads `.md` files from `priv/static/docs/`
2. **Frontmatter Extraction**: YAML metadata parsed and separated
3. **Markdown Processing**: Content converted to HTML using MDEx (fast Rust-based processor)
4. **Cross-Reference Processing**: Special links are resolved to proper URLs
5. **Template Rendering**: HTML wrapped in Phoenix templates with navigation

### 2. URL Routing
The system uses this routing pattern:
```
/                    → Home page (dev/index.md or root index)
/:category           → Category index (e.g., /dev → dev/index.md)
/:category/:page     → Specific page (e.g., /dev/setup → dev/setup.md)
```

### 3. Navigation Generation
Navigation is automatically generated from:
- Directory structure (categories)
- Frontmatter metadata (titles, tags)
- File organization

The navigation appears in the left sidebar and updates based on the current page.

## 🔧 Development Workflow

### Adding New Documentation

1. **Choose the Category**: Determine if it's `dev`, `user`, or other
2. **Create the File**: Add `filename.md` in the appropriate category directory
3. **Add Frontmatter**: Include required title and category fields
4. **Write Content**: Use GitHub Flavored Markdown
5. **Test Locally**: Start the docs app and verify rendering
6. **Commit & Deploy**: Add to git and deploy

### Creating New Categories

1. **Create Directory**: `mkdir priv/static/docs/new-category`
2. **Add Index File**: Create `index.md` with category overview
3. **Update Navigation**: The system will automatically detect the new category
4. **Add Route (if needed)**: Most categories work automatically

### Development Server

To work on documentation locally:

```bash
cd docs-app

# Start the development server
PORT=4001 mix phx.server

# Or use the Docker setup
docker-compose up docs-app
```

Visit `http://localhost:4001` to see your documentation.

## 🔒 Security & Access Control

### Current State
- All documentation is publicly accessible
- No authentication required

### Planned Features
- **Developer Documentation**: Will be secured behind authentication
- **User Documentation**: Will remain public or have role-based access
- **Admin Documentation**: Will require admin privileges

### Implementation Notes
Access control will be implemented at the Phoenix router level, checking user authentication and roles before serving documentation content.

## 🛠️ Technical Architecture

### Key Components

1. **MarkdownProcessor** (`lib/sertantai_docs/markdown_processor.ex`)
   - Processes markdown files using MDEx
   - Handles frontmatter extraction
   - Manages cross-reference resolution

2. **DocController** (`lib/sertantai_docs_web/controllers/doc_controller.ex`)
   - Handles HTTP requests for documentation
   - Routes requests to appropriate markdown files
   - Manages error handling for missing content

3. **Navigation** (`lib/sertantai_docs_web/navigation.ex`)
   - Generates sidebar navigation
   - Creates breadcrumb trails
   - Handles fallback navigation

4. **Integration** (`lib/sertantai_docs/integration.ex`)
   - Manages file system monitoring
   - Handles content synchronization
   - Provides development API endpoints

### File System Monitoring
The system automatically watches for file changes during development and updates content without requiring server restarts.

## 📋 Best Practices

### File Naming
- Use lowercase with hyphens: `api-guide.md`, `setup-instructions.md`
- Keep names descriptive but concise
- Avoid spaces in filenames

### Content Organization
- Start with overview/index pages
- Break large topics into separate files
- Use consistent heading hierarchy
- Include cross-references between related topics

### Frontmatter Guidelines
```yaml
---
title: "Clear, Descriptive Title"        # User-friendly display name
category: "dev"                          # Must match directory
tags: ["api", "authentication"]         # 2-4 relevant tags
author: "Team Name"                      # Optional attribution
date: "2024-01-15"                      # Optional creation date
---
```

### Writing Style
- Use clear, concise language
- Include code examples where helpful
- Add navigation hints (Next: ..., See also: ...)
- Test all links and examples

## 🚀 Future Enhancements

### Planned Features
- [ ] Full-text search across all documentation
- [ ] Automatic API documentation generation from Ash resources
- [ ] Integration with ExDoc for function documentation
- [ ] Version control and change tracking
- [ ] Multi-language support
- [ ] PDF export functionality
- [ ] Comment and feedback system

### Integration Roadmap
- **Phase 1**: Basic authentication and role-based access ✅ (Completed)
- **Phase 2**: Enhanced cross-referencing with main app
- **Phase 3**: Automated API documentation
- **Phase 4**: Advanced search and indexing

---

## Need Help?

- **Issues with the docs app**: Check the [Development Setup](setup.md) guide
- **Content questions**: Contact the development team
- **System improvements**: Create issues in the main repository

This documentation system is designed to grow with the project while maintaining simplicity and developer efficiency.