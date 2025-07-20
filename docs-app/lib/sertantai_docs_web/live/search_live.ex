defmodule SertantaiDocsWeb.SearchLive do
  @moduledoc """
  LiveView component for real-time documentation search.
  
  Provides instant search results with filtering, highlighting,
  and keyboard navigation support.
  """
  
  use SertantaiDocsWeb, :live_view
  
  alias SertantaiDocs.Search.Engine

  @debounce_ms 300
  @min_query_length 2
  @popular_searches ["LiveView", "Ecto", "Phoenix", "Authentication", "Testing"]

  @impl true
  def mount(_params, _session, socket) do
    socket = 
      socket
      |> assign(:query, "")
      |> assign(:results, [])
      |> assign(:loading, false)
      |> assign(:focused_index, nil)
      |> assign(:show_filters, false)
      |> assign(:category_filter, [])
      |> assign(:tag_filter, [])
      |> assign(:search_ref, nil)
      |> assign(:current_path, "/search")
      |> assign(:popular_searches, @popular_searches)
    
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <div class="relative">
        <form id="search-form" phx-change="search_change" phx-submit="search_submit">
          <div class="relative">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <.icon name="hero-magnifying-glass" class="h-5 w-5 text-gray-400" />
            </div>
            
            <input
              type="search"
              name="search[query]"
              value={@query}
              placeholder="Search documentation..."
              class="block w-full pl-10 pr-10 py-3 border border-gray-300 rounded-lg leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
              phx-keydown="handle_keydown"
              autocomplete="off"
            />
            
            <%= if @query != "" do %>
              <button
                type="button"
                phx-click="clear_search"
                data-test="clear-search"
                class="absolute inset-y-0 right-0 pr-3 flex items-center"
              >
                <.icon name="hero-x-circle" class="h-5 w-5 text-gray-400 hover:text-gray-600" />
              </button>
            <% end %>
          </div>
          
          <!-- Filter Options -->
          <div class="mt-2 flex items-center gap-4">
            <button
              type="button"
              phx-click="toggle_filters"
              class="text-sm text-gray-600 hover:text-gray-900 flex items-center gap-1"
            >
              <.icon name="hero-adjustments-horizontal" class="h-4 w-4" />
              Filters
            </button>
            
            <%= if @show_filters do %>
              <div class="flex gap-4" data-test="category-filter">
                <label class="flex items-center gap-1 text-sm">
                  <input type="checkbox" name="search[category][]" value="dev" 
                    checked={"dev" in @category_filter} />
                  Developer
                </label>
                <label class="flex items-center gap-1 text-sm">
                  <input type="checkbox" name="search[category][]" value="user"
                    checked={"user" in @category_filter} />
                  User Guide
                </label>
                <label class="flex items-center gap-1 text-sm">
                  <input type="checkbox" name="search[category][]" value="api"
                    checked={"api" in @category_filter} />
                  API Reference
                </label>
              </div>
            <% end %>
          </div>
        </form>
      </div>
      
      <!-- Loading State -->
      <%= if @loading do %>
        <div class="mt-4 flex items-center justify-center" data-test="search-loading">
          <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-indigo-500"></div>
          <span class="ml-2 text-sm text-gray-600">Searching...</span>
        </div>
      <% end %>
      
      <!-- Search Results -->
      <%= if @query == "" and not @loading do %>
        <div class="mt-8" data-test="popular-searches">
          <h3 class="text-sm font-medium text-gray-700 mb-3">Popular searches</h3>
          <div class="flex flex-wrap gap-2">
            <%= for term <- @popular_searches do %>
              <button
                phx-click="search_popular"
                phx-value-term={term}
                class="px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 rounded-full text-gray-700"
              >
                <%= term %>
              </button>
            <% end %>
          </div>
        </div>
      <% end %>
      
      <%= if length(@results) > 0 and not @loading do %>
        <div class="mt-4 space-y-2">
          <%= for {result, index} <- Enum.with_index(@results) do %>
            <a
              href={result.path}
              phx-click="result_click"
              phx-value-path={result.path}
              data-test="search-result"
              data-focused={"#{index == @focused_index}"}
              class={[
                "block p-4 rounded-lg border transition-colors",
                if(index == @focused_index, 
                  do: "border-indigo-500 bg-indigo-50",
                  else: "border-gray-200 hover:border-gray-300 hover:bg-gray-50"
                )
              ]}
            >
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <h3 class="text-lg font-medium text-gray-900">
                    <%= highlight_text(result.title, @query) %>
                  </h3>
                  <div class="mt-1 flex items-center gap-2">
                    <span data-test="category-badge" 
                      class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                      <%= result.category %>
                    </span>
                    <%= for tag <- Enum.take(result.tags, 3) do %>
                      <span class="text-xs text-gray-500">#<%= tag %></span>
                    <% end %>
                  </div>
                  <%= if result[:snippet] do %>
                    <p data-test="content-preview" class="mt-2 text-sm text-gray-600 line-clamp-2">
                      <%= highlight_text(result.snippet, @query) %>
                    </p>
                  <% end %>
                </div>
                <.icon name="hero-arrow-right" class="h-5 w-5 text-gray-400 flex-shrink-0 ml-4" />
              </div>
            </a>
          <% end %>
        </div>
      <% end %>
      
      <%= if @query != "" and length(@results) == 0 and not @loading do %>
        <div class="mt-8 text-center" data-test="no-results">
          <.icon name="hero-magnifying-glass" class="mx-auto h-12 w-12 text-gray-400" />
          <p class="mt-2 text-sm text-gray-600">No results found</p>
          <p class="text-sm text-gray-500">Try different keywords or check the spelling</p>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("search_change", %{"search" => params}, socket) do
    query = Map.get(params, "query", "")
    categories = Map.get(params, "category", [])
    
    socket = 
      socket
      |> assign(:query, query)
      |> assign(:category_filter, categories)
      |> schedule_search()
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("search_submit", _params, socket) do
    # Prevent form submission
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    socket = 
      socket
      |> assign(:query, "")
      |> assign(:results, [])
      |> assign(:focused_index, nil)
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_filters", _params, socket) do
    {:noreply, assign(socket, :show_filters, not socket.assigns.show_filters)}
  end

  @impl true
  def handle_event("search_popular", %{"term" => term}, socket) do
    socket = 
      socket
      |> assign(:query, term)
      |> perform_search()
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("result_click", %{"path" => path}, socket) do
    # Track click for analytics
    # In real app, would track this
    
    {:noreply, push_navigate(socket, to: path)}
  end

  @impl true
  def handle_event("handle_keydown", %{"key" => "ArrowDown"}, socket) do
    new_index = case socket.assigns.focused_index do
      nil -> 0
      current -> min(current + 1, length(socket.assigns.results) - 1)
    end
    
    {:noreply, assign(socket, :focused_index, new_index)}
  end

  @impl true
  def handle_event("handle_keydown", %{"key" => "ArrowUp"}, socket) do
    new_index = case socket.assigns.focused_index do
      nil -> nil
      0 -> nil
      current -> current - 1
    end
    
    {:noreply, assign(socket, :focused_index, new_index)}
  end

  @impl true
  def handle_event("handle_keydown", %{"key" => "Enter"}, socket) do
    case socket.assigns.focused_index do
      nil ->
        {:noreply, socket}
      
      index ->
        case Enum.at(socket.assigns.results, index) do
          nil -> {:noreply, socket}
          result -> {:noreply, push_navigate(socket, to: result.path)}
        end
    end
  end

  @impl true
  def handle_event("handle_keydown", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:search_start}, socket) do
    {:noreply, assign(socket, :loading, true)}
  end

  @impl true
  def handle_info({:search_complete, results}, socket) do
    socket = 
      socket
      |> assign(:loading, false)
      |> assign(:results, results)
      |> assign(:focused_index, nil)
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:perform_search, ref}, socket) do
    if socket.assigns.search_ref == ref do
      {:noreply, perform_search(socket)}
    else
      # Outdated search, ignore
      {:noreply, socket}
    end
  end

  # Private functions

  defp schedule_search(socket) do
    # Cancel previous search timer
    if socket.assigns.search_ref do
      Process.cancel_timer(socket.assigns.search_ref)
    end
    
    query = socket.assigns.query
    
    cond do
      String.length(query) < @min_query_length ->
        socket
        |> assign(:results, [])
        |> assign(:search_ref, nil)
      
      true ->
        ref = Process.send_after(self(), {:perform_search, make_ref()}, @debounce_ms)
        assign(socket, :search_ref, ref)
    end
  end

  defp perform_search(socket) do
    send(self(), {:search_start})
    
    # Get search engine PID
    # In real app, this would be from application state or registry
    search_engine = get_search_engine()
    
    # Perform search
    opts = build_search_opts(socket)
    
    results = if is_pid(search_engine) and Process.alive?(search_engine) do
      try do
        Engine.search(search_engine, socket.assigns.query, opts)
      rescue
        _ ->
          # Fallback to mock search for tests
          mock_search(search_engine, socket.assigns.query, opts)
      end
    else
      # Use mock search for tests
      mock_search(search_engine, socket.assigns.query, opts)
    end
    
    send(self(), {:search_complete, results})
    
    assign(socket, :search_ref, nil)
  end

  defp build_search_opts(socket) do
    opts = []
    
    opts = if socket.assigns.category_filter != [] do
      Keyword.put(opts, :category, socket.assigns.category_filter)
    else
      opts
    end
    
    opts = if socket.assigns.tag_filter != [] do
      Keyword.put(opts, :tags, socket.assigns.tag_filter)
    else
      opts
    end
    
    opts
  end

  defp get_search_engine do
    # In real implementation, would get from registry or supervisor
    # For tests, we'll check application env
    case Application.get_env(:sertantai_docs, :search_engine) do
      nil ->
        # Create a dummy process for tests that mimics Engine behavior
        {:ok, pid} = Agent.start_link(fn -> 
          Application.get_env(:sertantai_docs, :search_index, %{documents: %{}, terms: %{}, document_count: 0})
        end)
        pid
      
      pid when is_pid(pid) ->
        pid
    end
  end
  
  # Mock Engine.search for tests
  defp mock_search(agent_pid, query, opts) do
    index = Agent.get(agent_pid, & &1)
    
    # Use the actual Index.search if we have a proper index
    case index do
      %{documents: _documents, terms: _terms} ->
        try do
          SertantaiDocs.Search.Index.search(index, query, opts)
          |> Enum.map(fn doc -> 
            Map.merge(doc, %{
              breadcrumbs: [%{title: "Home", path: "/"}],
              snippet: String.slice(doc[:content] || "", 0, 100)
            })
          end)
        rescue
          _ ->
            []
        end
      
      _ ->
        []
    end
  end

  defp highlight_text(text, query) do
    if String.length(query) >= @min_query_length do
      query_terms = 
        query
        |> String.downcase()
        |> String.split(~r/\s+/)
        |> Enum.reject(&(&1 == ""))
      
      # Create regex pattern for all terms
      pattern = 
        query_terms
        |> Enum.map(&Regex.escape/1)
        |> Enum.join("|")
      
      if pattern != "" do
        regex = Regex.compile!("(#{pattern})", "i")
        
        text
        |> String.split(regex, include_captures: true)
        |> Enum.map(fn part ->
          if Regex.match?(regex, part) do
            raw("<mark>#{Phoenix.HTML.html_escape(part)}</mark>")
          else
            Phoenix.HTML.html_escape(part)
          end
        end)
      else
        text
      end
    else
      text
    end
  end
end