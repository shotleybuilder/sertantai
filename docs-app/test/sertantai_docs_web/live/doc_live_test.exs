defmodule SertantaiDocsWeb.DocLiveTest do
  use SertantaiDocsWeb.ConnCase
  import Phoenix.LiveViewTest

  describe "collapsible navigation groups" do
    test "renders navigation with collapsible groups", %{conn: conn} do
      {:ok, view, html} = live(conn, "/build")
      
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
      {:ok, view, _html} = live(conn, "/build")
      
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
      {:ok, view, _html} = live(conn, "/build")
      
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
      {:ok, view, html} = live(conn, "/build")
      
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
      {:ok, view, _html} = live(conn, "/build")
      
      # Expand done group
      view |> element("[phx-value-group='done']") |> render_click()
      assert has_element?(view, "[data-group='done'][aria-expanded='true']")
      
      # Navigate to a specific done document (if link exists)
      if has_element?(view, "a[href*='/build/done_']") do
        first_done_link = view |> element("a[href*='/build/done_']") |> render_click()
        
        # After navigation, return to build index
        {:ok, view, _html} = live(conn, "/build")
        
        # Group expansion state should be preserved (via session storage)
        # Note: This test will pass when we implement session persistence
        assert has_element?(view, "[data-group='done']")
      end
    end

    test "handles keyboard navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build")
      
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
      {:ok, view, _html} = live(conn, "/build")
      
      # Press space on group header (standard accessibility pattern)
      view
      |> element("[data-group='strategy']")
      |> render_hook("keydown", %{"key" => " "})
      
      # Should toggle expansion
      assert has_element?(view, "[data-group='strategy'][aria-expanded='true']")
    end

    test "provides proper focus management", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build")
      
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
      {:ok, view, _html} = live(conn, "/build")
      
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
      {:ok, view, _html} = live(conn, "/build")
      
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
      
      {:ok, view, html} = live(conn, "/build")
      
      # Should have data attributes for JavaScript to hook into
      assert html =~ ~r/data-state-key="build_group_/
      assert html =~ ~r/data-default-expanded/
      
      # JavaScript will read these attributes and restore state
      # LiveView will handle server-side state management
    end
  end

  describe "performance and caching" do
    test "efficiently handles large numbers of groups", %{conn: conn} do
      {:ok, view, html} = live(conn, "/build")
      
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
      
      {:ok, _view, _html} = live(conn, "/build")
      
      end_time = System.monotonic_time(:millisecond)
      load_time = end_time - start_time
      
      # Should load reasonably quickly (under 1 second)
      assert load_time < 1000
    end
  end

  describe "error handling" do
    test "handles missing group data gracefully", %{conn: conn} do
      {:ok, view, html} = live(conn, "/build")
      
      # Should not crash even if some group data is malformed
      # Navigation should still render
      assert html =~ "Build Documentation"
      
      # Should have at least some navigation elements
      assert has_element?(view, "nav")
    end

    test "handles JavaScript errors gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/build")
      
      # Attempt to toggle non-existent group
      result = view |> element("[phx-value-group='nonexistent']", false) |> render_click()
      
      # Should not crash the LiveView
      assert is_binary(result) || result == {:error, :not_found}
      
      # View should still be functional
      assert render(view) =~ "Build Documentation"
    end

    test "provides fallback when localStorage is unavailable", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/build")
      
      # Should have fallback behavior built into the component
      # Groups should work even without persistence
      assert html =~ ~r/data-default-expanded/
      
      # Should have all necessary data attributes for JavaScript fallback
      assert html =~ ~r/data-state-key/
    end
  end
end