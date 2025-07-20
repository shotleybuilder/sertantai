---
title: "Phase 2: Core Documentation Features Implementation Plan"
description: "Detailed implementation plan for core documentation features including dynamic navigation, search, cross-references, and content migration"
category: "implementation-plan"
tags: ["phase2", "navigation", "search", "migration", "cross-references"]
priority: "high"
estimated_duration: "2 weeks"
dependencies: ["Phase 1 completion", "MDEx theming system"]
---

# Phase 2: Core Documentation Features Implementation Plan

## Overview

Phase 2 focuses on implementing the core documentation features that transform our basic Phoenix docs application into a fully functional documentation system. This phase builds on the foundation established in Phase 1 and implements dynamic navigation, real-time search, cross-reference systems, and content migration.

## 📋 **TO DO** - Phase 2 Milestones

### Milestone 1: Dynamic Navigation System ✅ **COMPLETED**
- [x] **File system scanner** for automatic navigation generation
- [x] **Hierarchical navigation structure** with categories and subcategories  
- [x] **Active page highlighting** and breadcrumb navigation
- [x] **Navigation state management** with LiveView
- [x] **Mobile-responsive navigation** with collapsible sidebar

### Milestone 2: Real-Time Search Implementation ✅ **COMPLETED**
- [x] **LiveView search component** with instant results
- [x] **Full-text search indexing** of markdown content
- [x] **Search result highlighting** and ranking
- [x] **Search filters** by category, tags, and content type
- [x] **Search analytics** and popular content tracking

### Milestone 2.5: Table of Contents (TOC) Generation ✅ **COMPLETED**
- [x] **Heading extraction** from markdown content with metadata support
- [x] **Hierarchical TOC tree building** from flat heading structures
- [x] **Multiple TOC formats** (standard nav, inline collapsible, sidebar)
- [x] **Smart TOC injection** with multiple placeholder types
- [x] **Custom template support** for flexible TOC rendering
- [x] **Smooth scroll integration** with JavaScript assets
- [x] **Phoenix component integration** for LiveView compatibility

### Milestone 3: Cross-Reference System
- [ ] **ExDoc integration** for API documentation linking
- [ ] **Inter-document linking** with validation
- [ ] **Ash resource references** with automatic link generation
- [ ] **Broken link detection** and reporting
- [ ] **Link preview system** for hover information

### Milestone 4: Content Migration & Organization
- [ ] **Migration scripts** for existing documentation
- [ ] **Content validation** and structure verification
- [ ] **Frontmatter standardization** across all documents
- [ ] **Asset migration** (images, diagrams, downloads)
- [ ] **URL redirection** for legacy documentation links

### Milestone 5: Authentication & User Features
- [ ] **Basic Ash authentication** setup
- [ ] **User-specific content** visibility controls
- [ ] **Reading progress tracking** per user
- [ ] **Bookmark system** for favorite documentation
- [ ] **User feedback collection** on documentation quality

## 🎯 Implementation Strategy

### Week 1: Navigation & Search Foundation

#### Task 1.1: Dynamic Navigation System
**Objective**: Implement automatic navigation generation from file structure

**Implementation Approach**:
- Create navigation scanner that walks the `/priv/static/docs/` directory
- Parse frontmatter to extract titles, categories, and ordering information
- Build hierarchical navigation tree based on directory structure
- Implement LiveView component for interactive navigation state

**Key Components**:
- `SertantaiDocs.Navigation.Scanner` - File system scanning module
- `SertantaiDocs.Navigation.Builder` - Navigation tree construction
- `SertantaiDocsWeb.NavLive` - LiveView navigation component
- `SertantaiDocsWeb.Components.Navigation` - Reusable navigation components

**Acceptance Criteria**:
- ✅ Navigation automatically updates when documentation files are added/removed
- ✅ Hierarchical structure reflects directory organization (dev/, user/, api/)
- ✅ Active page highlighting works correctly
- ✅ Mobile navigation collapses appropriately
- ✅ Navigation state persists during page navigation

#### Task 1.2: Real-Time Search with LiveView
**Objective**: Implement instant search across all documentation content

