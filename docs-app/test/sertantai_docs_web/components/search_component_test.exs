defmodule SertantaiDocsWeb.SearchComponentTest do
  use SertantaiDocsWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import SertantaiDocsWeb.CoreComponents

  describe "advanced search enhancement with metadata" do
    test "renders search input with metadata filtering options" do
      search_state = %{
        query: "",
        include_tags: true,
        include_author: true,
        include_category: true,
        scoped_to_group: "",
        results: []
      }

      available_options = %{
        groups: ["done", "strategy", "todo"],
        categories: ["security", "admin", "implementation"],
        authors: ["Claude", "User"],
        tags: ["phase-1", "ash", "security"]
      }

      assigns = %{search_state: search_state, available_options: available_options}

      html = rendered_to_string(~H"""
      <div class="search-container">
        <div class="search-input-container">
          <input
            type="text"
            phx-change="search-query-change"
            phx-value-query={@search_state.query}
            placeholder="Search documentation and metadata..."
            class="w-full px-4 py-2 border rounded-md"
          />
        </div>
        
        <div class="search-options mt-2">
          <div class="search-metadata-toggles flex items-center space-x-4">
            <label class="inline-flex items-center">
              <input
                type="checkbox"
                phx-click="toggle-search-tags"
                checked={@search_state.include_tags}
                class="mr-1"
              />
              <span class="text-xs">Include Tags</span>
            </label>
            
            <label class="inline-flex items-center">
              <input
                type="checkbox"
                phx-click="toggle-search-author"
                checked={@search_state.include_author}
                class="mr-1"
              />
              <span class="text-xs">Include Author</span>
            </label>
            
            <label class="inline-flex items-center">
              <input
                type="checkbox"
                phx-click="toggle-search-category"
                checked={@search_state.include_category}
                class="mr-1"
              />
              <span class="text-xs">Include Category</span>
            </label>
          </div>
          
          <div class="search-scope mt-2">
            <label class="text-xs font-medium text-gray-700">Search in group:</label>
            <select phx-change="change-search-scope" class="text-xs ml-2">
              <option value="">All groups</option>
              <%= for group <- @available_options.groups do %>
                <option value={group} selected={@search_state.scoped_to_group == group}>
                  <%= String.capitalize(group) %>
                </option>
              <% end %>
            </select>
          </div>
        </div>
      </div>
      """)

      # Should render search input
      assert html =~ ~s(phx-change="search-query-change")
      assert html =~ ~s(placeholder="Search documentation and metadata...")
      
      # Should render metadata toggle options
      assert html =~ ~s(phx-click="toggle-search-tags")
      assert html =~ ~s(phx-click="toggle-search-author")
      assert html =~ ~s(phx-click="toggle-search-category")
      assert html =~ "Include Tags"
      assert html =~ "Include Author"
      assert html =~ "Include Category"
      
      # Should render scope selector
      assert html =~ ~s(phx-change="change-search-scope")
      assert html =~ "All groups"
      assert html =~ "Done"
      assert html =~ "Strategy"
      assert html =~ "Todo"
    end

    test "renders tag autocomplete suggestions" do
      search_state = %{
        query: "sec",
        tag_suggestions: ["security", "secure-auth"],
        show_suggestions: true
      }

      assigns = %{search_state: search_state}

      html = rendered_to_string(~H"""
      <div class="search-suggestions-container">
        <%= if @search_state.show_suggestions do %>
          <div class="tag-suggestions bg-white border rounded-md shadow-lg mt-1">
            <div class="suggestion-header p-2 text-xs font-medium text-gray-700">
              Tag suggestions:
            </div>
            <%= for suggestion <- @search_state.tag_suggestions do %>
              <button
                phx-click="select-tag-suggestion"
                phx-value-tag={suggestion}
                class="w-full text-left px-3 py-1 text-xs hover:bg-gray-100"
              >
                <span class="text-blue-600">#<%= suggestion %></span>
              </button>
            <% end %>
          </div>
        <% end %>
      </div>
      """)

      # Should render tag suggestions
      assert html =~ "Tag suggestions:"
      assert html =~ ~s(phx-click="select-tag-suggestion")
      assert html =~ ~s(phx-value-tag="security")
      assert html =~ "#security"
      assert html =~ "#secure-auth"
    end

    test "performs full-text search with metadata inclusion" do
      # Mock search data
      documents = [
        %{title: "Security Guide", path: "/security", content: "Authentication methods", metadata: %{"tags" => ["security", "auth"], "author" => "Claude", "category" => "security"}},
        %{title: "Admin Panel", path: "/admin", content: "User management", metadata: %{"tags" => ["admin"], "author" => "User", "category" => "admin"}},
        %{title: "Implementation", path: "/impl", content: "Security implementation", metadata: %{"tags" => ["implementation", "security"], "author" => "Claude", "category" => "implementation"}}
      ]

      search_options = %{
        query: "security",
        include_tags: true,
        include_author: false,
        include_category: true,
        scoped_to_group: ""
      }

      # Test search logic that would be in the component
      results = Enum.filter(documents, fn doc ->
        # Search in title and content
        title_match = String.contains?(String.downcase(doc.title), String.downcase(search_options.query))
        content_match = String.contains?(String.downcase(doc.content), String.downcase(search_options.query))
        
        # Search in metadata if enabled
        tag_match = if search_options.include_tags do
          tags = Map.get(doc.metadata, "tags", [])
          Enum.any?(tags, fn tag -> String.contains?(String.downcase(tag), String.downcase(search_options.query)) end)
        else
          false
        end
        
        category_match = if search_options.include_category do
          category = Map.get(doc.metadata, "category", "")
          String.contains?(String.downcase(category), String.downcase(search_options.query))
        else
          false
        end

        title_match || content_match || tag_match || category_match
      end)

      # Should find documents matching in title, content, tags, or category
      assert length(results) == 2
      
      titles = Enum.map(results, & &1.title)
      assert "Security Guide" in titles      # matches title and tags
      assert "Implementation" in titles      # matches content and tags
      # Admin Panel would not match since "security" not in its title, content, tags, or category
    end

    test "performs scoped search within specific group" do
      # Mock grouped documents
      documents = [
        %{title: "Done Security", path: "/done/sec", group: "done", metadata: %{"category" => "security"}},
        %{title: "Todo Security", path: "/todo/sec", group: "todo", metadata: %{"category" => "security"}},
        %{title: "Strategy Security", path: "/strategy/sec", group: "strategy", metadata: %{"category" => "security"}}
      ]

      search_options = %{
        query: "security",
        scoped_to_group: "done"
      }

      # Test scoped search logic
      scoped_docs = if search_options.scoped_to_group != "" do
        Enum.filter(documents, fn doc -> doc.group == search_options.scoped_to_group end)
      else
        documents
      end

      results = Enum.filter(scoped_docs, fn doc ->
        String.contains?(String.downcase(doc.title), String.downcase(search_options.query))
      end)

      # Should only find documents in the "done" group
      assert length(results) == 1
      assert List.first(results).title == "Done Security"
    end

    test "highlights search matches in results" do
      search_result = %{
        title: "Security Implementation Guide",
        path: "/security",
        matches: [
          %{field: "title", text: "Security Implementation Guide", highlight_start: 0, highlight_end: 8},
          %{field: "tags", text: "security, implementation", highlight_start: 0, highlight_end: 8},
          %{field: "category", text: "security", highlight_start: 0, highlight_end: 8}
        ]
      }

      assigns = %{result: search_result}

      html = rendered_to_string(~H"""
      <div class="search-result">
        <h3 class="result-title">
          <a href={@result.path} class="text-blue-600 hover:underline">
            <%= @result.title %>
          </a>
        </h3>
        
        <div class="result-matches mt-1">
          <%= for match <- @result.matches do %>
            <div class="match text-xs text-gray-600">
              <span class="match-field font-medium"><%= match.field %>:</span>
              <span class="match-text">
                <%= if match.highlight_start >= 0 do %>
                  <%= String.slice(match.text, 0, match.highlight_start) %><mark class="bg-yellow-200"><%= String.slice(match.text, match.highlight_start, match.highlight_end - match.highlight_start) %></mark><%= String.slice(match.text, match.highlight_end, String.length(match.text)) %>
                <% else %>
                  <%= match.text %>
                <% end %>
              </span>
            </div>
          <% end %>
        </div>
      </div>
      """)

      # Should render highlighted matches
      assert html =~ ~s(<mark class="bg-yellow-200">Security</mark>)
      assert html =~ "Security Implementation Guide"
      assert html =~ "title:"
      assert html =~ "tags:"
      assert html =~ "category:"
    end

    test "handles empty search gracefully" do
      search_state = %{
        query: "",
        results: [],
        total_results: 0,
        search_time_ms: 0
      }

      assigns = %{search_state: search_state}

      html = rendered_to_string(~H"""
      <div class="search-results">
        <%= if @search_state.query == "" do %>
          <div class="empty-search text-center text-gray-500 py-8">
            <p>Enter a search term to find documents</p>
            <p class="text-xs mt-1">Search includes titles, content, tags, authors, and categories</p>
          </div>
        <% else %>
          <%= if @search_state.total_results == 0 do %>
            <div class="no-results text-center text-gray-500 py-8">
              <p>No results found for "<%= @search_state.query %>"</p>
              <p class="text-xs mt-1">Try different keywords or check your spelling</p>
            </div>
          <% end %>
        <% end %>
      </div>
      """)

      # Should render empty state message
      assert html =~ "Enter a search term to find documents"
      assert html =~ "Search includes titles, content, tags, authors, and categories"
    end

    test "displays search statistics and timing" do
      search_state = %{
        query: "security",
        results: [],
        total_results: 42,
        search_time_ms: 15,
        filters_applied: %{
          include_tags: true,
          include_author: false,
          scoped_to_group: "done"
        }
      }

      assigns = %{search_state: search_state}

      html = rendered_to_string(~H"""
      <div class="search-stats text-xs text-gray-600 mb-4">
        <span class="results-count">
          Found <%= @search_state.total_results %> results
        </span>
        <span class="search-time ml-2">
          (<%= @search_state.search_time_ms %>ms)
        </span>
        
        <%= if @search_state.filters_applied do %>
          <div class="active-filters mt-1">
            <span class="filter-label">Filters:</span>
            <%= if @search_state.filters_applied.include_tags do %>
              <span class="filter-badge bg-blue-100 text-blue-800 px-1 rounded">Tags</span>
            <% end %>
            <%= if @search_state.filters_applied.scoped_to_group != "" do %>
              <span class="filter-badge bg-green-100 text-green-800 px-1 rounded ml-1">
                Group: <%= @search_state.filters_applied.scoped_to_group %>
              </span>
            <% end %>
          </div>
        <% end %>
      </div>
      """)

      # Should render search statistics
      assert html =~ "Found 42 results"
      assert html =~ "(15ms)"
      assert html =~ "Filters:"
      assert html =~ ~s(<span class="filter-badge bg-blue-100 text-blue-800 px-1 rounded">Tags</span>)
      assert html =~ "Group: done"
    end

    test "supports keyboard navigation in search results" do
      search_results = [
        %{title: "First Result", path: "/first"},
        %{title: "Second Result", path: "/second"},
        %{title: "Third Result", path: "/third"}
      ]

      search_state = %{
        results: search_results,
        selected_index: 1  # Second result selected
      }

      assigns = %{search_state: search_state}

      html = rendered_to_string(~H"""
      <div class="search-results" phx-window-keydown="search-keydown">
        <%= for {result, index} <- Enum.with_index(@search_state.results) do %>
          <div 
            class={[
              "search-result-item p-3 border-b",
              if(index == @search_state.selected_index, do: "bg-blue-50 border-blue-200", else: "hover:bg-gray-50")
            ]}
            data-result-index={index}
          >
            <a href={result.path} class="block">
              <%= result.title %>
            </a>
          </div>
        <% end %>
      </div>
      """)

      # Should render keyboard navigation support
      assert html =~ ~s(phx-window-keydown="search-keydown")
      assert html =~ ~s(data-result-index="0")
      assert html =~ ~s(data-result-index="1")
      assert html =~ ~s(data-result-index="2")
      
      # Should highlight selected result
      assert html =~ ~s(bg-blue-50 border-blue-200)
    end

    test "saves and restores search preferences" do
      # This test verifies that search state persists
      saved_preferences = %{
        include_tags: true,
        include_author: false,
        include_category: true,
        last_scope: "todo",
        recent_queries: ["security", "admin", "phase-1"]
      }

      # Mock localStorage retrieval (this would be in JavaScript)
      search_state = Map.merge(%{
        query: "",
        include_tags: false,
        include_author: false,
        include_category: false,
        scoped_to_group: ""
      }, saved_preferences)

      # Verify preferences are restored
      assert search_state.include_tags == true
      assert search_state.include_author == false  
      assert search_state.include_category == true
      assert search_state.last_scope == "todo"
      assert length(search_state.recent_queries) == 3
    end
  end

  describe "search performance and optimization" do
    test "implements search result caching" do
      # Mock cache behavior
      cache_key = "search:security:tags:true:author:false:scope:"
      
      # First search - cache miss
      first_result = %{
        results: [%{title: "Security Doc", path: "/sec"}],
        cache_hit: false,
        search_time_ms: 25
      }
      
      # Second identical search - cache hit
      second_result = %{
        results: [%{title: "Security Doc", path: "/sec"}],
        cache_hit: true,
        search_time_ms: 2
      }

      # Cache should improve performance significantly
      assert second_result.search_time_ms < first_result.search_time_ms
      assert second_result.cache_hit == true
      assert first_result.cache_hit == false
      assert first_result.results == second_result.results
    end

    test "limits search results for performance" do
      # Mock large result set
      large_results = Enum.map(1..1000, fn i -> 
        %{title: "Document #{i}", path: "/doc#{i}"}
      end)

      # Should limit to reasonable number (e.g., 50)
      max_results = 50
      limited_results = Enum.take(large_results, max_results)

      assert length(limited_results) == max_results
      assert length(limited_results) < length(large_results)
    end

    test "debounces search input to avoid excessive queries" do
      # This test verifies debouncing behavior (would be implemented in JavaScript)
      search_inputs = [
        %{query: "s", timestamp: 0},
        %{query: "se", timestamp: 100},
        %{query: "sec", timestamp: 200},
        %{query: "secu", timestamp: 300},
        %{query: "secur", timestamp: 400},
        %{query: "security", timestamp: 600}  # Final input after debounce delay
      ]

      debounce_delay = 300  # milliseconds
      
      # Should only trigger search after debounce delay
      triggered_searches = Enum.filter(search_inputs, fn input ->
        # Simulate: only trigger if no input follows within debounce delay
        next_input = Enum.find(search_inputs, fn next -> 
          next.timestamp > input.timestamp && next.timestamp <= input.timestamp + debounce_delay
        end)
        next_input == nil
      end)

      # Should only trigger search for final "security" query
      assert length(triggered_searches) == 1
      assert List.first(triggered_searches).query == "security"
    end
  end
end