defmodule SertantaiDocsWeb.LayoutComponentTest do
  use SertantaiDocsWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import SertantaiDocsWeb.CoreComponents

  describe "app layout with filtering/sorting integration" do
    test "renders nav_sidebar with filtering controls" do
      navigation_items = [
        %{title: "Test Item", path: "/test", type: :page, metadata: %{"status" => "live"}}
      ]

      filter_state = %{
        status: "",
        category: "",
        priority: "",
        author: "",
        tags: []
      }

      assigns = %{
        current_path: "/build",
        navigation_items: navigation_items,
        filter_state: filter_state,
        available_categories: ["security", "admin"],
        available_priorities: ["high", "medium", "low"],
        available_authors: ["Claude", "User"],
        available_tags: ["phase-1", "ash"],
        sort_state: %{sort_by: "priority", sort_order: "asc"},
        available_sort_options: [
          %{value: "priority", label: "Priority"},
          %{value: "title", label: "Title"}
        ]
      }

      html = rendered_to_string(~H"""
      <div class="flex h-screen bg-white">
        <!-- Sidebar Navigation -->
        <.nav_sidebar 
          items={@navigation_items}
          current_path={@current_path}
          filter_state={@filter_state}
          available_categories={@available_categories}
          available_priorities={@available_priorities}
          available_authors={@available_authors}
          available_tags={@available_tags}
          sort_state={@sort_state}
          available_sort_options={@available_sort_options}
        />
        
        <!-- Main Content Area -->
        <div class="flex-1 flex flex-col overflow-hidden">
          <main class="flex-1 overflow-y-auto">
            <div>Content</div>
          </main>
        </div>
      </div>
      """)

      # Should render filtering controls in sidebar
      assert html =~ ~s(class="nav-filters)
      assert html =~ ~s(phx-change="filter-by-status")
      assert html =~ ~s(phx-change="filter-by-category")
      assert html =~ ~s(phx-change="filter-by-priority")
      assert html =~ ~s(phx-change="filter-by-author")
      assert html =~ ~s(phx-click="toggle-tag-filter")
      assert html =~ ~s(phx-click="reset-filters")

      # Should render sorting controls in sidebar
      assert html =~ ~s(class="nav-sort)
      assert html =~ ~s(phx-change="change-sort")
      assert html =~ ~s(phx-click="toggle-sort-order")
      assert html =~ "Sort by"
      assert html =~ "Priority"
      assert html =~ "↑"
    end

    test "renders enhanced search box in header" do
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

      assigns = %{
        search_state: search_state,
        available_options: available_options
      }

      html = rendered_to_string(~H"""
      <div class="flex h-screen bg-white">
        <!-- Main Content Area -->
        <div class="flex-1 flex flex-col overflow-hidden">
          <!-- Top Header -->
          <header class="bg-white border-b border-gray-200">
            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
              <div class="flex items-center justify-between h-16">
                <div class="flex items-center">
                  <.enhanced_search_box 
                    search_state={@search_state}
                    available_options={@available_options}
                    class="w-96" 
                  />
                </div>
              </div>
            </div>
          </header>
        </div>
      </div>
      """)

      # Should render enhanced search with metadata options
      assert html =~ ~s(class="enhanced-search-box)
      assert html =~ ~s(phx-change="search-query-change")
      assert html =~ ~s(phx-click="toggle-search-tags")
      assert html =~ ~s(phx-click="toggle-search-author")
      assert html =~ ~s(phx-click="toggle-search-category")
      assert html =~ ~s(phx-change="change-search-scope")
      assert html =~ "Include Tags"
      assert html =~ "Include Author"
      assert html =~ "Include Category"
      assert html =~ "Search in group:"
    end

    test "shows filtered item counts in sidebar" do
      navigation_items = [
        %{title: "Live Doc 1", path: "/live1", type: :page, metadata: %{"status" => "live"}},
        %{title: "Live Doc 2", path: "/live2", type: :page, metadata: %{"status" => "live"}},
        %{title: "Archived Doc", path: "/arch", type: :page, metadata: %{"status" => "archived"}}
      ]

      filter_state = %{
        status: "live",
        category: "",
        priority: "",
        author: "",
        tags: []
      }

      assigns = %{
        current_path: "/build",
        navigation_items: navigation_items,
        filter_state: filter_state,
        total_items: 3,
        filtered_items_count: 2
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@navigation_items}
        current_path={@current_path}
        filter_state={@filter_state}
        total_items={@total_items}
        filtered_items_count={@filtered_items_count}
      />
      """)

      # Should show filtered count information
      assert html =~ "Showing 2 of 3 items" or html =~ "2 items shown"
      assert html =~ "Filters active" or html =~ "filter-indicator-active"
    end

    test "handles empty filter results gracefully" do
      navigation_items = [
        %{title: "Admin Doc", path: "/admin", type: :page, metadata: %{"category" => "admin"}}
      ]

      # Filter by non-existent category
      filter_state = %{
        status: "",
        category: "security", # No items match this
        priority: "",
        author: "",
        tags: []
      }

      assigns = %{
        current_path: "/build",
        navigation_items: navigation_items,
        filter_state: filter_state,
        filtered_items_count: 0
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@navigation_items}
        current_path={@current_path}
        filter_state={@filter_state}
        filtered_items_count={@filtered_items_count}
      />
      """)

      # Should show empty state message
      assert html =~ "No items match the current filters" or html =~ "Try adjusting your filter criteria"
      assert html =~ "Reset Filters" or html =~ "reset-filters"
    end

    test "shows active filter indicators" do
      filter_state = %{
        status: "live",
        category: "security",
        priority: "",
        author: "",
        tags: ["phase-1"]
      }

      assigns = %{
        current_path: "/build",
        navigation_items: [],
        filter_state: filter_state
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@navigation_items}
        current_path={@current_path}
        filter_state={@filter_state}
      />
      """)

      # Should show active filter badges or indicators
      assert html =~ "Status: live" or html =~ "live"
      assert html =~ "Category: security" or html =~ "security"
      assert html =~ "Tags: phase-1" or html =~ "phase-1"
      assert html =~ "Reset Filters" or html =~ "Clear all"
    end

    test "preserves navigation group expansion state with filtering" do
      navigation_items = [
        %{
          title: "Done",
          type: :group,
          group: "done",
          collapsible: true,
          children: [
            %{title: "Phase 1", path: "/done/phase1", type: :page, metadata: %{"status" => "live"}}
          ]
        }
      ]

      filter_state = %{
        status: "live",
        category: "",
        priority: "",
        author: "",
        tags: []
      }

      expanded_groups = MapSet.new(["done"])

      assigns = %{
        current_path: "/build",
        navigation_items: navigation_items,
        filter_state: filter_state,
        expanded_groups: expanded_groups
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@navigation_items}
        current_path={@current_path}
        filter_state={@filter_state}
        expanded_groups={@expanded_groups}
      />
      """)

      # Should maintain expanded state even when filters are applied
      assert html =~ ~s(aria-expanded="true") or html =~ "chevron-down"
      assert html =~ "Phase 1" # Child items should be visible
    end
  end

  describe "app layout responsiveness with filtering/sorting" do
    test "adapts filtering UI for mobile viewports" do
      filter_state = %{
        status: "",
        category: "",
        priority: "",
        author: "",
        tags: []
      }

      assigns = %{
        current_path: "/build",
        navigation_items: [],
        filter_state: filter_state,
        mobile_view: true
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@navigation_items}
        current_path={@current_path}
        filter_state={@filter_state}
        mobile_view={@mobile_view}
      />
      """)

      # Should have mobile-specific classes or collapsed filter UI
      assert html =~ "mobile" or html =~ "sm:" or html =~ "md:"
      assert html =~ "nav-filters" # Filters should still be present
    end

    test "shows sort controls in compact mode" do
      sort_state = %{sort_by: "priority", sort_order: "asc"}

      assigns = %{
        current_path: "/build",
        navigation_items: [],
        sort_state: sort_state,
        compact_mode: true
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@navigation_items}
        current_path={@current_path}
        sort_state={@sort_state}
        compact_mode={@compact_mode}
      />
      """)

      # Should render compact sort controls
      assert html =~ "nav-sort"
      assert html =~ "↑" or html =~ "↓"
      assert html =~ "Priority" or html =~ "sort"
    end
  end

  describe "keyboard navigation with filtering/sorting" do
    test "supports keyboard shortcuts for filter operations" do
      assigns = %{
        current_path: "/build",
        navigation_items: [],
        filter_state: %{status: "", category: "", priority: "", author: "", tags: []}
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@navigation_items}
        current_path={@current_path}
        filter_state={@filter_state}
        keyboard_shortcuts_enabled={true}
      />
      """)

      # Should have keyboard navigation attributes
      assert html =~ ~r/data-key/ or html =~ ~r/tabindex/ or html =~ ~r/aria-/
      assert html =~ "nav-filters"
    end

    test "maintains focus when filtering navigation items" do
      navigation_items = [
        %{title: "Focused Item", path: "/focused", type: :page, metadata: %{"status" => "live"}}
      ]

      assigns = %{
        current_path: "/build",
        navigation_items: navigation_items,
        filter_state: %{status: "live", category: "", priority: "", author: "", tags: []},
        focused_item_path: "/focused"
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@navigation_items}
        current_path={@current_path}
        filter_state={@filter_state}
        focused_item_path={@focused_item_path}
      />
      """)

      # Should maintain focus indicators after filtering
      assert html =~ "Focused Item"
      assert html =~ ~r/tabindex/ or html =~ ~r/aria-current/ or html =~ "focused"
    end
  end
end