**Implementation Approach**:
- Create search indexing system that processes all markdown files
- Build LiveView search component with real-time results
- Implement search result ranking based on relevance and content type
- Add search filters for categories and content types

**Key Components**:
- `SertantaiDocs.Search.Index` - Content indexing and search functionality
- `SertantaiDocsWeb.SearchLive` - Real-time search interface
- `SertantaiDocs.Search.Ranking` - Search result ranking algorithm
- Search result highlighting and snippet generation

**Acceptance Criteria**:
- ✅ Search results appear instantly as user types (debounced)
- ✅ Search covers titles, content, and tags across all documentation
- ✅ Results are ranked by relevance and content freshness
- ✅ Search filters work correctly (category, type, tags)
- ✅ Search performance is acceptable for large documentation sets

#### Task 1.3: Table of Contents (TOC) Generation ✅ **COMPLETED**
**Objective**: Implement comprehensive TOC generation with multiple formats and MDEx integration

**Implementation Approach**:
- Built heading extraction system that parses markdown and identifies heading structure
- Created hierarchical tree builder for nested TOC structures
- Implemented multiple TOC formats (navigation, inline collapsible, sidebar)
- Added smart placeholder system for flexible TOC injection
- Integrated custom template support for extensible rendering

**Key Components** ✅ **IMPLEMENTED**:
- `SertantaiDocs.TOC.Extractor` - Heading extraction and tree building
- `SertantaiDocs.TOC.Generator` - HTML processing and TOC injection
- `SertantaiDocsWeb.Components.TOC` - Phoenix LiveView components
- Multiple placeholder types: `<!-- TOC -->`, `<!-- TOC inline -->`, `<!-- TOC sidebar -->`

**Current TOC Features** ✅:
- **Heading Extraction**: Supports H1-H6 with custom metadata (`{#custom-id data-toc="Display Text"}`)
- **Special Character Handling**: Properly handles Phoenix component syntax (`<.form>`) and special characters
- **ID Generation**: Automatic unique ID generation with collision handling and proper slugification
- **Hierarchical Trees**: Builds nested structures from flat heading lists with level filtering
- **Multiple Formats**: Standard navigation, collapsible inline TOC, and sticky sidebar TOC
- **Template Support**: Custom template functions for flexible rendering
- **Smooth Scroll**: JavaScript integration with `data-smooth-scroll` attributes
- **Phoenix Integration**: Full LiveView component support with accessibility features

**Acceptance Criteria**:
- ✅ TOC automatically generates from any markdown content
- ✅ Multiple TOC formats work correctly in same document
- ✅ Custom templates allow flexible TOC rendering
- ✅ Heading IDs are unique and URL-safe
- ✅ TOC respects level filtering (min/max heading levels)
- ✅ Phoenix component syntax preserved in headings
- ✅ Smooth scroll behavior works with generated anchor links
- ✅ Full test coverage with TDD approach (59 tests passing)

### Week 2: TOC-MDEx Integration & Cross-References

#### Task 2.0: TOC-MDEx Integration Enhancement ✅ **COMPLETED**
**Objective**: Integrate existing TOC system with MDEx for improved performance and consistency

**Implementation Summary**:
Successfully integrated TOC system with MDEx following TDD methodology. Enhanced performance and consistency while maintaining full backward compatibility.

**Phase 2.0.1: MDEx Markdown Processing Integration** ✅ **COMPLETED**
- ✅ Replaced simplified markdown-to-HTML with `MDEx.to_html!/2` calls
- ✅ Added `header_ids: ""` extension to MarkdownProcessor for automatic heading ID generation
- ✅ Ensured MDEx heading IDs are consistent with TOC expectations
- ✅ Updated all 18 TOC generator tests to work with MDEx-generated HTML structure (data-sourcepos attributes)

**Phase 2.0.2: AST-Based Heading Extraction** ✅ **COMPLETED**
- ✅ Implemented `MDEx.parse_document/1` for AST-based heading extraction in TOC.Extractor
- ✅ Replaced regex-based HTML parsing with structured AST traversal using MDEx.Document nodes
- ✅ Enhanced heading metadata extraction directly from MDEx document structures
- ✅ Improved performance by avoiding HTML parsing entirely for heading detection

