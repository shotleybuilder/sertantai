defmodule SertantaiDocsWeb.TOCLiveTest do
  use SertantaiDocsWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "TOC tracking and scrollspy" do
    test "tracks active section on scroll", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/test-page")
      
      # Simulate scroll to section
      assert view
             |> element("[data-toc-scrollspy]")
             |> render_hook("scroll", %{"section_id" => "installation"}) =~ 
             ~s(data-active-section="installation")
      
      # Active TOC item should be highlighted
      assert view
             |> element("[data-toc-item='installation']")
             |> render() =~ "active"
    end

    test "smooth scrolls to section on TOC click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/test-page")
      
      # Click TOC item
      view
      |> element("a[href='#configuration']")
      |> render_click()
      
      # Should trigger smooth scroll
      assert_push_event(view, "scroll-to-section", %{
        section_id: "configuration",
        behavior: "smooth"
      })
    end

    test "updates URL hash on section navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/test-page")
      
      # Navigate to section
      view
      |> element("a[href='#advanced-usage']")
      |> render_click()
      
      # URL should update
      assert_patch(view, "/docs/test-page#advanced-usage")
    end

    test "expands/collapses TOC sections", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/test-page")
      
      # Initially expanded
      assert view
             |> element("[data-toc-section='getting-started']")
             |> render() =~ "expanded"
      
      # Click to collapse
      view
      |> element("[phx-click='toggle-toc-section'][phx-value-section='getting-started']")
      |> render_click()
      
      # Should be collapsed
      refute view
              |> element("[data-toc-section='getting-started']")
              |> render() =~ "expanded"
    end

    test "highlights current section based on viewport", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/test-page")
      
      # Simulate intersection observer callback
      assert view
             |> render_hook("section-visible", %{
               "entries" => [
                 %{"id" => "overview", "isIntersecting" => false},
                 %{"id" => "installation", "isIntersecting" => true},
                 %{"id" => "configuration", "isIntersecting" => true}
               ]
             })
      
      # Should highlight the first visible section
      assert view
             |> element("[data-toc-active]")
             |> render() =~ "installation"
    end

    test "persists TOC collapse state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/test-page")
      
      # Collapse a section
      view
      |> element("[phx-click='toggle-toc-section'][phx-value-section='api-reference']")
      |> render_click()
      
      # Navigate away and back
      {:ok, _view2, _html} = live(conn, "/docs/other-page")
      {:ok, view3, _html} = live(conn, "/docs/test-page")
      
      # Section should remain collapsed
      refute view3
              |> element("[data-toc-section='api-reference']")
              |> render() =~ "expanded"
    end

    test "shows progress indicator for long documents", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/long-document")
      
      # Simulate scroll progress
      assert view
             |> render_hook("scroll-progress", %{"progress" => 0.45})
      
      # Progress bar should update
      assert view
             |> element("[data-reading-progress]")
             |> render() =~ "width: 45%"
    end

    test "keyboard navigation in TOC", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/test-page")
      
      # Focus TOC
      view
      |> element("[data-toc-container]")
      |> render_focus()
      
      # Arrow down
      view
      |> element("[data-toc-container]")
      |> render_keydown(%{"key" => "ArrowDown"})
      
      assert view
             |> element("[data-toc-focused]")
             |> render() =~ "introduction"
      
      # Enter to navigate
      view
      |> element("[data-toc-container]")
      |> render_keydown(%{"key" => "Enter"})
      
      assert_push_event(view, "scroll-to-section", %{section_id: "introduction"})
    end

    test "mobile TOC toggle", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/test-page")
      
      # TOC should be hidden on mobile by default
      assert view
             |> element("[data-mobile-toc]")
             |> render() =~ "hidden"
      
      # Toggle mobile TOC
      view
      |> element("[phx-click='toggle-mobile-toc']")
      |> render_click()
      
      # Should be visible
      refute view
              |> element("[data-mobile-toc]")
              |> render() =~ "hidden"
    end

    test "TOC search/filter", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/test-page")
      
      # Enter search term
      view
      |> form("[data-toc-search]", %{query: "install"})
      |> render_change()
      
      # Should filter TOC items
      assert view
             |> element("[data-toc-items]")
             |> render() =~ "Installation"
      
      refute view
              |> element("[data-toc-items]")
              |> render() =~ "Overview"
    end

    test "generates TOC from dynamic content", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/dynamic-page")
      
      # Update page content
      send(view.pid, {:content_updated, """
      ## New Section
      ### New Subsection
      ## Another Section
      """})
      
      # TOC should regenerate
      assert view
             |> element("[data-toc-items]")
             |> render() =~ "New Section"
      
      assert view
             |> element("[data-toc-items]")
             |> render() =~ "New Subsection"
    end
  end

  describe "accessibility features" do
    test "TOC has proper ARIA attributes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/test-page")
      
      assert html =~ ~s(role="navigation")
      assert html =~ ~s(aria-label="Table of contents")
      assert html =~ ~s(aria-current="true")
    end

    test "keyboard navigation with screen reader support", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/docs/test-page")
      
      # Tab through TOC items
      view
      |> element("[data-toc-container]")
      |> render_keydown(%{"key" => "Tab"})
      
      assert view
             |> element("[data-toc-container]")
             |> render() =~ ~s(aria-selected="true")
    end
  end
end