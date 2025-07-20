defmodule SertantaiDocsWeb.SearchLiveTest do
  use SertantaiDocsWeb.ConnCase
  import Phoenix.LiveViewTest

  alias SertantaiDocs.Search.Index

  setup do
    # Create a test search index
    files = [
      %{
        id: "getting-started",
        title: "Getting Started with Phoenix",
        content: "Learn how to build web applications with Phoenix framework",
        path: "/user/getting-started",
        category: "user",
        tags: ["beginner", "phoenix"]
      },
      %{
        id: "liveview-guide",
        title: "LiveView Guide",
        content: "Build interactive real-time features with Phoenix LiveView",
        path: "/dev/liveview-guide",
        category: "dev",
        tags: ["liveview", "real-time"]
      },
      %{
        id: "ecto-queries",
        title: "Ecto Query Guide",
        content: "Learn how to write efficient database queries with Ecto",
        path: "/dev/ecto-queries",
        category: "dev",
        tags: ["ecto", "database"]
      }
    ]
    
    # In a real app, this would be stored in an Agent or ETS table
    Application.put_env(:sertantai_docs, :search_index, Index.build_index(files))
    
    :ok
  end

  describe "search interface" do
    test "renders search input and placeholder", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      assert has_element?(view, "input[type='search']")
      assert has_element?(view, "input[placeholder*='Search documentation']")
    end

    test "shows search results as user types", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      # Initially no results
      refute has_element?(view, "[data-test='search-result']")
      
      # Type in search box
      view
      |> form("#search-form", search: %{query: "phoenix"})
      |> render_change()
      
      # Should show results
      assert has_element?(view, "[data-test='search-result']")
      assert has_element?(view, "a", "Getting Started with Phoenix")
      assert has_element?(view, "a", "LiveView Guide")
    end

    test "debounces search input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      # Type quickly
      view
      |> form("#search-form", search: %{query: "p"})
      |> render_change()
      
      # Should not show results immediately for single character
      refute has_element?(view, "[data-test='search-result']")
      
      # Complete the word
      view
      |> form("#search-form", search: %{query: "phoenix"})
      |> render_change()
      
      # Now should show results
      assert has_element?(view, "[data-test='search-result']")
    end

    test "highlights matching terms in results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      view
      |> form("#search-form", search: %{query: "ecto"})
      |> render_change()
      
      # Should highlight the search term
      assert has_element?(view, "mark", "Ecto")
      assert has_element?(view, "[data-test='search-result']", "Ecto Query Guide")
    end

    test "shows no results message", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      view
      |> form("#search-form", search: %{query: "nonexistent"})
      |> render_change()
      
      assert has_element?(view, "[data-test='no-results']")
      assert has_element?(view, "p", "No results found")
    end

    test "clears search and results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      # Search for something
      view
      |> form("#search-form", search: %{query: "phoenix"})
      |> render_change()
      
      assert has_element?(view, "[data-test='search-result']")
      
      # Clear search
      view
      |> element("button[data-test='clear-search']")
      |> render_click()
      
      refute has_element?(view, "[data-test='search-result']")
      assert has_element?(view, "input[value='']")
    end
  end

  describe "search filters" do
    test "filters by category", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      # Search without filter
      view
      |> form("#search-form", search: %{query: "guide"})
      |> render_change()
      
      # Should show all guides
      assert has_element?(view, "a", "LiveView Guide")
      assert has_element?(view, "a", "Ecto Query Guide")
      
      # Apply category filter
      view
      |> form("#search-form", search: %{query: "guide", category: "dev"})
      |> render_change()
      
      # Should only show dev guides
      assert has_element?(view, "a", "LiveView Guide")
      assert has_element?(view, "a", "Ecto Query Guide")
      refute has_element?(view, "a", "Getting Started with Phoenix")
    end

    test "shows filter options", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      # Filter dropdown/checkboxes should be visible
      assert has_element?(view, "[data-test='category-filter']")
      assert has_element?(view, "label", "Developer")
      assert has_element?(view, "label", "User Guide")
      assert has_element?(view, "label", "API Reference")
    end

    test "combines multiple filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      # Search with multiple filters
      view
      |> form("#search-form", search: %{
        query: "guide",
        category: ["dev"],
        tags: ["database"]
      })
      |> render_change()
      
      # Should only show results matching all filters
      assert has_element?(view, "a", "Ecto Query Guide")
      refute has_element?(view, "a", "LiveView Guide")
    end
  end

  describe "search result interaction" do
    test "navigates to document on click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      view
      |> form("#search-form", search: %{query: "ecto"})
      |> render_change()
      
      # Click on result
      view
      |> element("a", "Ecto Query Guide")
      |> render_click()
      
      # Should navigate to the document
      assert_redirect(view, "/dev/ecto-queries")
    end

    test "shows document metadata in results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      view
      |> form("#search-form", search: %{query: "phoenix"})
      |> render_change()
      
      # Should show category badges
      assert has_element?(view, "[data-test='category-badge']", "user")
      assert has_element?(view, "[data-test='category-badge']", "dev")
      
      # Should show content preview
      assert has_element?(view, "[data-test='content-preview']", "Learn how to build")
    end

    test "keyboard navigation through results", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      view
      |> form("#search-form", search: %{query: "guide"})
      |> render_change()
      
      # Simulate keyboard navigation
      view
      |> element("#search-form")
      |> render_keydown(%{key: "ArrowDown"})
      
      # First result should be focused
      assert has_element?(view, "[data-test='search-result'][data-focused='true']")
      
      # Navigate down again
      view
      |> element("#search-form")
      |> render_keydown(%{key: "ArrowDown"})
      
      # Second result should be focused
      results = view |> element("[data-test='search-result'][data-focused='true']") |> render()
      assert results =~ "Ecto Query Guide"
    end
  end

  describe "search performance" do
    test "shows loading state for slow searches", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      # Simulate slow search by sending message directly
      send(view.pid, {:search_start})
      
      assert has_element?(view, "[data-test='search-loading']")
      
      # Complete search
      send(view.pid, {:search_complete, []})
      
      refute has_element?(view, "[data-test='search-loading']")
    end

    test "cancels previous search when new query is entered", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      # Start first search
      view
      |> form("#search-form", search: %{query: "pho"})
      |> render_change()
      
      # Quickly type more
      view
      |> form("#search-form", search: %{query: "phoenix"})
      |> render_change()
      
      # Should only show results for "phoenix", not "pho"
      assert has_element?(view, "[data-test='search-result']")
      
      # Verify the results are for "phoenix" query
      assert has_element?(view, "mark", "Phoenix")
    end
  end

  describe "search analytics" do
    test "tracks popular searches", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      # Perform a search
      view
      |> form("#search-form", search: %{query: "liveview"})
      |> render_change()
      
      # Click on a result
      view
      |> element("a", "LiveView Guide")
      |> render_click()
      
      # In real implementation, this would be tracked
      # For now, just verify the click was registered
      assert_redirect(view, "/dev/liveview-guide")
    end

    test "shows popular searches suggestion", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/search")
      
      # Should show popular searches when input is empty
      assert has_element?(view, "[data-test='popular-searches']")
      assert has_element?(view, "button", "LiveView")
      assert has_element?(view, "button", "Ecto")
      
      # Clicking popular search should trigger search
      view
      |> element("button", "LiveView")
      |> render_click()
      
      assert has_element?(view, "input[value='LiveView']")
      assert has_element?(view, "[data-test='search-result']")
    end
  end
end