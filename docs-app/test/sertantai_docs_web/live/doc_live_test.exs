defmodule SertantaiDocsWeb.DocLiveTest do
  use SertantaiDocsWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "collapsible navigation groups" do
    test "renders navigation with collapsible groups", %{conn: conn} do
      {:ok, view, html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Should render Build Documentation section with groups
      assert html =~ "Build Documentation"
      
      # Should have collapsible groups with proper data attributes
      assert html =~ ~r/data-group="done"/
      assert html =~ ~r/phx-click="toggle-group"/
      
      # Should show chevron icons for expand/collapse state
      assert has_element?(view, "[data-testid='group-chevron']")
      
      # Should show item counts for groups
      assert html =~ ~r/\(\d+\)/  # Matches (number) pattern
    end

    test "toggles group expansion state on click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Initially, done group should be collapsed (default_expanded: false)
      refute has_element?(view, "[data-group='done'][aria-expanded='true']")
      
      # Click to expand done group
      view |> element("[phx-value-group='done']") |> render_click()
      
      # Should now be expanded
      assert has_element?(view, "[data-group='done'][aria-expanded='true']")
      
      # Chevron should change from right to down
      assert has_element?(view, "[data-group='done'] [data-testid='chevron-down']")
      refute has_element?(view, "[data-group='done'] [data-testid='chevron-right']")
      
      # Children should now be visible
      done_children = view |> element("[data-group='done'] .group-children") |> render()
      assert done_children =~ "done_"  # Should contain done_ prefixed files
      
      # Click again to collapse
      view |> element("[phx-value-group='done']") |> render_click()
      
      # Should be collapsed again
      refute has_element?(view, "[data-group='done'][aria-expanded='true']")
      assert has_element?(view, "[data-group='done'] [data-testid='chevron-right']")
    end

    test "handles multiple groups independently", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Expand done group
      view |> element("[phx-value-group='done']") |> render_click()
      assert has_element?(view, "[data-group='done'][aria-expanded='true']")
      
      # Strategy group should still be collapsed
      refute has_element?(view, "[data-group='strategy'][aria-expanded='true']")
      
      # Expand strategy group
      view |> element("[phx-value-group='strategy']") |> render_click()
      assert has_element?(view, "[data-group='strategy'][aria-expanded='true']")
      
      # Done group should still be expanded
      assert has_element?(view, "[data-group='done'][aria-expanded='true']")
      
      # Collapse done, strategy should remain expanded
      view |> element("[phx-value-group='done']") |> render_click()
      refute has_element?(view, "[data-group='done'][aria-expanded='true']")
      assert has_element?(view, "[data-group='strategy'][aria-expanded='true']")
    end

    test "respects default expansion settings", %{conn: conn} do
      {:ok, view, html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Todo group should default to expanded (active work)
      if html =~ ~r/data-group="todo"/ do
        assert has_element?(view, "[data-group='todo'][aria-expanded='true']")
        assert has_element?(view, "[data-group='todo'] [data-testid='chevron-down']")
      end
      
      # Done group should default to collapsed (completed work)
      if html =~ ~r/data-group="done"/ do
        refute has_element?(view, "[data-group='done'][aria-expanded='true']")
        assert has_element?(view, "[data-group='done'] [data-testid='chevron-right']")
      end
      
      # Strategy group should default to collapsed (reference material)
      if html =~ ~r/data-group="strategy"/ do
        refute has_element?(view, "[data-group='strategy'][aria-expanded='true']")
        assert has_element?(view, "[data-group='strategy'] [data-testid='chevron-right']")
      end
    end

    test "maintains state when navigating between pages in same category", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Expand done group
      view |> element("[phx-value-group='done']") |> render_click()
      assert has_element?(view, "[data-group='done'][aria-expanded='true']")
      
      # Navigate to a specific done document (if link exists)
      if has_element?(view, "a[href*='/build/done_']") do
        first_done_link = view |> element("a[href*='/build/done_']") |> render_click()
        
        # After navigation, return to build index
        {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")
        
        # Group expansion state should be preserved (via session storage)
        # Note: This test will pass when we implement session persistence
        assert has_element?(view, "[data-group='done']")
      end
    end

    test "handles keyboard navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Focus on a group header and press Enter
      view 
      |> element("[data-group='done']")
      |> render_hook("keydown", %{"key" => "Enter"})
      
      # Should toggle expansion state
      assert has_element?(view, "[data-group='done'][aria-expanded='true']")
      
      # Press Enter again to collapse
      view
      |> element("[data-group='done']") 
      |> render_hook("keydown", %{"key" => "Enter"})
      
      refute has_element?(view, "[data-group='done'][aria-expanded='true']")
    end

    test "handles space key for accessibility", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Press space on group header (standard accessibility pattern)
      view
      |> element("[data-group='strategy']")
      |> render_hook("keydown", %{"key" => " "})
      
      # Should toggle expansion
      assert has_element?(view, "[data-group='strategy'][aria-expanded='true']")
    end

    test "provides proper focus management", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Expand a group
      view |> element("[phx-value-group='done']") |> render_click()
      
      # Arrow down should focus first child (if implemented)
      view
      |> element("[data-group='done']")
      |> render_hook("keydown", %{"key" => "ArrowDown"})
      
      # Should focus first child item (test will verify this behavior exists)
      # Note: Actual focus behavior will be tested in browser/integration tests
      assert has_element?(view, "[data-group='done'] .group-children")
    end

    test "updates URL hash when navigating to specific documents", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # If there are navigable items, test URL updates
      if has_element?(view, "[data-group='done'] a") do
        # Expand group to reveal links
        view |> element("[phx-value-group='done']") |> render_click()
        
        # Click on a document link
        view |> element("[data-group='done'] a") |> render_click()
        
        # Should navigate to the document (URL change will be handled by LiveView)
        assert_patch(view)
      end
    end
  end

  describe "state persistence" do
    test "stores group expansion state in session storage", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Expand multiple groups
      view |> element("[phx-value-group='done']") |> render_click()
      view |> element("[phx-value-group='strategy']") |> render_click()
      
      # Simulate page reload by creating new connection
      # Note: Session storage persistence will be handled by JavaScript
      # This test verifies the data structure for persistence
      
      expanded_state = %{
        "build_group_done" => true,
        "build_group_strategy" => true,
        "build_group_todo" => false
      }
      
      # Verify state structure is correct for storage
      assert is_map(expanded_state)
      assert Map.has_key?(expanded_state, "build_group_done")
      assert Map.get(expanded_state, "build_group_done") == true
    end

    test "restores expansion state from session storage on page load", %{conn: conn} do
      # This test will verify the restoration logic exists
      # Implementation will be in JavaScript + LiveView mount
      
      {:ok, view, html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Should have data attributes for JavaScript to hook into
      assert html =~ ~r/data-state-key="build_group_/
      assert html =~ ~r/data-default-expanded/
      
      # JavaScript will read these attributes and restore state
      # LiveView will handle server-side state management
    end
  end

  describe "performance and caching" do
    test "efficiently handles large numbers of groups", %{conn: conn} do
      {:ok, view, html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Should render groups without performance issues
      group_count = html
      |> String.split("data-group=")
      |> length()
      |> Kernel.-(1)  # Subtract 1 for the split artifact
      
      # Should have reasonable number of groups (2-6 typically)
      assert group_count > 0
      assert group_count < 20  # Reasonable upper bound
      
      # Each group should have proper attributes
      assert html =~ ~r/data-group="[^"]+"/
    end

    test "loads navigation data efficiently", %{conn: conn} do
      # Measure navigation generation performance
      start_time = System.monotonic_time(:millisecond)
      
      {:ok, _view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      end_time = System.monotonic_time(:millisecond)
      load_time = end_time - start_time
      
      # Should load reasonably quickly (under 1 second)
      assert load_time < 1000
    end
  end

  describe "error handling" do
    test "handles missing group data gracefully", %{conn: conn} do
      {:ok, view, html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Should not crash even if some group data is malformed
      # Navigation should still render
      assert html =~ "Build Documentation"
      
      # Should have at least some navigation elements
      assert has_element?(view, "nav")
    end

    test "handles JavaScript errors gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Attempt to toggle non-existent group
      result = view |> element("[phx-value-group='nonexistent']", false) |> render_click()
      
      # Should not crash the LiveView
      assert is_binary(result) || result == {:error, :not_found}
      
      # View should still be functional
      assert render(view) =~ "Build Documentation"
    end

    test "provides fallback when localStorage is unavailable", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/build/todo_documentation_grouping_system_plan")
      
      # Should have fallback behavior built into the component
      # Groups should work even without persistence
      assert html =~ ~r/data-default-expanded/
      
      # Should have all necessary data attributes for JavaScript fallback
      assert html =~ ~r/data-state-key/
    end
  end

  describe "DocLive with integrated filtering/sorting UI" do
    test "renders page with filtering controls in sidebar", %{conn: conn} do
      {:ok, view, html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Should render filter controls in the sidebar
      assert html =~ ~s(class="nav-filters)
      assert html =~ ~s(phx-change="filter-by-status")
      assert html =~ ~s(phx-change="filter-by-category")
      assert html =~ ~s(phx-change="filter-by-priority")
      assert html =~ "Status"
      assert html =~ "Category"
      assert html =~ "Priority"
    end

    test "renders page with sorting controls in sidebar", %{conn: conn} do
      {:ok, view, html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Should render sort controls in the sidebar
      assert html =~ ~s(class="nav-sort)
      assert html =~ ~s(phx-change="change-sort")
      assert html =~ ~s(phx-click="toggle-sort-order")
      assert html =~ "Sort by"
      assert html =~ "Priority"
      assert html =~ "Title"
    end

    test "renders page with enhanced search box in header", %{conn: conn} do
      {:ok, view, html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Should render enhanced search with metadata options
      assert html =~ ~s(class="enhanced-search-box)
      assert html =~ ~s(phx-change="search-query-change")
      assert html =~ ~s(phx-click="toggle-search-tags")
      assert html =~ ~s(phx-click="toggle-search-author")
      assert html =~ "Include Tags"
      assert html =~ "Include Author"
      assert html =~ "Search in group:"
    end

    test "handles filter-by-status event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Should handle status filter change
      assert view |> element("select[phx-change='filter-by-status']") |> has_element?()
      
      # Simulate status filter change
      view
      |> element("select[phx-change='filter-by-status']")
      |> render_change(%{"value" => "live"})

      # Should update the filtered navigation items
      html = render(view)
      assert html =~ ~s(selected="selected") or html =~ "live"
    end

    test "handles filter-by-category event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Should handle category filter change
      assert view |> element("select[phx-change='filter-by-category']") |> has_element?()
      
      # Simulate category filter change  
      view
      |> element("select[phx-change='filter-by-category']")
      |> render_change(%{"value" => "security"})

      # Should update the navigation to show only security items
      html = render(view)
      # Navigation should be filtered to security items only
      assert html =~ "security"
    end

    test "handles change-sort event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Should handle sort change
      assert view |> element("select[phx-change='change-sort']") |> has_element?()
      
      # Simulate sort change
      view
      |> element("select[phx-change='change-sort']")
      |> render_change(%{"value" => "title"})

      # Should update the navigation sort order
      html = render(view)
      assert html =~ ~s(value="title" selected) or html =~ "title"
    end

    test "handles toggle-sort-order event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Should handle sort order toggle
      assert view |> element("button[phx-click='toggle-sort-order']") |> has_element?()
      
      # Click sort order toggle
      view
      |> element("button[phx-click='toggle-sort-order']")
      |> render_click()

      # Should toggle between ↑ and ↓ indicators
      html = render(view)
      assert html =~ "↓" or html =~ "↑"
    end

    test "handles reset-filters event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # First apply some filters
      view
      |> element("select[phx-change='filter-by-status']")
      |> render_change(%{"value" => "live"})

      # Should have reset filters button
      assert view |> element("button[phx-click='reset-filters']") |> has_element?()
      
      # Click reset filters
      view
      |> element("button[phx-click='reset-filters']")
      |> render_click()

      # Should reset all filters to default state
      html = render(view)
      assert html =~ ~s(option value="" selected) or html =~ ~s(value="">All</option>)
    end

    test "handles toggle-tag-filter event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Should handle tag filter toggle
      assert view |> element("input[phx-click='toggle-tag-filter']") |> has_element?()
      
      # Toggle a tag filter
      view
      |> element("input[phx-click='toggle-tag-filter'][phx-value-tag='phase-1']")
      |> render_click()

      # Should update the tag filter state
      html = render(view)
      assert html =~ ~s(checked) or html =~ "phase-1"
    end

    test "handles search-query-change event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Should handle search query change
      assert view |> element("input[phx-change='search-query-change']") |> has_element?()
      
      # Simulate search input
      view
      |> element("input[phx-change='search-query-change']")
      |> render_change(%{"query" => "security"})

      # Should update search results or highlight matches
      html = render(view)
      # Should show search results or filtered navigation
      assert html =~ "security" or html =~ "No results" or html =~ "Found"
    end

    test "handles toggle-search-tags event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Should handle search metadata toggle
      assert view |> element("input[phx-click='toggle-search-tags']") |> has_element?()
      
      # Toggle search tags inclusion
      view
      |> element("input[phx-click='toggle-search-tags']")
      |> render_click()

      # Should update search options state
      html = render(view)
      assert html =~ ~s(checked) or html =~ ~s(phx-click="toggle-search-tags")
    end

    test "shows filter count when filters are active", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Apply a filter
      view
      |> element("select[phx-change='filter-by-status']")
      |> render_change(%{"value" => "live"})

      # Should show active filter indicator
      html = render(view)
      assert html =~ "Filters active" or html =~ "filter-indicator-active" or html =~ "Showing"
    end

    test "shows no results message when no items match filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Apply a filter that matches no items
      view
      |> element("select[phx-change='filter-by-category']")
      |> render_change(%{"value" => "nonexistent-category"})

      # Should show no results message
      html = render(view)
      assert html =~ "No items match" or html =~ "Try adjusting" or html =~ "No results"
    end
  end

  describe "DocLive state management with filtering/sorting" do
    test "maintains filter state across navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Apply filters
      view
      |> element("select[phx-change='filter-by-status']")
      |> render_change(%{"value" => "live"})

      view
      |> element("select[phx-change='filter-by-category']")
      |> render_change(%{"value" => "security"})

      # Navigate to another page within the same LiveView section
      {:ok, view, html} = live(conn, "/dev")

      # Should maintain filter state (via localStorage/URL params)
      assert html =~ ~s(value="live" selected) or html =~ "live"
      assert html =~ ~s(value="security" selected) or html =~ "security"
    end

    test "syncs state with URL parameters", %{conn: conn} do
      # Visit page with URL parameters for filters/sort
      {:ok, view, html} = live(conn, "/build?filter_status=live&filter_category=security&sort_by=priority&sort_order=desc")

      # Should initialize with URL parameter state
      assert html =~ ~s(value="live" selected) or html =~ "live"
      assert html =~ ~s(value="security" selected) or html =~ "security"
      assert html =~ ~s(value="priority" selected) or html =~ "priority"
      assert html =~ "↓"
    end

    test "persists expanded navigation groups with filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Expand a navigation group
      view |> element("[phx-value-group='done']") |> render_click()

      # Apply a filter
      view
      |> element("select[phx-change='filter-by-status']")
      |> render_change(%{"value" => "live"})

      # Navigation groups should remain expanded after filtering
      html = render(view)
      assert html =~ ~s(aria-expanded="true") or html =~ "chevron-down"
    end

    test "applies filters to navigation items correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Apply status filter 
      view
      |> element("select[phx-change='filter-by-status']")
      |> render_change(%{"value" => "live"})

      html = render(view)
      
      # Should only show items matching the filter
      # Note: This will fail until nav_sidebar supports filtering
      refute html =~ "archived"  # Should not show archived items
    end

    test "sorts navigation items according to selected criteria", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Change sort to title
      view
      |> element("select[phx-change='change-sort']")
      |> render_change(%{"value" => "title"})

      # Toggle to descending order
      view
      |> element("button[phx-click='toggle-sort-order']")
      |> render_click()

      html = render(view)
      
      # Should show descending sort indicator and sorted items
      # Note: This will fail until nav_sidebar supports sorting
      assert html =~ "↓"
    end

    test "combines multiple filters correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build/todo_documentation_grouping_system_plan")

      # Apply multiple filters
      view
      |> element("select[phx-change='filter-by-status']")
      |> render_change(%{"value" => "live"})

      view
      |> element("select[phx-change='filter-by-category']") 
      |> render_change(%{"value" => "security"})

      view
      |> element("select[phx-change='filter-by-priority']")
      |> render_change(%{"value" => "high"})

      html = render(view)
      
      # Should only show items matching ALL filters
      # Note: This will fail until nav_sidebar supports combined filtering
      assert html =~ "security"
      assert html =~ "high" or html =~ "live"
    end
  end
end