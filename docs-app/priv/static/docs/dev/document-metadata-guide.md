---
title: "Document Metadata Guide for Creators"
category: "dev"
tags: ["documentation", "metadata", "frontmatter", "authoring"]
priority: "high"
author: "Documentation Team"
description: "Complete guide for document creators on using YAML frontmatter to optimize search, filter, and sort functionality"
---

# Document Metadata Guide for Creators

This guide explains how to properly structure your documentation with YAML frontmatter metadata to ensure optimal integration with Sertantai's search, filter, and sort features.

## 📋 YAML Frontmatter Overview

Every documentation file should begin with YAML frontmatter enclosed in triple dashes:

```yaml
---
title: "Your Document Title"
category: "dev"
tags: ["tag1", "tag2", "tag3"]
priority: "high"
author: "Your Name"
description: "Brief description of the document"
status: "live"
---
```

## 🔑 Required Fields

### title
- **Purpose**: Display name in navigation and search results
- **Format**: String in quotes
- **Best Practices**:
  - Keep concise but descriptive (2-8 words)
  - Use title case: "Getting Started with Phoenix"
  - Avoid redundant words like "Documentation" or "Guide" in titles
  - Be specific: "LiveView State Management" vs "State Guide"

```yaml
# ✅ Good
title: "Authentication Setup"
title: "Database Migration Guide" 
title: "API Error Handling"

# ❌ Avoid
title: "Documentation for Authentication Setup Guide"
title: "Guide"
title: "How to Do Database Stuff"
```

### category
- **Purpose**: Primary classification for filtering
- **Format**: String (lowercase)
- **Standard Categories**:
  - `"dev"` - Developer documentation, technical guides
  - `"user"` - End-user guides, getting started
  - `"build"` - Build, deployment, infrastructure
  - `"test"` - Testing guides, QA documentation
  - `"api"` - API reference and integration guides

```yaml
# ✅ Examples
category: "dev"      # Technical implementation guide
category: "user"     # User-facing tutorial
category: "build"    # CI/CD or deployment doc
category: "test"     # Testing methodology
```

## 🏷️ Recommended Fields

### tags
- **Purpose**: Granular topic classification for filtering and search
- **Format**: Array of strings
- **Guidelines**:
  - Use 3-7 relevant tags
  - Include technology names: `"phoenix"`, `"ecto"`, `"liveview"`
  - Add functional tags: `"authentication"`, `"database"`, `"api"`
  - Include difficulty: `"beginner"`, `"advanced"`, `"intermediate"`

```yaml
# ✅ Good tag examples
tags: ["phoenix", "liveview", "authentication", "setup", "beginner"]
tags: ["ecto", "database", "migrations", "advanced"]
tags: ["api", "rest", "json", "integration", "intermediate"]

# ❌ Too vague or redundant
tags: ["docs", "guide", "tutorial", "documentation"]
```

### priority
- **Purpose**: Importance level for sorting and visibility
- **Format**: String
- **Values**:
  - `"high"` - Critical docs (setup, key concepts, breaking changes)
  - `"medium"` - Important but not essential (features, best practices)
  - `"low"` - Reference material, advanced topics, legacy docs

```yaml
# ✅ Priority guidelines
priority: "high"    # Getting started guides, setup instructions
priority: "medium"  # Feature documentation, how-to guides  
priority: "low"     # Advanced topics, reference material
```

### author
- **Purpose**: Content ownership and contact for updates
- **Format**: String
- **Best Practices**:
  - Use consistent naming: "John Smith" or "john.smith"
  - Team names are acceptable: "DevOps Team", "Documentation Team"

```yaml
author: "Sarah Johnson"
author: "Platform Team"
author: "john.doe"
```

### description
- **Purpose**: Brief summary for search results and metadata
- **Format**: String (1-2 sentences)
- **Guidelines**:
  - 50-150 characters optimal
  - Describe what the document covers
  - Include key keywords for search

```yaml
description: "Step-by-step guide to setting up Phoenix LiveView authentication with session management"
description: "Complete reference for Ecto database migrations including rollbacks and data transformations"
```

## 🔧 Optional Fields

### status
- **Purpose**: Publication status for filtering
- **Format**: String
- **Values**:
  - `"live"` (default) - Published, current documentation
  - `"archived"` - Legacy or deprecated content
  - `"draft"` - Work in progress (may be filtered out)

```yaml
status: "live"      # Current documentation
status: "archived"  # Legacy content
status: "draft"     # Work in progress
```

### last_modified
- **Purpose**: When document was last updated (auto-generated preferred)
- **Format**: ISO date string
- **Note**: Often handled automatically by the system

```yaml
last_modified: "2024-01-15"
```

### related
- **Purpose**: Links to related documents
- **Format**: Array of relative paths or document IDs

```yaml
related:
  - "/dev/authentication-setup"
  - "/user/getting-started"
```

## 📊 Metadata Strategy by Document Type

