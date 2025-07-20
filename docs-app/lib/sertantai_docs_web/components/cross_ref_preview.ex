defmodule SertantaiDocsWeb.Components.CrossRefPreview do
  @moduledoc """
  Components for rendering cross-reference links with hover previews.
  
  Provides interactive cross-reference links that show detailed preview
  information on hover, including:
  - Ash resource information
  - ExDoc module documentation
  - Internal documentation previews
  - Error handling for broken links
  """
  
  use Phoenix.Component

  @doc """
  Renders a cross-reference link with preview capabilities.
  
  ## Examples
  
      <CrossRefPreview.cross_ref_link cross_ref={@cross_ref} />
      <CrossRefPreview.cross_ref_link cross_ref={@cross_ref} class="custom-class" />
  """
  attr :cross_ref, :map, required: true, doc: "Cross-reference data with type, target, text, url, and validation info"
  attr :class, :string, default: nil, doc: "Additional CSS classes"
  attr :rest, :global, include: ~w(id data-*)

  def cross_ref_link(assigns) do
    ~H"""
    <%= if @cross_ref.valid do %>
      <a 
        href={@cross_ref.url}
        class={build_link_classes(@cross_ref, @class)}
        data-ref-type={@cross_ref.type}
        data-ref-target={@cross_ref.target}
        data-preview-enabled="true"
        data-lazy-preview={if is_nil(@cross_ref[:preview_data]), do: "true", else: "false"}
        data-preview-url={build_preview_url(@cross_ref)}
        role="button"
        aria-describedby={"preview-#{@cross_ref.target |> String.replace(".", "-")}"}
        tabindex="0"
        {@rest}
      >
        <%= @cross_ref.text %>
      </a>
    <% else %>
      <span 
        class={build_broken_link_classes(@cross_ref, @class)}
        data-ref-type={@cross_ref.type}
        data-ref-target={@cross_ref.target}
        data-error={@cross_ref.error}
        title={@cross_ref.error}
        {@rest}
      >
        <%= @cross_ref.text %>
      </span>
    <% end %>
    """
  end

  @doc """
  Renders a preview tooltip for a cross-reference.
  
  ## Examples
  
      <CrossRefPreview.preview_tooltip cross_ref={@cross_ref} />
  """
  attr :cross_ref, :map, required: true, doc: "Cross-reference data with preview information"

  def preview_tooltip(assigns) do
    ~H"""
    <div 
      class={build_preview_classes(@cross_ref)}
      id={"preview-#{@cross_ref.target |> String.replace(".", "-")}"}
      data-loading={if is_nil(@cross_ref[:preview_data]), do: "true", else: "false"}
    >
      <%= cond do %>
        <% @cross_ref[:valid] == false -> %>
          <%= render_error_preview(assigns) %>
        <% is_nil(@cross_ref[:preview_data]) -> %>
          <%= render_loading_preview(assigns) %>
        <% @cross_ref.type == :ash -> %>
          <%= render_ash_preview(assigns) %>
        <% @cross_ref.type == :exdoc -> %>
          <%= render_exdoc_preview(assigns) %>
        <% @cross_ref.type in [:dev, :user] -> %>
          <%= render_internal_preview(assigns) %>
        <% true -> %>
          <%= render_generic_preview(assigns) %>
      <% end %>
    </div>
    """
  end

  @doc """
  Returns the JavaScript code needed for cross-reference preview functionality.
  """
  def preview_javascript do
    ~S"""
    <script>
    (function() {
      const crossRefPreviewSystem = {
        debounceTimeout: null,
        debounceDelay: 150,
        previewCache: new Map(),
        activePreview: null,

        init() {
          this.bindEvents();
        },

        bindEvents() {
          document.addEventListener('mouseenter', (event) => {
            if (event.target.matches('[data-preview-enabled="true"]')) {
              this.handleMouseEnter(event);
            }
          }, true);

          document.addEventListener('mouseleave', (event) => {
            if (event.target.matches('[data-preview-enabled="true"]')) {
              this.handleMouseLeave(event);
            }
          }, true);

          document.addEventListener('focus', (event) => {
            if (event.target.matches('[data-preview-enabled="true"]')) {
              this.handleFocus(event);
            }
          }, true);

          document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape') {
              this.hidePreview();
            } else if (event.target.matches('[data-preview-enabled="true"]') && 
                      (event.key === 'Enter' || event.key === ' ')) {
              event.preventDefault();
              this.showPreview(event.target);
            }
          });
        },

        handleMouseEnter(event) {
          clearTimeout(this.debounceTimeout);
          this.debounceTimeout = setTimeout(() => {
            this.showPreview(event.target);
          }, this.debounceDelay);
        },

        handleMouseLeave(event) {
          clearTimeout(this.debounceTimeout);
          this.debounceTimeout = setTimeout(() => {
            this.hidePreview();
          }, this.debounceDelay);
        },

        handleFocus(event) {
          this.showPreview(event.target);
        },

        showPreview(element) {
          const refTarget = element.dataset.refTarget;
          const refType = element.dataset.refType;
          const cacheKey = `${refType}:${refTarget}`;

          // Check cache first
          if (this.previewCache.has(cacheKey)) {
            this.renderPreview(element, this.previewCache.get(cacheKey));
            return;
          }

          // Load preview data if needed
          if (element.dataset.lazyPreview === 'true') {
            this.loadPreviewData(element, refTarget, refType);
          } else {
            this.renderExistingPreview(element);
          }
        },

        hidePreview() {
          if (this.activePreview) {
            this.activePreview.remove();
            this.activePreview = null;
          }
        },

        loadPreviewData(element, target, type) {
          // Show loading state
          this.renderLoadingPreview(element);

          // In a real implementation, this would make an AJAX call
          // For testing, we'll simulate with a timeout
          setTimeout(() => {
            const mockData = this.generateMockPreviewData(type, target);
            this.previewCache.set(`${type}:${target}`, mockData);
            this.renderPreview(element, mockData);
          }, 100);
        },

        renderPreview(element, data) {
          this.hidePreview();

          const preview = document.createElement('div');
          preview.className = 'cross-ref-preview-tooltip';
          preview.innerHTML = data.html;

          // Position the preview
          const position = this.calculatePosition(element);
          preview.style.left = position.x + 'px';
          preview.style.top = position.y + 'px';

          document.body.appendChild(preview);
          this.activePreview = preview;
        },

        renderLoadingPreview(element) {
          this.hidePreview();

          const preview = document.createElement('div');
          preview.className = 'cross-ref-preview-tooltip cross-ref-preview-loading';
          preview.innerHTML = '<div class="preview-loading">Loading preview...</div>';

          const position = this.calculatePosition(element);
          preview.style.left = position.x + 'px';
          preview.style.top = position.y + 'px';

          document.body.appendChild(preview);
          this.activePreview = preview;
        },

        renderExistingPreview(element) {
          const previewId = element.getAttribute('aria-describedby');
          const previewElement = document.getElementById(previewId);
          
          if (previewElement) {
            this.renderPreview(element, { html: previewElement.innerHTML });
          }
        },

        calculatePosition(element) {
          const rect = element.getBoundingClientRect();
          const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
          const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft;

          let x = rect.left + scrollLeft;
          let y = rect.bottom + scrollTop + 5;

          // Adjust if preview would go off-screen
          const previewWidth = 300; // Estimated width
          const previewHeight = 200; // Estimated height

          if (x + previewWidth > window.innerWidth) {
            x = window.innerWidth - previewWidth - 10;
          }

          if (y + previewHeight > window.innerHeight + scrollTop) {
            y = rect.top + scrollTop - previewHeight - 5;
          }

          return { x, y };
        },

        generateMockPreviewData(type, target) {
          // Mock data for testing - in real implementation would come from server
          return {
            html: `<div class="cross-ref-preview cross-ref-preview-${type}">
              <div class="preview-header">${type.toUpperCase()} Preview</div>
              <div class="preview-content">Preview data for ${target}</div>
            </div>`
          };
        }
      };

      // Initialize when DOM is ready
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => crossRefPreviewSystem.init());
      } else {
        crossRefPreviewSystem.init();
      }

      // Export for external use
      window.crossRefPreviewSystem = crossRefPreviewSystem;
    })();
    </script>
    """
  end

  @doc """
  Returns the CSS styles needed for cross-reference preview functionality.
  """
  def preview_css do
    ~S"""
    <style>
    /* Base cross-reference link styles */
    .cross-ref {
      position: relative;
      text-decoration: underline;
      text-decoration-style: dotted;
      cursor: pointer;
      transition: all 0.2s ease;
    }

    .cross-ref:hover,
    .cross-ref:focus {
      text-decoration-style: solid;
    }

    /* Type-specific link styles */
    .cross-ref-ash {
      color: #059669;
      border-bottom: 1px dotted #059669;
    }

    .cross-ref-exdoc {
      color: #7c3aed;
      border-bottom: 1px dotted #7c3aed;
    }

    .cross-ref-internal {
      color: #dc2626;
      border-bottom: 1px dotted #dc2626;
    }

    .cross-ref-broken {
      color: #ef4444;
      text-decoration: line-through;
      cursor: not-allowed;
    }

    /* Preview tooltip container */
    .cross-ref-preview {
      position: absolute;
      z-index: 9999;
      background: #ffffff;
      border: 1px solid #e5e7eb;
      border-radius: 8px;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
      max-width: 300px;
      padding: 16px;
      font-size: 14px;
      line-height: 1.5;
      opacity: 0;
      transform: translateY(-5px);
      transition: opacity 0.2s ease, transform 0.2s ease;
      pointer-events: none;
    }

    .cross-ref-preview.visible {
      opacity: 1;
      transform: translateY(0);
    }

    /* Type-specific preview styles */
    .cross-ref-preview-ash {
      border-left: 4px solid #059669;
    }

    .cross-ref-preview-exdoc {
      border-left: 4px solid #7c3aed;
    }

    .cross-ref-preview-internal {
      border-left: 4px solid #dc2626;
    }

    .cross-ref-preview-error {
      border-left: 4px solid #ef4444;
      background: #fef2f2;
    }

    /* Preview content styles */
    .preview-header {
      font-weight: 600;
      color: #374151;
      margin-bottom: 8px;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    .preview-title {
      font-weight: 600;
      color: #111827;
      margin-bottom: 4px;
    }

    .preview-description {
      color: #6b7280;
      margin-bottom: 12px;
    }

    .preview-description.truncated {
      max-height: 60px;
      overflow: hidden;
      position: relative;
    }

    .preview-description.truncated::after {
      content: "Show more";
      position: absolute;
      bottom: 0;
      right: 0;
      background: linear-gradient(to right, transparent, #ffffff 50%);
      padding-left: 20px;
      color: #059669;
      cursor: pointer;
      font-size: 12px;
    }

    .preview-meta {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-bottom: 12px;
    }

    .preview-tag {
      background: #f3f4f6;
      color: #374151;
      padding: 2px 6px;
      border-radius: 4px;
      font-size: 11px;
    }

    .preview-functions,
    .preview-actions,
    .preview-sections {
      margin-top: 12px;
    }

    .preview-functions h4,
    .preview-actions h4,
    .preview-sections h4 {
      font-size: 12px;
      font-weight: 600;
      color: #374151;
      margin-bottom: 4px;
    }

    .preview-list {
      display: flex;
      flex-wrap: wrap;
      gap: 4px;
    }

    .preview-list-item {
      background: #f9fafb;
      color: #374151;
      padding: 1px 4px;
      border-radius: 3px;
      font-size: 11px;
      font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
    }

    .preview-example {
      background: #f9fafb;
      border: 1px solid #e5e7eb;
      border-radius: 4px;
      padding: 8px;
      margin-top: 8px;
      font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
      font-size: 12px;
      color: #374151;
    }

    .preview-error {
      color: #dc2626;
      font-weight: 500;
    }

    .preview-suggestions {
      margin-top: 8px;
    }

    .preview-suggestions h4 {
      font-size: 12px;
      color: #6b7280;
      margin-bottom: 4px;
    }

    .preview-suggestion {
      color: #059669;
      text-decoration: underline;
      cursor: pointer;
      margin-right: 8px;
      font-size: 12px;
    }

    .preview-loading {
      color: #6b7280;
      font-style: italic;
      text-align: center;
      padding: 20px;
    }

    .preview-unavailable {
      color: #dc2626;
      text-align: center;
      padding: 12px;
    }

    .preview-retry {
      color: #059669;
      text-decoration: underline;
      cursor: pointer;
      font-size: 12px;
      margin-top: 4px;
    }

    /* Dark mode support */
    @media (prefers-color-scheme: dark) {
      :root {
        --preview-bg-dark: #1f2937;
        --preview-text-dark: #f9fafb;
        --preview-border-dark: #374151;
      }

      .cross-ref-preview {
        background: var(--preview-bg-dark);
        border-color: var(--preview-border-dark);
        color: var(--preview-text-dark);
      }

      .cross-ref-preview-error {
        background: #7f1d1d;
      }

      .preview-header,
      .preview-title {
        color: var(--preview-text-dark);
      }

      .preview-description {
        color: #d1d5db;
      }

      .preview-tag,
      .preview-list-item {
        background: #374151;
        color: #d1d5db;
      }

      .preview-example {
        background: #374151;
        border-color: #4b5563;
        color: #d1d5db;
      }
    }

    /* High contrast mode */
    @media (prefers-contrast: high) {
      .cross-ref {
        border-width: 2px;
        font-weight: bold;
      }

      .cross-ref-preview {
        border-width: 2px;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
      }
    }

    /* Reduced motion support */
    @media (prefers-reduced-motion: reduce) {
      .cross-ref,
      .cross-ref-preview {
        transition: none;
      }
    }

    /* Focus styles for accessibility */
    .cross-ref:focus-visible {
      outline: 2px solid #059669;
      outline-offset: 2px;
    }

    /* Responsive design */
    @media (max-width: 640px) {
      .cross-ref-preview {
        max-width: 280px;
        font-size: 13px;
        padding: 12px;
      }
    }
    </style>
    """
  end

  # Private helper functions

  defp build_link_classes(%{type: type}, custom_class) do
    base_classes = ["cross-ref"]
    type_class = case type do
      :ash -> "cross-ref-ash"
      :exdoc -> "cross-ref-exdoc"
      :dev -> "cross-ref-internal"
      :user -> "cross-ref-internal"
      _ -> "cross-ref-unknown"
    end
    
    classes = base_classes ++ [type_class]
    if custom_class, do: classes ++ [custom_class], else: classes
    |> Enum.join(" ")
  end

  defp build_broken_link_classes(%{type: type}, custom_class) do
    base_classes = ["cross-ref"]
    type_class = case type do
      :ash -> "cross-ref-ash"
      :exdoc -> "cross-ref-exdoc"
      :dev -> "cross-ref-internal"
      :user -> "cross-ref-internal"
      _ -> "cross-ref-unknown"
    end
    
    classes = base_classes ++ [type_class, "cross-ref-broken"]
    if custom_class, do: classes ++ [custom_class], else: classes
    |> Enum.join(" ")
  end

  defp build_preview_classes(%{type: _type, valid: valid}) when valid == false do
    "cross-ref-preview cross-ref-preview-error"
  end

  defp build_preview_classes(%{type: type}) do
    base_class = "cross-ref-preview"
    type_class = case type do
      :ash -> "cross-ref-preview-ash"
      :exdoc -> "cross-ref-preview-exdoc"
      :dev -> "cross-ref-preview-internal"
      :user -> "cross-ref-preview-internal"
      _ -> "cross-ref-preview-generic"
    end
    
    "#{base_class} #{type_class}"
  end

  defp build_preview_url(%{type: type, target: target}) do
    "/api/preview/#{type}/#{target}"
  end

  defp render_error_preview(assigns) do
    ~H"""
    <div class="preview-header">Reference Error</div>
    <div class="preview-title"><%= @cross_ref.target %></div>
    <div class="preview-error"><%= @cross_ref.error %></div>
    <%= if @cross_ref[:suggestions] && length(@cross_ref.suggestions) > 0 do %>
      <div class="preview-suggestions">
        <h4>Did you mean:</h4>
        <%= for suggestion <- @cross_ref.suggestions do %>
          <span class="preview-suggestion"><%= suggestion %></span>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp render_loading_preview(assigns) do
    ~H"""
    <%= if @cross_ref[:loading_error] do %>
      <div class="preview-unavailable">
        <div>Preview unavailable</div>
        <div class="preview-error"><%= @cross_ref.loading_error %></div>
        <div class="preview-retry">Retry</div>
      </div>
    <% else %>
      <div class="preview-loading">Loading preview...</div>
    <% end %>
    """
  end

  defp render_ash_preview(assigns) do
    ~H"""
    <div class="preview-header">Ash Resource</div>
    <div class="preview-title"><%= @cross_ref.target %></div>
    
    <%= if @cross_ref.preview_data[:domain] do %>
      <div class="preview-meta">
        <span class="preview-tag">Domain: <%= @cross_ref.preview_data.domain %></span>
      </div>
    <% end %>
    
    <%= if @cross_ref.preview_data && @cross_ref.preview_data[:description] do %>
      <% description = @cross_ref.preview_data[:description] %>
      <div class={if String.length(description) > 200, do: "preview-description truncated", else: "preview-description"}>
        <%= description %>
      </div>
    <% end %>
    
    <%= if @cross_ref.preview_data[:actions] && length(@cross_ref.preview_data.actions) > 0 do %>
      <div class="preview-actions">
        <h4>Actions:</h4>
        <div class="preview-list">
          <%= for action <- @cross_ref.preview_data.actions do %>
            <span class="preview-list-item"><%= action %></span>
          <% end %>
        </div>
      </div>
    <% end %>
    
    <%= if @cross_ref.preview_data[:attributes] && length(@cross_ref.preview_data.attributes) > 0 do %>
      <div class="preview-actions">
        <h4>Attributes:</h4>
        <div class="preview-list">
          <%= for attr <- @cross_ref.preview_data.attributes do %>
            <span class="preview-list-item"><%= attr %></span>
          <% end %>
        </div>
      </div>
    <% end %>
    
    <%= if @cross_ref.preview_data[:relationships] && length(@cross_ref.preview_data.relationships) > 0 do %>
      <div class="preview-actions">
        <h4>Relationships:</h4>
        <div class="preview-list">
          <%= for rel <- @cross_ref.preview_data.relationships do %>
            <span class="preview-list-item"><%= rel %></span>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_exdoc_preview(assigns) do
    ~H"""
    <div class="preview-header">Elixir Module</div>
    <div class="preview-title"><%= @cross_ref.target %></div>
    
    <%= if @cross_ref.preview_data[:description] do %>
      <div class="preview-description"><%= @cross_ref.preview_data.description %></div>
    <% end %>
    
    <%= if @cross_ref.preview_data[:since] do %>
      <div class="preview-meta">
        <span class="preview-tag">Since: <%= @cross_ref.preview_data.since %></span>
      </div>
    <% end %>
    
    <%= if @cross_ref.preview_data[:functions] && length(@cross_ref.preview_data.functions) > 0 do %>
      <div class="preview-functions">
        <h4>Key Functions:</h4>
        <div class="preview-list">
          <%= for func <- @cross_ref.preview_data.functions do %>
            <span class="preview-list-item"><%= func %></span>
          <% end %>
        </div>
      </div>
    <% end %>
    
    <%= if @cross_ref.preview_data[:examples] && length(@cross_ref.preview_data.examples) > 0 do %>
      <%= for example <- Enum.take(@cross_ref.preview_data.examples, 1) do %>
        <div class="preview-example"><%= example %></div>
      <% end %>
    <% end %>
    """
  end

  defp render_internal_preview(assigns) do
    ~H"""
    <div class="preview-header">Documentation</div>
    <div class="preview-title">
      <%= @cross_ref.preview_data[:title] || @cross_ref.target %>
    </div>
    
    <%= if @cross_ref.preview_data[:category] do %>
      <div class="preview-meta">
        <span class="preview-tag"><%= @cross_ref.preview_data.category %></span>
      </div>
    <% end %>
    
    <%= if @cross_ref.preview_data[:description] do %>
      <div class="preview-description"><%= @cross_ref.preview_data.description %></div>
    <% end %>
    
    <%= if @cross_ref.preview_data[:sections] && length(@cross_ref.preview_data.sections) > 0 do %>
      <div class="preview-sections">
        <h4>Sections:</h4>
        <div class="preview-list">
          <%= for section <- @cross_ref.preview_data.sections do %>
            <span class="preview-list-item"><%= section %></span>
          <% end %>
        </div>
      </div>
    <% end %>
    
    <%= if @cross_ref.preview_data[:tags] && length(@cross_ref.preview_data.tags) > 0 do %>
      <div class="preview-meta">
        <%= for tag <- @cross_ref.preview_data.tags do %>
          <span class="preview-tag"><%= tag %></span>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp render_generic_preview(assigns) do
    ~H"""
    <div class="preview-header">Reference</div>
    <div class="preview-title"><%= @cross_ref.target %></div>
    <div class="preview-description">Cross-reference target</div>
    """
  end
end