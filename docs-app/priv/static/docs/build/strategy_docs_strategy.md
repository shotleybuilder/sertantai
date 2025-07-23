# Unified Documentation Strategy for Sertantai

## Executive Summary

This strategy combines comprehensive documentation management with cost-efficient AI integration for the Sertantai Elixir Phoenix project. The approach leverages a native Phoenix-based documentation application with Ash Framework integration, Petal Components styling, and MDEx markdown processing, creating a seamless documentation experience that stays entirely within the Elixir ecosystem.

## Core Principles

- **Single Source of Truth (SSOT)**: Avoid duplicating information. Link extensively between developer and user docs
- **Elixir Ecosystem Native**: Leverage native Elixir tools (ExDoc, Phoenix, Ash, Petal Components) for maximum compatibility and maintainability
- **Markdown First**: Easy to write, version control, and render with MDEx for superior performance and features
- **Ash Framework Integration**: Use Ash resources for content management, user authentication, and advanced documentation features
- **Petal Components Styling**: Consistent UI/UX with the main application through shared component library
- **Automation**: Leverage Mix/ExDoc for API docs and AI for content generation and maintenance
- **User-Centric**: Clearly separate and tailor content for developer and end-user audiences
- **Cost-Efficient**: Prioritize free/open-source tools and services, especially for public GitHub repos
- **Seamless Integration**: Documentation site integrates naturally with main application through shared technology stack

## I. Dual Phoenix Architecture

### 1. Main Application (sertantai)
- **Purpose**: Core business application with full LiveView functionality
- **Location**: Current repository at `/`
- **Documentation Role**: Houses source documentation files and ExDoc comments

### 2. Documentation Site (sertantai-docs)
- **Purpose**: Dedicated Phoenix application for documentation presentation
- **Technology**: Phoenix with optional LiveView for interactive features, Ash Framework for data management
- **Location**: Subdirectory at `/docs-app/` (recommended for shared repository approach)
- **Core Stack**:
  - **MDEx**: Fast, Rust-based markdown processing with GitHub Flavored Markdown support
  - **Petal Components**: Consistent UI styling with main application
  - **Ash Framework**: Content management, user authentication, and advanced features
  - **LiveView**: Interactive documentation features (search, live examples, feedback)
- **Features**:
  - High-performance markdown rendering with syntax highlighting
  - Dynamic navigation generation from file structure
  - Integrated search functionality
  - User authentication and personalized documentation
  - Real-time content updates
  - Integration with main app's ExDoc output

### 3. Integration Strategy

#### Option A: Shared GitHub Repository (Recommended)
```
sertantai/
├── lib/                    # Main application
├── docs/                   # Source documentation files
├── docs-app/               # Phoenix docs application with Ash & Petal
│   ├── lib/
│   │   └── sertantai_docs/
│   │       ├── application.ex
│   │       ├── docs/        # Ash resources for content management
│   │       └── repo.ex      # Optional: if persisting user data/analytics
│   ├── lib/sertantai_docs_web/
│   │   ├── controllers/
│   │   ├── live/           # LiveView components for interactive features
│   │   └── components/     # Petal Components integration
│   ├── priv/
│   │   └── static/docs/    # Markdown files organized by type
│   │       ├── dev/
│   │       └── user/
│   ├── assets/             # TailwindCSS + Petal Components styling
│   └── mix.exs
└── .github/
    └── workflows/
        ├── main-app.yml    # Main app CI/CD
        └── docs.yml        # Docs site deployment
```

#### Option B: Separate Repository
- Main app: `github.com/yourorg/sertantai`
- Docs site: `github.com/yourorg/sertantai-docs`
- Use GitHub submodules or API integration for content sync

## II. Documentation Site Technical Implementation

### 1. Phoenix Documentation Application Stack