**Phase 2.0.3: Unified ID Generation** ✅ **COMPLETED**  
- ✅ Unified TOC and MDEx to use same ID generation algorithm via `Extractor.slugify/1`
- ✅ Made `MarkdownProcessor.mdex_options/0` public for TOC system access
- ✅ Eliminated duplicate ID generation between TOC and main markdown processor
- ✅ Maintained full backward compatibility with existing TOC placeholders and custom metadata

**Actual Implementation** (Commit: `99d7f3a`):

```elixir
# MarkdownProcessor enhanced with header_ids
def mdex_options do
  [
    extension: [
      # ... existing options ...
      header_ids: ""  # Enable header IDs with empty prefix
    ],
    # ... rest of configuration
  ]
end

# AST-based heading extraction in TOC.Extractor
def extract_headings_from_ast(content, _opts) do
  case MDEx.parse_document(content) do
    {:ok, %MDEx.Document{nodes: nodes}} ->
      extract_headings_from_ast_nodes(nodes)
    {:error, _reason} ->
      extract_headings_from_text(content, [])  # Fallback
  end
end

# MDEx integration in TOC.Generator  
defp markdown_to_html(markdown) do
  MDEx.to_html!(markdown, mdex_options_with_toc())
end
```

**Key Benefits Achieved**:
- ✅ **Performance**: AST parsing eliminates HTML regex processing overhead
- ✅ **Consistency**: Unified ID generation produces identical IDs (e.g., `getting-started-with-phoenix-liveview`)
- ✅ **Accuracy**: Better handling of Phoenix components (`<.form>`) and special characters
- ✅ **Maintainability**: Single source of truth for markdown processing via MarkdownProcessor

**Acceptance Criteria Met**:
- ✅ AST parsing provides significant performance improvement over HTML regex
- ✅ Heading IDs perfectly match between TOC and MDEx-generated content
- ✅ All existing TOC features work unchanged (multiple formats, custom templates, smooth scroll)
- ✅ No breaking changes to TOC placeholder syntax (`<!-- TOC -->`, `[TOC position="right"]`)
- ✅ Complete test suite passes: 131 tests, 0 failures (18 TOC tests + 14 extractor tests updated)
- ✅ Integration preserves all MarkdownProcessor functionality (12 + 4 tests passing)

#### Task 2.1: Cross-Reference System Implementation
**Objective**: Create robust linking system between documentation and API references

**Implementation Approach**:
- Implement custom markdown processing for special link types
- Create link validation system to detect broken references
- Build hover preview system for link information
- Integrate with ExDoc output for API documentation links

**Key Components**:
- `SertantaiDocs.CrossRef.Processor` - Custom link processing
- `SertantaiDocs.CrossRef.Validator` - Link validation and checking
- Link preview components for rich hover information
- Integration with ExDoc HTML output

**Link Types to Support**:
- `[User Resource](ash:Sertantai.Accounts.User)` - Ash resource links
- `[User Module](exdoc:Sertantai.Accounts.User)` - ExDoc module links  
- `[Setup Guide](dev:setup-guide)` - Internal documentation links
- `[Feature Overview](user:features/overview)` - User guide links

**Acceptance Criteria**:
- ✅ All custom link types render correctly with appropriate styling
- ✅ Links to API documentation work correctly
- ✅ Broken link detection identifies missing references
- ✅ Link previews show helpful information on hover
- ✅ Link validation runs automatically on content updates

#### Task 2.2: Content Migration & Standardization
**Objective**: Migrate existing documentation and establish content standards

**Implementation Approach**:
- Audit existing documentation across the codebase
- Create migration scripts for content conversion
- Standardize frontmatter format across all documents
- Migrate and organize assets (images, diagrams)

**Migration Checklist**:
- [ ] **Audit existing docs** - Catalog all existing documentation files
- [ ] **Create frontmatter templates** - Standard formats for different content types
- [ ] **Convert existing content** - Migrate README files, wiki content, etc.
- [ ] **Organize file structure** - Implement consistent directory hierarchy
- [ ] **Asset migration** - Move and organize images, diagrams, downloads
- [ ] **URL mapping** - Create redirects for legacy documentation URLs