### Setup/Installation Guides
```yaml
---
title: "Phoenix LiveView Setup"
category: "dev"
tags: ["phoenix", "liveview", "setup", "installation", "beginner"]
priority: "high"
author: "Platform Team"
description: "Complete setup guide for Phoenix LiveView including dependencies and configuration"
status: "live"
---
```

### Feature Documentation
```yaml
---
title: "Real-time Data Sync"
category: "dev"
tags: ["liveview", "websockets", "real-time", "intermediate"]
priority: "medium"
author: "Backend Team"
description: "Implementing real-time data synchronization using Phoenix PubSub and LiveView"
---
```

### User Guides
```yaml
---
title: "Dashboard Navigation"
category: "user"
tags: ["dashboard", "navigation", "ui", "beginner"]
priority: "high"
author: "UX Team"
description: "How to navigate and use the main dashboard interface effectively"
---
```

### API Documentation
```yaml
---
title: "Authentication API Endpoints"
category: "api"
tags: ["api", "rest", "authentication", "jwt", "reference"]
priority: "medium"
author: "API Team"
description: "Complete reference for authentication endpoints including JWT token management"
---
```

### Troubleshooting Guides
```yaml
---
title: "Database Connection Issues"
category: "dev"
tags: ["database", "troubleshooting", "ecto", "postgresql", "intermediate"]
priority: "medium"
author: "DevOps Team"
description: "Common database connection problems and their solutions"
---
```

## 🎯 SEO and Discoverability

### Keyword Optimization
- Include important keywords in `title`, `description`, and `tags`
- Use terms your audience would search for
- Balance specificity with discoverability

### Tag Strategy
```yaml
# ✅ Multi-level tagging strategy
tags: [
  "phoenix",           # Technology
  "authentication",    # Feature
  "oauth",            # Specific implementation
  "setup",            # Task type
  "intermediate"      # Difficulty level
]
```

### Cross-Reference Support
```yaml
# Link related documents
related:
  - "/dev/oauth-configuration"
  - "/dev/session-management"
  - "/user/login-troubleshooting"
```

## 📁 File Organization Impact

### Directory Structure
Your file location affects automatic categorization:
```
/docs/dev/       -> category: "dev" (if not specified)
/docs/user/      -> category: "user" (if not specified)  
/docs/build/     -> category: "build" (if not specified)
/docs/api/       -> category: "api" (if not specified)
```

### Filename Best Practices
- Use kebab-case: `oauth-setup-guide.md`
- Include key terms: `phoenix-liveview-authentication.md`
- Avoid spaces and special characters

## ⚡ Performance Considerations

### Efficient Metadata
- Keep tag arrays reasonable (3-7 items)
- Use consistent terminology across documents
- Avoid duplicate information between fields

### Search Optimization
```yaml
# ✅ Search-friendly metadata
title: "Phoenix LiveView Real-time Features"
tags: ["phoenix", "liveview", "real-time", "pubsub", "websockets"]
description: "Building real-time features with Phoenix LiveView and PubSub"

# ❌ Poor for search
title: "Guide"
tags: ["guide", "documentation", "help"]
description: "A guide about stuff"
```

## 🔄 Maintenance and Updates

### Regular Review
- **Quarterly**: Review `priority` and `status` fields
- **After major changes**: Update `tags` and `description`
- **Version updates**: Modify related technology tags

### Consistency Checks
- Use consistent author names across documents
- Standardize tag naming conventions
- Regular audit of category distribution

### Deprecation Process
```yaml
# Mark legacy content
status: "archived"
priority: "low"
tags: ["legacy", "deprecated", "v1"]
description: "[DEPRECATED] Legacy authentication system - see v2 guide"
```

## 🛠️ Tools and Validation

### Frontmatter Validation
The documentation system validates:
- Required fields presence
- Category values against allowed list
- Tag format and reasonable limits
- Priority values

### Content Guidelines
- **Title**: 2-8 words, descriptive, no redundancy
- **Tags**: 3-7 items, specific and relevant
- **Description**: 50-150 characters, keyword-rich
- **Category**: Must match system categories

## 📚 Examples and Templates

### Basic Template
```yaml
---
title: "Document Title Here"
category: "dev"
tags: ["tag1", "tag2", "tag3"]
priority: "medium"
author: "Your Name"
description: "Brief but descriptive summary of the document content and purpose"
---
```

### Complete Example
```yaml
---
title: "Phoenix Context Testing Strategies"
category: "dev"
tags: ["phoenix", "testing", "contexts", "elixir", "intermediate"]
priority: "medium"
author: "Backend Development Team"
description: "Comprehensive testing strategies for Phoenix contexts including mocking, fixtures, and integration tests"
status: "live"
related:
  - "/dev/phoenix-testing-setup"
  - "/dev/ecto-testing-patterns"
---
```

By following these guidelines, your documentation will be easily discoverable through search, properly categorized for filtering, and appropriately prioritized for different user needs. This improves the overall documentation experience and helps users find the information they need quickly and efficiently.