```elixir
# mix.exs for docs-app
defp deps do
  [
    # Phoenix Framework
    {:phoenix, "~> 1.7.0"},
    {:phoenix_html, "~> 3.3"},
    {:phoenix_live_view, "~> 0.20.0"},
    {:phoenix_live_reload, "~> 1.2", only: :dev},
    
    # Ash Framework for data management
    {:ash, "~> 3.0"},
    {:ash_phoenix, "~> 2.0"},
    {:ash_postgres, "~> 2.0"},    # Optional: if persisting user data
    
    # Markdown processing (modern, fast alternative to Earmark)
    {:mdex, "~> 0.8"},
    
    # UI Components and styling
    {:petal_components, "~> 1.8"},
    {:heroicons, "~> 0.5"},
    
    # Core dependencies
    {:jason, "~> 1.2"},
    {:plug_cowboy, "~> 2.5"},
    
    # Documentation integration
    {:ex_doc, "~> 0.30", only: :dev},
    
    # Development and testing
    {:floki, ">= 0.30.0", only: :test},
    {:phoenix_live_dashboard, "~> 0.8.0", only: :dev}
  ]
end
```

### 2. Core Features

#### MDEx Markdown Processing Pipeline
```elixir
defmodule SertantaiDocs.MarkdownProcessor do
  @moduledoc """
  High-performance markdown processing using MDEx with GitHub Flavored Markdown,
  syntax highlighting, and cross-references to main application ExDoc.
  """
  
  alias MDEx
  
  def process_file(file_path) do
    content = File.read!(file_path)
    {frontmatter, markdown} = extract_frontmatter(content)
    
    # MDEx configuration for optimal documentation rendering
    options = [
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true
      ],
      parse: [
        smart: true,
        relaxed_tasklist_matching: true
      ],
      render: [
        unsafe: true,  # Allow HTML in markdown for advanced formatting
        escape: false,
        github_pre_lang: true,
        hardbreaks: false
      ]
    ]
    
    html_content = 
      markdown
      |> process_cross_references()
      |> MDEx.to_html!(options)
      |> inject_metadata(frontmatter)
      |> enhance_code_blocks()
    
    {:ok, html_content, frontmatter}
  end
  
  # Process Ash resource references and ExDoc links
  defp process_cross_references(markdown) do
    markdown
    |> String.replace(~r/\[([^\]]+)\]\(ash:([^)]+)\)/, fn _, text, resource ->
      "<a href=\"/api/#{resource}.html\" class=\"ash-resource-link\">#{text}</a>"
    end)
    |> String.replace(~r/\[([^\]]+)\]\(exdoc:([^)]+)\)/, fn _, text, module ->
      "<a href=\"/api/#{module}.html\" class=\"exdoc-link\">#{text}</a>"
    end)
  end
  
  # Enhanced syntax highlighting for Elixir code blocks
  defp enhance_code_blocks(html) do
    # Additional processing for interactive code examples
    # Could integrate with LiveView for live code execution
    html
  end
end
```

#### Ash Framework Integration for Content Management
```elixir
# Ash resource for documentation content management
defmodule SertantaiDocs.Docs.Article do
  use Ash.Resource,
    domain: SertantaiDocs.Docs,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false
    attribute :slug, :string, allow_nil?: false
    attribute :content_path, :string, allow_nil?: false
    attribute :category, :atom, constraints: [one_of: [:dev, :user, :api]]
    attribute :tags, {:array, :string}, default: []
    attribute :last_modified, :utc_datetime
    attribute :view_count, :integer, default: 0
    timestamps()
  end

  actions do
    defaults [:read, :destroy]
    
    create :create do
      accept [:title, :slug, :content_path, :category, :tags]
    end
    
    update :update do
      accept [:title, :content_path, :tags]
    end
    
    update :increment_views do
      change increment(:view_count, by: 1)
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end

# Integration module leveraging Ash for content management
defmodule SertantaiDocs.Integration do
  @moduledoc """
  Handles integration with main Sertantai application using Ash Framework.
  """
  
  alias SertantaiDocs.Docs.Article
  
  def fetch_api_docs do
    # Fetch generated ExDoc content from main app
    # Can be done via file system, API, or build artifact
    # Store metadata in Ash resources for enhanced functionality
  end
  
  def sync_documentation do
    # Synchronize docs/ content from main repository
    # Update Ash resources with metadata for search and navigation
    # Triggered by GitHub webhooks or scheduled jobs
  end
  
  def get_article_by_slug(slug) do
    Article
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.read_one()
  end
  
  def increment_article_views(article) do
    Ash.update(article, :increment_views)
  end
end
```

### 3. Petal Components Integration and Content Organization