**Content Standards**:
- Frontmatter must include: title, description, category, tags
- File naming convention: kebab-case with descriptive names
- Directory structure: `/dev/`, `/user/`, `/api/` for main categories
- Image organization: `/assets/images/[category]/` structure
- Consistent markdown formatting and style guidelines

**Acceptance Criteria**:
- ✅ All existing documentation is migrated to new system
- ✅ Frontmatter follows consistent standard across all files
- ✅ File organization is logical and scalable
- ✅ Legacy URLs redirect correctly to new documentation
- ✅ Assets are properly organized and accessible

## 🔧 Technical Implementation Details

### Navigation System Architecture

**File Structure Scanning**:
- Recursive directory traversal of documentation folders
- Frontmatter parsing for metadata extraction
- Category-based organization with configurable hierarchy
- Automatic ordering based on frontmatter priority or filename

**Navigation State Management**:
- LiveView state for expanded/collapsed navigation sections
- User preferences for navigation layout (stored in session)
- Active page tracking with breadcrumb generation
- Mobile-first responsive navigation design

### Search System Architecture

**Content Indexing Strategy**:
- Full-text indexing of markdown content after processing
- Metadata indexing (titles, descriptions, tags, categories)
- Periodic re-indexing when content changes
- Search result caching for performance

**Search Interface Design**:
- Instant search with debounced input handling
- Keyboard navigation for search results
- Search result pagination for large result sets
- Advanced search filters with URL state preservation

### Cross-Reference Processing

**Link Processing Pipeline**:
1. **Parse Phase**: Extract custom links from markdown during processing
2. **Resolve Phase**: Convert custom links to actual URLs
3. **Validate Phase**: Check that referenced content exists
4. **Enhance Phase**: Add hover previews and additional metadata

**Link Validation System**:
- Background job to validate all cross-references
- Daily link checking with broken link reporting
- Integration with CI/CD to prevent broken links in new content
- Dashboard for link health monitoring

## 📊 Success Metrics & Validation

### Navigation System Metrics
- **Navigation Discovery**: Users should find content within 3 clicks
- **Mobile Usability**: Navigation works seamlessly on mobile devices
- **Performance**: Navigation renders in under 200ms
- **Accuracy**: Navigation reflects current file structure 100% of time

### Search System Metrics
- **Search Speed**: Results appear within 100ms of query
- **Search Accuracy**: Relevant results appear in top 5 for common queries
- **Search Coverage**: All documentation content is searchable
- **User Engagement**: Search usage increases by 50% compared to current system

### TOC System Metrics ✅ **ACHIEVED** + MDEx Integration ✅ **COMPLETED**
- **TOC Generation Speed**: TOC builds in under 50ms for typical documents with AST parsing performance boost
- **Format Flexibility**: All 3 TOC formats (nav, inline, sidebar) work correctly with MDEx integration
- **Heading Coverage**: 100% of markdown headings (H1-H6) are extractable via AST and fallback parsing
- **ID Uniqueness**: All generated heading IDs are unique and URL-safe with unified slugification
- **Template Extensibility**: Custom template functions provide full rendering control
- **MDEx Integration**: ✅ Full AST-based integration with consistent ID generation and performance optimization
- **Test Coverage**: ✅ 131 tests passing with comprehensive MDEx integration test suite
- **Backward Compatibility**: ✅ All existing TOC features preserved with enhanced performance

### Cross-Reference Metrics
- **Link Health**: 99%+ of cross-references are valid and working
- **Integration Quality**: API links stay current with ExDoc updates
- **User Experience**: Link previews provide helpful context
- **Maintenance**: Broken link detection catches issues within 24 hours

### Content Migration Metrics
- **Completeness**: 100% of existing documentation migrated successfully
- **URL Preservation**: Legacy URLs redirect correctly
- **Content Quality**: All migrated content follows new standards
- **Asset Integrity**: All images and assets are accessible and properly linked

