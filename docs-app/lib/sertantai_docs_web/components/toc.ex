defmodule SertantaiDocsWeb.Components.TOC do
  @moduledoc """
  Table of Contents components for documentation pages.
  
  Provides various TOC rendering options including sidebar,
  inline, and floating variations.
  """
  
  use Phoenix.Component
  import SertantaiDocsWeb.CoreComponents

  @doc """
  Renders a table of contents from a list of headings.
  
  ## Examples
  
      <.table_of_contents headings={@headings} />
      <.table_of_contents headings={@headings} title="On This Page" />
  """
  attr :headings, :list, required: true, doc: "List of heading maps with :level, :text, :id"
  attr :title, :string, default: "Table of Contents"
  attr :class, :string, default: ""
  attr :active_id, :string, default: nil
  attr :collapsible, :boolean, default: false

  def table_of_contents(assigns) do
    ~H"""
    <nav class={["table-of-contents", @class]} role="navigation" aria-label="Table of contents">
      <%= if @headings == [] do %>
        <p class="text-sm text-gray-500 italic">No table of contents available</p>
      <% else %>
        <h2 class="toc-title text-lg font-semibold mb-3"><%= @title %></h2>
        <.toc_tree tree={build_tree(@headings)} active_id={@active_id} />
      <% end %>
    </nav>
    """
  end

  @doc """
  Renders a hierarchical TOC tree.
  """
  attr :tree, :list, required: true
  attr :active_id, :string, default: nil
  attr :collapsible, :boolean, default: false

  def toc_tree(assigns) do
    ~H"""
    <ul class="toc-list space-y-1">
      <%= for node <- @tree do %>
        <li class="toc-item" data-level={node.level}>
          <div class="flex items-center">
            <%= if @collapsible && node.children != [] do %>
              <button
                phx-click="toggle-toc-section"
                phx-value-section={node.id}
                class="toc-toggle mr-1 text-gray-500 hover:text-gray-700"
              >
                <.icon name="hero-chevron-right" class="h-3 w-3" />
              </button>
            <% end %>
            
            <a
              href={"##{node.id}"}
              class={[
                "toc-link block py-1 text-sm transition-colors",
                "hover:text-indigo-600",
                if(@active_id == node.id, do: "text-indigo-600 font-medium", else: "text-gray-700")
              ]}
              data-active={@active_id == node.id}
              id={if @active_id == node.id, do: node.id}
            >
              <%= node.text %>
            </a>
          </div>
          
          <%= if node.children != [] do %>
            <div class="ml-4">
              <.toc_tree tree={node.children} active_id={@active_id} collapsible={@collapsible} />
            </div>
          <% end %>
        </li>
      <% end %>
    </ul>
    """
  end

  @doc """
  Renders a sticky TOC sidebar.
  """
  attr :toc, :map, required: true, doc: "TOC data with :tree, :headings, :flat"
  attr :sticky, :boolean, default: true
  attr :show_back_to_top, :boolean, default: false
  attr :class, :string, default: ""

  def toc_sidebar(assigns) do
    ~H"""
    <aside class={[
      "toc-sidebar",
      @sticky && "sticky top-20",
      @class
    ]}>
      <nav class="bg-gray-50 rounded-lg p-4">
        <h3 class="text-sm font-semibold text-gray-900 mb-3">On This Page</h3>
        
        <%= if @toc.tree != [] do %>
          <.toc_tree tree={@toc.tree} />
        <% else %>
          <p class="text-sm text-gray-500">No headings found</p>
        <% end %>
        
        <%= if @show_back_to_top do %>
          <div class="mt-4 pt-4 border-t border-gray-200">
            <a href="#top" class="text-sm text-indigo-600 hover:text-indigo-700 flex items-center">
              <.icon name="hero-arrow-up" class="h-3 w-3 mr-1" />
              Back to top
            </a>
          </div>
        <% end %>
      </nav>
    </aside>
    """
  end

  @doc """
  Renders an inline collapsible TOC.
  """
  attr :toc, :map, required: true
  attr :collapsed, :boolean, default: false
  attr :class, :string, default: ""

  def inline_toc(assigns) do
    ~H"""
    <div class={["inline-toc border border-gray-200 rounded-lg p-4 mb-6", @class]} data-collapsed={@collapsed}>
      <details open={!@collapsed}>
        <summary class="cursor-pointer font-medium text-gray-900 flex items-center justify-between">
          <span>Table of Contents</span>
          <span class="text-sm text-gray-500">
            <%= if @collapsed, do: "Expand", else: "Collapse" %>
          </span>
        </summary>
        
        <div class="mt-3">
          <.toc_tree tree={@toc.tree} />
        </div>
      </details>
    </div>
    """
  end

  # Private functions

  defp build_tree(headings) do
    # Convert flat list to tree if needed
    # This is a simplified version - the actual implementation would be in Extractor
    headings
    |> Enum.map(fn h -> Map.put(h, :children, []) end)
  end
end