```
docs-app/
├── lib/
│   ├── sertantai_docs/
│   │   ├── application.ex
│   │   ├── docs/              # Ash domain for documentation
│   │   │   ├── article.ex     # Ash resource for articles
│   │   │   ├── user.ex        # User management (optional)
│   │   │   └── analytics.ex   # Usage analytics (optional)
│   │   ├── markdown_processor.ex
│   │   └── integration.ex
│   └── sertantai_docs_web/
│       ├── controllers/
│       │   └── doc_controller.ex
│       ├── live/              # LiveView components
│       │   ├── doc_live.ex    # Main documentation viewer
│       │   ├── search_live.ex # Real-time search
│       │   └── nav_live.ex    # Dynamic navigation
│       ├── components/        # Petal Components integration
│       │   ├── core_components.ex
│       │   ├── doc_components.ex
│       │   └── layout_components.ex
│       └── templates/
│           └── layout/
│               └── docs.html.heex  # Petal-styled layout
├── priv/
│   ├── static/docs/          # Markdown files
│   │   ├── dev/
│   │   └── user/
│   └── repo/                 # Database migrations (if using Ash with DB)
└── assets/
    ├── css/
    │   ├── app.css           # Main styles with Petal Components
    │   └── docs.css          # Documentation-specific styles
    ├── js/
    │   ├── app.js            # LiveView integration
    │   └── search.js         # Enhanced search functionality
    └── tailwind.config.js    # Petal Components + custom configuration
```

#### Petal Components Documentation Layout Example
```elixir
# lib/sertantai_docs_web/components/layout_components.ex
defmodule SertantaiDocsWeb.LayoutComponents do
  use Phoenix.Component
  import PetalComponents.{Button, Container, Card, Badge}
  
  def docs_layout(assigns) do
    ~H"""
    <.container class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex flex-col lg:flex-row gap-8">
        <!-- Sidebar Navigation with Petal Components -->
        <aside class="lg:w-64 lg:flex-shrink-0">
          <.card class="sticky top-4">
            <.docs_navigation sections={@navigation_sections} current_path={@current_path} />
          </.card>
        </aside>
        
        <!-- Main Content Area -->
        <main class="flex-1 min-w-0">
          <article class="prose prose-lg max-w-none">
            <%= render_slot(@inner_block) %>
          </article>
          
          <!-- Feedback Section -->
          <.docs_feedback article_id={@article_id} />
        </main>
        
        <!-- Table of Contents -->
        <aside class="hidden xl:block xl:w-64 xl:flex-shrink-0">
          <.docs_toc content={@toc} />
        </aside>
      </div>
    </.container>
    """
  end
  
  def docs_navigation(assigns) do
    ~H"""
    <nav class="space-y-2">
      <%= for section <- @sections do %>
        <div class="space-y-1">
          <.badge color="primary" variant="outline" class="w-full justify-start">
            <%= section.title %>
          </.badge>
          <%= for item <- section.items do %>
            <.button
              variant={if(@current_path == item.path, do: "solid", else: "ghost")}
              color="gray"
              size="sm"
              class="w-full justify-start"
              link_type="live_patch"
              to={item.path}
            >
              <%= item.title %>
            </.button>
          <% end %>
        </div>
      <% end %>
    </nav>
    """
  end
end
```

## III. Content Strategy

### 1. Developer Documentation (`docs/dev/`)
- **API Reference**: Generated by ExDoc, integrated into docs site
- **Architecture Overview**: High-level design, Ash resources, LiveView structure
- **Setup and Local Development**: Environment setup, database configuration
- **Contribution Guidelines**: PR process, coding standards, testing requirements
- **Testing Strategy**: Test organization, Ash testing patterns, CI/CD
- **Deployment Guides**: Production deployment, environment configuration
- **Troubleshooting**: Common issues, debugging techniques

### 2. User Documentation (`docs/user/`)
- **Getting Started**: Account setup, basic navigation
- **Feature Guides**: Detailed feature explanations with screenshots
- **How-To Guides**: Task-oriented instructions
- **FAQ**: Common questions and solutions
- **Advanced Usage**: Power user features
- **API Usage**: Public API documentation for integrations

### 3. Cross-Reference Integration
```markdown
<!-- Example of cross-referencing ExDoc from user docs -->
For detailed API information, see [Sertantai.Accounts.User](api/Sertantai.Accounts.User.html).

<!-- Link to implementation details -->
Technical implementation details are available in the [developer documentation](dev/architecture.md#user-management).
```

