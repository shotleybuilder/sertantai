defmodule SertantaiDocsWeb.DocLive do
  use SertantaiDocsWeb, :live_view
  import SertantaiDocsWeb.CoreComponents

  alias SertantaiDocsWeb.Navigation
  alias SertantaiDocs.MarkdownProcessor

  @impl true
  def mount(params, _session, socket) do
    category = Map.get(params, "category", "")
    page = Map.get(params, "page", "")
    
    # Get navigation items with initial state
    navigation_items = Navigation.get_navigation_items()
    
    # Initialize filter and sort state
    initial_state = %{
      filter_state: %{
        status: "",
        category: "",
        priority: "",
        author: "",
        tags: []
      },
      sort_state: %{
        sort_by: "priority",
        sort_order: "desc"
      }
    }
    
    # Calculate filtered/sorted navigation for sidebar
    {filtered_items, total_count, filtered_count} = apply_filters_and_sort(navigation_items, initial_state)
    
    socket = 
      socket
      |> assign(:category, category)
      |> assign(:page, page)
      |> assign(:navigation_items, navigation_items)
      |> assign(:filtered_navigation_items, filtered_items)
      |> assign(:total_count, total_count)
      |> assign(:filtered_count, filtered_count)
      |> assign(:filter_state, initial_state.filter_state)
      |> assign(:sort_state, initial_state.sort_state)
      |> assign(:available_sort_options, get_sort_options())
      |> load_page_content()
    
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-full bg-white">
      <!-- Sidebar Navigation with LiveView state -->
      <.nav_sidebar 
        items={@navigation_items}
        current_path={@current_path}
        filter_state={@filter_state}
        sort_state={@sort_state}
        available_sort_options={@available_sort_options}
        total_count={@total_count}
        filtered_count={@filtered_count}
      />
      
      <!-- Main Content Area (header is handled by app layout) -->
      <div class="flex-1 flex flex-col overflow-hidden">        
        <!-- Main Content -->
        <main class="flex-1 overflow-y-auto">
          <div class="documentation-page">
            <.doc_content>
              <.breadcrumb 
                items={[
                  %{title: "Documentation", path: "/"},
                  %{title: String.capitalize(@category), path: "/#{@category}"},
                  %{title: @page, path: nil}
                ]}
                class="mb-6"
              />
              
              <.doc_header 
                title={@metadata["title"] || String.capitalize(@page)}
                description={@metadata["description"]}
                category={@category}
                tags={@metadata["tags"] || []}
              />
              
              <article class="prose prose-lg max-w-none">
                <%= raw @content %>
              </article>
            </.doc_content>
          </div>
        </main>
      </div>
    </div>
    """
  end

  @impl true 
  def handle_event("change-sort", %{"value" => sort_by}, socket) do
    new_sort_state = %{socket.assigns.sort_state | sort_by: sort_by}
    socket = 
      socket
      |> assign(:sort_state, new_sort_state)
      |> update_navigation()
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle-sort-order", _params, socket) do
    new_order = case socket.assigns.sort_state.sort_order do
      "asc" -> "desc"
      "desc" -> "asc"
      :asc -> :desc
      :desc -> :asc
      _ -> "asc"
    end
    
    new_sort_state = %{socket.assigns.sort_state | sort_order: new_order}
    socket = 
      socket
      |> assign(:sort_state, new_sort_state)
      |> update_navigation()
    {:noreply, socket}
  end

  # Handle other filter/sort events that nav_sidebar might send
  @impl true
  def handle_event("filter-status", %{"value" => status}, socket) do
    new_filter_state = %{socket.assigns.filter_state | status: status}
    socket = 
      socket
      |> assign(:filter_state, new_filter_state)
      |> update_navigation()
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter-category", %{"value" => category}, socket) do
    new_filter_state = %{socket.assigns.filter_state | category: category}
    socket = 
      socket
      |> assign(:filter_state, new_filter_state)
      |> update_navigation()
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter-priority", %{"value" => priority}, socket) do
    new_filter_state = %{socket.assigns.filter_state | priority: priority}
    socket = 
      socket
      |> assign(:filter_state, new_filter_state)
      |> update_navigation()
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset-filters", _params, socket) do
    reset_filter_state = %{
      status: "",
      category: "",
      priority: "",
      author: "",
      tags: []
    }
    socket = 
      socket
      |> assign(:filter_state, reset_filter_state)
      |> update_navigation()
    {:noreply, socket}
  end

  # Catch-all for unhandled events
  @impl true
  def handle_event(event_name, params, socket) do
    # Log unhandled events for debugging
    require Logger
    Logger.debug("Unhandled event in DocLive: #{event_name}, params: #{inspect(params)}")
    {:noreply, socket}
  end

  # Private functions
  
  defp load_page_content(socket) do
    category = socket.assigns.category
    page = socket.assigns.page
    
    try do
      # Use relative path like DocController does
      file_path = "#{category}/#{page}.md"
      
      case MarkdownProcessor.process_file(file_path) do
        {:ok, content, metadata} ->
          socket
          |> assign(:content, content)
          |> assign(:metadata, metadata)
          |> assign(:current_path, "/#{category}/#{page}")
        
        {:error, reason} ->
          socket
          |> assign(:content, "<p>Error loading content: #{inspect(reason)}</p>")
          |> assign(:metadata, %{})
          |> assign(:current_path, "/#{category}/#{page}")
      end
    rescue
      error ->
        socket
        |> assign(:content, "<p>Error: #{inspect(error)}</p>")
        |> assign(:metadata, %{})
        |> assign(:current_path, "/#{category}/#{page}")
    end
  end
  
  defp get_sort_options do
    [
      %{value: "priority", label: "Priority"},
      %{value: "title", label: "Title"},
      %{value: "date_modified", label: "Date Modified"},
      %{value: "category", label: "Category"}
    ]
  end
  
  defp update_navigation(socket) do
    state = %{
      filter_state: socket.assigns.filter_state,
      sort_state: socket.assigns.sort_state
    }
    
    {filtered_items, total_count, filtered_count} = 
      apply_filters_and_sort(socket.assigns.navigation_items, state)
    
    socket
    |> assign(:filtered_navigation_items, filtered_items)
    |> assign(:total_count, total_count)
    |> assign(:filtered_count, filtered_count)
  end
  
  defp apply_filters_and_sort(navigation_items, state) do
    # For now, return the items as-is with counts
    # This would be where you'd apply the actual filtering and sorting logic
    total_count = length(navigation_items)
    
    # Simple filtering simulation - in practice you'd implement proper filtering
    filtered_items = navigation_items
    filtered_count = total_count
    
    {filtered_items, total_count, filtered_count}
  end
end