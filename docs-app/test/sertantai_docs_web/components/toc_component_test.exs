defmodule SertantaiDocsWeb.Components.TOCComponentTest do
  use SertantaiDocsWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias SertantaiDocsWeb.Components.TOC

  describe "table_of_contents/1 component" do
    test "renders TOC with headings", %{conn: conn} do
      headings = [
        %{level: 2, text: "Introduction", id: "introduction"},
        %{level: 3, text: "Overview", id: "overview"},
        %{level: 2, text: "Installation", id: "installation"}
      ]

      component = render_component(&TOC.table_of_contents/1, headings: headings)
      
      assert component =~ "Introduction"
      assert component =~ "Overview"
      assert component =~ "Installation"
      
      assert component =~ ~s(href="#introduction")
      assert component =~ ~s(href="#overview")
      assert component =~ ~s(href="#installation")
    end

    test "renders hierarchical structure", %{conn: conn} do
      tree = [
        %{
          level: 2,
          text: "Getting Started",
          id: "getting-started",
          children: [
            %{level: 3, text: "Prerequisites", id: "prerequisites", children: []},
            %{level: 3, text: "Installation", id: "installation", children: []}
          ]
        }
      ]

      component = render_component(&TOC.toc_tree/1, tree: tree)
      
      assert component =~ "Getting Started"
      assert component =~ "Prerequisites"
      assert component =~ "Installation"
      
      # Check nesting structure
      assert component =~ ~s(data-level="2")
      assert component =~ ~s(data-level="3")
    end

    test "renders empty state when no headings", %{conn: conn} do
      component = render_component(&TOC.table_of_contents/1, headings: [])
      
      assert component =~ "No table of contents available"
    end

    test "applies custom CSS classes", %{conn: conn} do
      headings = [
        %{level: 2, text: "Test", id: "test"}
      ]

      component = render_component(&TOC.table_of_contents/1, 
        headings: headings,
        class: "custom-toc-class"
      )
      
      assert component =~ "custom-toc-class"
    end

    test "renders with title", %{conn: conn} do
      headings = [
        %{level: 2, text: "Section", id: "section"}
      ]

      component = render_component(&TOC.table_of_contents/1, 
        headings: headings,
        title: "On This Page"
      )
      
      assert component =~ "On This Page"
    end

    test "highlights active section", %{conn: conn} do
      headings = [
        %{level: 2, text: "Section 1", id: "section-1"},
        %{level: 2, text: "Section 2", id: "section-2"}
      ]

      component = render_component(&TOC.table_of_contents/1, 
        headings: headings,
        active_id: "section-2"
      )
      
      assert component =~ ~s(data-active)
      assert component =~ ~s(id="section-2")
    end

    test "renders collapsible sections", %{conn: conn} do
      tree = [
        %{
          level: 2,
          text: "Collapsible Section",
          id: "collapsible",
          children: [
            %{level: 3, text: "Child", id: "child", children: []}
          ]
        }
      ]

      component = render_component(&TOC.toc_tree/1, 
        tree: tree,
        collapsible: true
      )
      
      assert component =~ ~s(phx-click="toggle-toc-section")
      assert component =~ ~s(phx-value-section="collapsible")
    end
  end

  describe "toc_sidebar/1 component" do
    test "renders sidebar with TOC", %{conn: conn} do
      toc = %{
        tree: [
          %{
            level: 2,
            text: "Overview",
            id: "overview",
            children: []
          }
        ],
        headings: [%{level: 2, text: "Overview", id: "overview"}],
        flat: [%{level: 2, text: "Overview", id: "overview"}]
      }

      component = render_component(&TOC.toc_sidebar/1, toc: toc)
      
      assert component =~ "On This Page"
      assert component =~ "Overview"
      assert component =~ ~s(toc-sidebar)
    end

    test "renders sticky positioning", %{conn: conn} do
      toc = %{tree: [], headings: [], flat: []}
      
      component = render_component(&TOC.toc_sidebar/1, 
        toc: toc,
        sticky: true
      )
      
      assert component =~ "sticky"
      assert component =~ "top-"
    end

    test "renders back to top button", %{conn: conn} do
      toc = %{
        tree: [%{level: 2, text: "Test", id: "test", children: []}],
        headings: [],
        flat: []
      }
      
      component = render_component(&TOC.toc_sidebar/1, 
        toc: toc,
        show_back_to_top: true
      )
      
      assert component =~ "Back to top"
      assert component =~ ~s(href="#top")
    end
  end

  describe "inline_toc/1 component" do
    test "renders inline TOC for article", %{conn: conn} do
      toc = %{
        tree: [
          %{
            level: 2,
            text: "Introduction",
            id: "introduction",
            children: [
              %{level: 3, text: "Background", id: "background", children: []}
            ]
          }
        ],
        headings: [],
        flat: []
      }

      component = render_component(&TOC.inline_toc/1, toc: toc)
      
      assert component =~ "Table of Contents"
      assert component =~ "Introduction"
      assert component =~ "Background"
      assert component =~ ~s(inline-toc)
    end

    test "can be collapsed by default", %{conn: conn} do
      toc = %{tree: [], headings: [], flat: []}
      
      component = render_component(&TOC.inline_toc/1, 
        toc: toc,
        collapsed: true
      )
      
      assert component =~ ~s(data-collapsed)
      assert component =~ "Expand"
    end
  end
end