## IV. Enhanced AI Integration Strategy

### 1. Native Elixir AI Integration
- **Elixir-Based Content Generation**: Use HTTP clients to call LLM APIs directly from Elixir applications
- **LiveView AI Tools**: Real-time content generation and preview within the documentation app
- **Mix Tasks for AI**: Custom Mix tasks for automated documentation generation and maintenance

#### Example: LiveView AI Documentation Assistant
```elixir
defmodule SertantaiDocsWeb.AIAssistantLive do
  use SertantaiDocsWeb, :live_view
  import PetalComponents.{Button, Input, Card, Alert}

  def render(assigns) do
    ~H"""
    <.card>
      <h2 class="text-xl font-semibold mb-4">AI Documentation Assistant</h2>
      
      <.input
        type="textarea"
        placeholder="Describe what documentation you need..."
        value={@prompt}
        phx-change="update_prompt"
        rows="4"
      />
      
      <.button 
        color="primary" 
        phx-click="generate_content"
        loading={@generating}
        class="mt-4"
      >
        Generate Documentation
      </.button>
      
      <%= if @generated_content do %>
        <div class="mt-6">
          <h3 class="text-lg font-medium mb-2">Generated Content (MDEx Preview)</h3>
          <div class="prose max-w-none border rounded-lg p-4">
            <%= raw @generated_content %>
          </div>
          
          <.button color="success" phx-click="save_content" class="mt-4">
            Save as Markdown File
          </.button>
        </div>
      <% end %>
    </.card>
    """
  end
end
```

### 2. Advanced Content Generation
- **Code Example Generation**: AI-generated Elixir/Phoenix examples with Ash Framework patterns
- **Interactive Documentation**: LiveView components for live code execution and testing
- **Automated API Documentation Enhancement**: AI-powered improvements to ExDoc comments

### 3. Intelligent Content Management
- **Semantic Search**: Use embeddings for meaning-based documentation search
- **Content Recommendations**: Suggest related documentation based on user context
- **Automated Content Updates**: Monitor code changes and suggest documentation updates
- **Translation Support**: Multi-language documentation generation

## V. Deployment and CI/CD

### 1. GitHub Actions Workflow

```yaml
# .github/workflows/docs.yml
name: Documentation Site Deployment

on:
  push:
    branches: [main]
    paths: 
      - 'docs/**'
      - 'docs-site/**'
      - 'lib/**' # For ExDoc regeneration

jobs:
  deploy-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      # Build main app ExDoc
      - name: Generate API Documentation
        run: |
          cd .
          mix deps.get
          mix docs
          
      # Build docs site
      - name: Build Documentation Site
        run: |
          cd docs-site
          mix deps.get
          mix assets.deploy
          mix phx.digest
          
      # Deploy to GitHub Pages or hosting service
      - name: Deploy to Production
        run: |
          # Deploy docs-site to hosting platform
```

### 2. Hosting Options

#### Option A: GitHub Pages + Phoenix Static Generation
- Generate static HTML from Phoenix docs site
- Deploy to GitHub Pages for free hosting
- Custom domain support

#### Option B: Dedicated Hosting (Fly.io/Railway)
- Deploy Phoenix docs site as lightweight application
- Real-time features (search, feedback)
- Custom authentication if needed

#### Option C: Hybrid Approach
- Static content on GitHub Pages
- Dynamic features via separate service

## VI. Integration Patterns

### 1. Content Synchronization
```elixir
# Automatic sync from main app to docs site
defmodule SertantaiDocs.ContentSync do
  def sync_from_main_repo do
    # Webhook handler for main repo changes
    # Updates documentation content
    # Triggers rebuild
  end
  
  def sync_exdoc_content do
    # Pulls latest ExDoc generation
    # Integrates with docs site navigation
  end
end
```

### 2. Cross-Application Linking
```elixir
# Helper for generating links between apps
defmodule SertantaiDocs.LinkHelper do
  def main_app_url(path), do: "#{main_app_base()}/#{path}"
  def docs_url(path), do: "#{docs_base()}/#{path}"
  def api_doc_url(module), do: "#{docs_base()}/api/#{module}.html"
end
```

### 3. Shared Authentication (Optional)
```elixir
# If authentication is needed for private docs
defmodule SertantaiDocs.Auth do
  def verify_token(token) do
    # Verify token against main application
    # Could use JWT, API calls, or shared database
  end
end
```