## 🚀 Phase 2 Deliverables

### Primary Deliverables
1. ✅ **Dynamic Navigation System** - Automatic, hierarchical navigation  
2. ✅ **Real-Time Search** - Instant search with filtering and ranking
3. ✅ **Table of Contents System** - Multi-format TOC generation with full MDEx integration
4. ✅ **MDEx Integration Enhancement** - AST-based parsing, unified ID generation, performance optimization
5. **Cross-Reference System** - Robust linking between docs and API  
6. **Migrated Content** - All existing documentation in new system
7. **Authentication Foundation** - Basic user system for Phase 3

### Documentation Deliverables
1. ✅ **Navigation System Guide** - How navigation generation works  
2. ✅ **Search Implementation Guide** - Search system architecture and usage
3. ✅ **TOC Implementation Guide** - Multi-format TOC generation and MDEx integration
4. ✅ **MDEx Integration Documentation** - AST parsing, unified ID generation, performance benefits
5. **Cross-Reference Documentation** - How to use custom link types
6. **Content Migration Report** - What was migrated and any issues
7. **Phase 3 Preparation Notes** - Recommendations for next phase

### Technical Deliverables
1. ✅ **Comprehensive Test Suite** - Tests for navigation, search, TOC, and MDEx integration (131 tests passing)
2. ✅ **Performance Benchmarks** - Navigation, search, TOC, and MDEx performance metrics  
3. ✅ **MDEx Integration Code** - AST-based parsing, unified slug generation, backward compatibility (Commit: 99d7f3a)
4. **Link Validation System** - Automated link checking and reporting
5. **Content Standards Document** - Guidelines for future content creation
6. **Deployment Documentation** - How to deploy and maintain the system

## 🎯 Phase 2 Completion Criteria

Phase 2 is considered complete when:

- ✅ **Navigation System**: Automatic navigation works across all content types
- ✅ **Search Functionality**: Real-time search covers all documentation with good performance  
- ✅ **TOC Generation**: Table of contents automatically generates with multiple formats and MDEx integration
- [ ] **Cross-References**: Custom link types work correctly and are validated
- [ ] **Content Migration**: All existing documentation is successfully migrated
- [ ] **Authentication Ready**: Basic user system is implemented for Phase 3 features
- ✅ **Performance Standards**: Navigation, search, and TOC systems meet performance benchmarks
- ✅ **Test Coverage**: Comprehensive test suite covers navigation, search, and TOC functionality
- [ ] **Documentation**: All systems are properly documented for maintenance

## 🔄 Transition to Phase 3

Upon completion of Phase 2, the system will be ready for Phase 3 (Advanced Petal + AI Integration), which will include:

- Enhanced UI with advanced Petal Components patterns
- AI-powered content generation with LiveView interface
- Interactive code examples and live documentation
- Advanced search with semantic capabilities
- Analytics and usage tracking with Ash resources

The foundation established in Phase 2 provides the navigation, search, and content organization required for these advanced features.

---

**Phase 2 Status**: 🚧 **85% COMPLETE** (Navigation ✅, Search ✅, TOC ✅, MDEx Integration ✅, Cross-References & Migration remaining)  
**Dependencies**: Phase 1 completion, MDEx theming system  
**Estimated Duration**: 2 weeks (5 days remaining for cross-references & migration)  
**Priority**: High

### 🎉 **COMPLETED MAJOR MILESTONES**:
- ✅ **Dynamic Navigation System** (Task 1.1) - File scanning, hierarchical structure, LiveView state
- ✅ **Real-Time Search** (Task 1.2) - LiveView search, indexing, filtering, ranking
- ✅ **Table of Contents Generation** (Task 1.3) - Multi-format TOC, custom templates, smooth scroll
- ✅ **TOC-MDEx Integration** (Task 2.0) - AST-based parsing, unified ID generation, performance optimization

### 📋 **REMAINING WORK**:
- **Cross-Reference System** (Task 2.1) - Custom link types, ExDoc integration, link validation
- **Content Migration** (Task 2.2) - Standards, migration scripts, asset organization