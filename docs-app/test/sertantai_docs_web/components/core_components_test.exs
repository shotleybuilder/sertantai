defmodule SertantaiDocsWeb.CoreComponentsTest do
  use SertantaiDocsWeb.ConnCase, async: true
  
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import SertantaiDocsWeb.CoreComponents

  describe "nav_sidebar/1" do
    test "renders sidebar with navigation items" do
      assigns = %{
        items: [
          %{title: "Home", path: "/"},
          %{title: "Developer", path: "/dev", children: [
            %{title: "Setup", path: "/dev/setup"}
          ]}
        ],
        current_path: "/",
        class: "test-class"
      }

      html = render_component(&nav_sidebar/1, assigns)
      
      assert html =~ "Sertantai Docs"
      assert html =~ "Home"
      assert html =~ "Developer"
      assert html =~ "Setup"
      assert html =~ "test-class"
      assert html =~ ~s(href="/")
      # Developer item should become a collapsible button since it has children
      refute html =~ ~s(href="/dev")
      assert html =~ ~s(href="/dev/setup")
    end

    test "highlights current path" do
      assigns = %{
        items: [
          %{title: "Home", path: "/"},
          %{title: "Developer", path: "/dev"}
        ],
        current_path: "/dev",
        class: ""
      }

      html = render_component(&nav_sidebar/1, assigns)
      
      # Should contain styling for active item
      assert html =~ "bg-blue-100" || html =~ "text-blue-600" || html =~ "font-semibold"
    end

    test "renders nested navigation items" do
      assigns = %{
        items: [
          %{title: "Developer", path: "/dev", children: [
            %{title: "Setup", path: "/dev/setup"},
            %{title: "Architecture", path: "/dev/architecture"}
          ]}
        ],
        current_path: "/",
        class: ""
      }

      html = render_component(&nav_sidebar/1, assigns)
      
      assert html =~ "Setup"
      assert html =~ "Architecture"
      assert html =~ ~s(href="/dev/setup")
      assert html =~ ~s(href="/dev/architecture")
    end
  end

  describe "nav_item/1" do
    test "renders simple navigation item" do
      assigns = %{
        item: %{title: "Test Page", path: "/test"},
        current_path: "/",
        class: "nav-item"
      }

      html = render_component(&nav_item/1, assigns)
      
      assert html =~ "Test Page"
      assert html =~ ~s(href="/test")
      assert html =~ "nav-item"
    end

    test "renders active navigation item" do
      assigns = %{
        item: %{title: "Current Page", path: "/current"},
        current_path: "/current",
        class: ""
      }

      html = render_component(&nav_item/1, assigns)
      
      assert html =~ "Current Page"
      # Should have active styling
      assert html =~ "bg-blue-100" || html =~ "text-blue-600" || html =~ "font-semibold"
    end

    test "renders item with children" do
      assigns = %{
        item: %{
          title: "Parent", 
          path: "/parent",
          children: [
            %{title: "Child", path: "/parent/child"}
          ]
        },
        current_path: "/",
        class: ""
      }

      html = render_component(&nav_item/1, assigns)
      
      assert html =~ "Parent"
      assert html =~ "Child"
      # Parent item should become a collapsible button since it has children
      refute html =~ ~s(href="/parent")
      assert html =~ ~s(href="/parent/child")
      # Should have collapsible button functionality
      assert html =~ "toggleNavigationGroup"
      assert html =~ "hero-chevron-right"
    end
  end

  describe "doc_content/1" do
    test "renders content with default styling" do
      assigns = %{}
      html = rendered_to_string(~H"""
      <.doc_content class="custom-class">
        <p>Test content</p>
      </.doc_content>
      """)
      
      assert html =~ "max-w-4xl"  # Default max width
      assert html =~ "custom-class"
      assert html =~ "<p>Test content</p>"
    end

    test "applies prose styling" do
      assigns = %{}
      html = rendered_to_string(~H"""
      <.doc_content class="">
        Content
      </.doc_content>
      """)
      
      assert html =~ "prose"
      assert html =~ "prose-lg"
    end
  end

  describe "breadcrumb/1" do
    test "renders breadcrumb navigation" do
      assigns = %{
        items: [
          %{title: "Home", path: "/"},
          %{title: "Developer", path: "/dev"},
          %{title: "Setup", path: nil}  # Current page
        ],
        class: "breadcrumb-test"
      }

      html = render_component(&breadcrumb/1, assigns)
      
      assert html =~ "Home"
      assert html =~ "Developer"
      assert html =~ "Setup"
      assert html =~ "breadcrumb-test"
      assert html =~ ~s(href="/")
      assert html =~ ~s(href="/dev")
    end

    test "handles empty breadcrumbs" do
      assigns = %{
        items: [],
        class: ""
      }

      html = render_component(&breadcrumb/1, assigns)
      
      # Should render container but no items
      assert html =~ "breadcrumb" || html =~ "nav"
    end

    test "differentiates between links and current page" do
      assigns = %{
        items: [
          %{title: "Home", path: "/"},
          %{title: "Current", path: nil}
        ],
        class: ""
      }

      html = render_component(&breadcrumb/1, assigns)
      
      assert html =~ ~s(href="/")  # Home should be a link
      refute html =~ ~s(href="#{nil}")  # Current should not be a link
    end
  end

  describe "doc_header/1" do
    test "renders page header with title and description" do
      assigns = %{
        title: "Test Documentation",
        description: "This is a test page",
        class: "header-test"
      }

      html = render_component(&doc_header/1, assigns)
      
      assert html =~ "Test Documentation"
      assert html =~ "This is a test page"
      assert html =~ "header-test"
    end

    test "renders header with title only" do
      assigns = %{
        title: "Simple Title",
        description: nil,
        class: ""
      }

      html = render_component(&doc_header/1, assigns)
      
      assert html =~ "Simple Title"
      # Should not render empty description elements
      refute html =~ "<p></p>"
    end

    test "applies proper heading hierarchy" do
      assigns = %{
        title: "Main Title",
        description: "Subtitle",
        class: ""
      }

      html = render_component(&doc_header/1, assigns)
      
      assert html =~ "<h1" || html =~ "text-3xl"  # Should use h1 or equivalent styling
    end
  end

  describe "search_box/1" do
    test "renders search input with proper attributes" do
      assigns = %{
        class: "search-test"
      }

      html = render_component(&search_box/1, assigns)
      
      assert html =~ "search-test"
      assert html =~ ~s(type="text")
      assert html =~ ~s(placeholder="Search documentation...")
      assert html =~ "search" # Should have search-related classes or attributes
    end

    test "includes search icon" do
      assigns = %{class: ""}

      html = render_component(&search_box/1, assigns)
      
      # Should include heroicon or search icon
      assert html =~ "hero-magnifying-glass" || html =~ "search-icon"
    end
  end

  describe "error handling" do
    test "handles missing navigation items gracefully" do
      assigns = %{
        items: nil,
        current_path: "/",
        class: ""
      }

      # Should not crash when items is nil
      html = render_component(&nav_sidebar/1, assigns)
      assert is_binary(html)
    end

    test "handles malformed navigation items" do
      assigns = %{
        items: [
          %{title: "Valid", path: "/valid"},
          %{},  # Invalid item missing required fields
          %{title: "Another Valid", path: "/another"}
        ],
        current_path: "/",
        class: ""
      }

      # Should render valid items and skip invalid ones
      html = render_component(&nav_sidebar/1, assigns)
      assert html =~ "Valid"
      assert html =~ "Another Valid"
    end
  end

  describe "nav_item chevron rotation" do
    test "renders chevron-right icon when collapsed" do
      item = %{
        type: :group,
        title: "Build Docs",
        group: "build",
        children: [
          %{title: "Child 1", path: "/child1"},
          %{title: "Child 2", path: "/child2"}
        ]
      }

      expanded_groups = MapSet.new([])

      html =
        render_component(&nav_item/1, %{
          item: item,
          current_path: "/test",
          expanded_groups: expanded_groups,
          class: ""
        })

      # Should render chevron-right when collapsed
      assert html =~ "hero-chevron-right"
      refute html =~ "hero-chevron-down"
      
      # Button should have aria-expanded=false
      assert html =~ ~r/aria-expanded="false"/
    end

    test "renders chevron-down icon when expanded" do
      item = %{
        type: :group,
        title: "Build Docs", 
        group: "build",
        children: [
          %{title: "Child 1", path: "/child1"},
          %{title: "Child 2", path: "/child2"}
        ]
      }

      expanded_groups = MapSet.new(["build"])

      html =
        render_component(&nav_item/1, %{
          item: item,
          current_path: "/test",
          expanded_groups: expanded_groups,
          class: ""
        })

      # Should render chevron-down when expanded
      assert html =~ "hero-chevron-down"
      refute html =~ "hero-chevron-right"
      
      # Button should have aria-expanded=true
      assert html =~ ~r/aria-expanded="true"/
    end

    test "renders correct data attributes for JavaScript integration" do
      item = %{
        type: :group,
        title: "Developer Docs",
        group: "dev",
        children: [%{title: "Child", path: "/child"}]
      }

      expanded_groups = MapSet.new([])

      html =
        render_component(&nav_item/1, %{
          item: item,
          current_path: "/test",
          expanded_groups: expanded_groups,
          class: ""
        })

      # Should have required data attributes for JavaScript
      assert html =~ ~r/data-group="dev"/
      assert html =~ ~r/onclick="toggleNavigationGroup\(this\)"/
      assert html =~ ~r/data-state-key/
      # Note: data-default-expanded may not be present for all items
    end

    test "main sections without type=group are also collapsible when they have children" do
      item = %{
        title: "Home",
        children: [
          %{title: "Overview", path: "/overview"},
          %{title: "Getting Started", path: "/getting-started"}
        ]
      }

      expanded_groups = MapSet.new([])

      html =
        render_component(&nav_item/1, %{
          item: item,
          current_path: "/test",
          expanded_groups: expanded_groups,
          class: ""
        })

      # Should be collapsible and have chevron icon
      assert html =~ "hero-chevron-right"
      assert html =~ ~r/onclick="toggleNavigationGroup\(this\)"/
      assert html =~ ~r/aria-expanded="false"/
    end

    test "items without children are not collapsible" do
      item = %{
        title: "Simple Link",
        path: "/simple"
      }

      expanded_groups = MapSet.new([])

      html =
        render_component(&nav_item/1, %{
          item: item,
          current_path: "/test",
          expanded_groups: expanded_groups,
          class: ""
        })

      # Should not have chevron icons or collapsible behavior
      refute html =~ "hero-chevron"
      refute html =~ "toggleNavigationGroup"
      refute html =~ "aria-expanded"
    end
  end

  describe "accessibility" do
    test "nav_sidebar includes proper ARIA attributes" do
      assigns = %{
        items: [%{title: "Home", path: "/"}],
        current_path: "/",
        class: ""
      }

      html = render_component(&nav_sidebar/1, assigns)
      
      # Should include navigation landmarks
      assert html =~ "nav" || html =~ "navigation"
    end

    test "breadcrumb includes proper navigation structure" do
      assigns = %{
        items: [
          %{title: "Home", path: "/"},
          %{title: "Current", path: nil}
        ],
        class: ""
      }

      html = render_component(&breadcrumb/1, assigns)
      
      # Should be structured as navigation
      assert html =~ "nav" || html =~ "breadcrumb"
    end

    test "search box includes proper labels" do
      assigns = %{class: ""}

      html = render_component(&search_box/1, assigns)
      
      # Should have accessible label
      assert html =~ "Search" || html =~ "aria-label" || html =~ "placeholder"
    end
  end
end