## VII. Implementation Roadmap

### Phase 1: Phoenix + Ash Foundation (Week 1-2)
1. Create Phoenix docs application with Ash Framework integration
2. Set up MDEx markdown processing pipeline
3. Implement basic Petal Components layout and styling
4. Configure Ash resources for content management
5. Set up database (optional) for user analytics and content metadata

### Phase 2: Core Documentation Features (Week 3-4)
1. Implement dynamic navigation using file system scanning
2. Create LiveView components for real-time search
3. Set up cross-reference system between docs and ExDoc
4. Migrate existing documentation to new MDEx-based structure
5. Implement basic authentication (if needed) using Ash authentication

### Phase 3: Advanced Petal + AI Integration (Week 5-6)
1. Enhance UI with advanced Petal Components patterns
2. Implement AI-powered content generation with LiveView interface
3. Create interactive code examples and documentation
4. Set up automated content synchronization with main repository
5. Add analytics and usage tracking with Ash resources

### Phase 4: Production Optimization (Week 7-8)
1. Optimize performance for large documentation sets
2. Implement advanced search with semantic capabilities
3. Add feedback collection and content improvement workflows
4. Set up comprehensive CI/CD for both applications
5. Create documentation for the documentation system itself

## VIII. Cost Optimization

### 1. Infrastructure Costs
- **GitHub Pages**: Free for public repositories
- **Fly.io/Railway**: ~$5-10/month for docs site hosting
- **Domain**: ~$12/year for custom domain

### 2. AI Integration Costs
- **OpenAI API**: Pay-per-use for content generation (~$20-50/month)
- **Local LLMs**: Free using Ollama or similar tools
- **GitHub Copilot**: $10/month for AI-assisted writing

### 3. Maintenance Costs
- **Automated**: CI/CD handles most deployment and updates
- **Manual**: ~2-4 hours/week for content review and updates
- **Community**: Encourage community contributions to reduce maintenance burden

## IX. Success Metrics

### 1. Developer Adoption
- API documentation usage analytics
- Contribution guide effectiveness (PR quality, time to first contribution)
- Developer onboarding time reduction

### 2. User Engagement
- Documentation page views and time spent
- User support ticket reduction
- Feature adoption rates after documentation publication

### 3. Maintenance Efficiency
- Documentation update frequency
- Time from feature release to documentation publication
- Community contribution rates

## X. Key Advantages of This Native Elixir Approach

### 1. **Technology Stack Consistency**
- Complete Elixir/Phoenix ecosystem integration
- Shared knowledge and tooling with main application
- Consistent build, deployment, and monitoring processes
- No context switching between different technologies

### 2. **Enhanced Integration Capabilities**
- **Ash Framework**: Powerful content management and user authentication
- **Petal Components**: Consistent UI/UX with main application
- **MDEx**: Superior markdown processing with GitHub Flavored Markdown support
- **LiveView**: Real-time, interactive documentation features without complex JavaScript

### 3. **Advanced Features Made Simple**
- Real-time search with LiveView
- Interactive code examples and live documentation
- User analytics and content management through Ash resources
- AI-powered content generation integrated natively
- Dynamic navigation and content organization

### 4. **Maintenance and Scalability Benefits**
- Single team can maintain both applications
- Shared dependencies and security updates
- Native performance optimizations
- Easy feature expansion using familiar tools

## XI. Conclusion

This unified documentation strategy leverages the full power of the Elixir ecosystem to create a documentation platform that is not just a static site, but a living, interactive extension of the Sertantai application. By using Phoenix with Ash Framework, Petal Components, and MDEx, we create a documentation experience that:

- **Feels Native**: Users experience consistent design and interaction patterns
- **Performs Exceptionally**: Rust-based MDEx processing and Phoenix's performance
- **Scales Effortlessly**: Ash Framework's powerful data management capabilities
- **Integrates Seamlessly**: Shared technology stack enables deep integration
- **Evolves Continuously**: AI assistance and automation reduce maintenance overhead

The strategy transforms documentation from a separate concern into an integral part of the development ecosystem, where updates are automated, content is dynamic, and the user experience matches the quality of the main application. This approach not only serves current documentation needs but provides a foundation for advanced features like personalized documentation, real-time collaboration, and AI-assisted content generation.