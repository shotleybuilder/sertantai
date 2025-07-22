defmodule SertantaiDocsWeb.NavigationComponentTest do
  use SertantaiDocsWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Phoenix.Component
  import SertantaiDocsWeb.CoreComponents

  alias SertantaiDocs.MarkdownProcessor

  describe "nav_item/1 component with collapsible groups" do
    test "renders group with collapse/expand button" do
      group_item = %{
        title: "Done",
        type: :group,
        group: "done",
        collapsible: true,
        default_expanded: false,
        children: [
          %{title: "Phase 1", path: "/build/done_phase1", type: :page}
        ],
        icon: "hero-check-circle",
        icon_color: "text-green-600",
        state_key: "build_group_done",
        aria_label: "Done group, collapsible section with 1 item",
        item_count: 1
      }

      assigns = %{group_item: group_item}
      
      html = rendered_to_string(~H"""
      <.nav_item item={@group_item} current_path="/build" expanded_groups={MapSet.new()} />
      """)

      # Should render collapsible group header with button
      assert html =~ ~r/data-group="done"/
      assert html =~ ~r/aria-label="Done group, collapsible section with 1 item"/
      
      # Should have toggle button
      assert html =~ ~r/onclick="toggleNavigationGroup\(this\)"/
      
      # Should show chevron icon indicating collapsed state
      assert html =~ ~r/hero-chevron-right/
      refute html =~ ~r/hero-chevron-down/
      
      # Should show item count
      assert html =~ ~r/\(1\)/
      
      # Should have group icon
      assert html =~ ~r/hero-check-circle/
      assert html =~ ~r/text-green-600/
      
      # Children should be hidden via CSS when collapsed
      assert html =~ ~r/class="[^"]*hidden[^"]*"/
      assert html =~ "Phase 1"  # Children are in DOM for accessibility
    end

    test "renders expanded group with visible children" do
      group_item = %{
        title: "Todo",
        type: :group,
        group: "todo",
        collapsible: true,
        default_expanded: true,
        children: [
          %{title: "Security Plan", path: "/build/todo_security", type: :page},
          %{title: "Phase 2 Plan", path: "/build/todo_phase2", type: :page}
        ],
        icon: "hero-clipboard-document-list",
        icon_color: "text-orange-600",
        state_key: "build_group_todo",
        item_count: 2
      }

      assigns = %{
        item: group_item,
        current_path: "/build",
        expanded_groups: MapSet.new(["todo"])  # Todo group is expanded
      }

      html = rendered_to_string(~H"""
      <.nav_item item={@item} current_path={@current_path} expanded_groups={@expanded_groups} />
      """)

      # Should show chevron down for expanded state
      assert html =~ ~r/hero-chevron-down/
      refute html =~ ~r/hero-chevron-right/
      
      # Children should be visible when expanded
      assert html =~ "Security Plan"
      assert html =~ "Phase 2 Plan"
      assert html =~ "/build/todo_security"
      assert html =~ "/build/todo_phase2"
      
      # Should have expanded state indicators
      assert html =~ ~r/aria-expanded="true"/
    end

    test "renders non-collapsible regular page item" do
      page_item = %{
        title: "Regular Page",
        path: "/build/regular_page",
        type: :page
      }

      assigns = %{
        item: page_item,
        current_path: "/build",
        expanded_groups: MapSet.new()
      }

      html = rendered_to_string(~H"""
      <.nav_item item={@item} current_path={@current_path} expanded_groups={@expanded_groups} />
      """)

      # Should render as simple link without group functionality
      assert html =~ ~r/<a[^>]*href="\/build\/regular_page"/
      assert html =~ "Regular Page"
      
      # Should not have group-related elements
      refute html =~ ~r/onclick="toggleNavigationGroup\(this\)"/
      refute html =~ ~r/hero-chevron/
      refute html =~ ~r/nav-group/
    end

    test "handles nested sub-groups correctly" do
      group_with_subgroups = %{
        title: "Done",
        type: :group,
        group: "done",
        collapsible: true,
        children: [
          %{
            title: "Phases",
            type: :sub_group,
            collapsible: true,
            children: [
              %{title: "Phase 1", path: "/build/done_phase1", type: :page},
              %{title: "Phase 8", path: "/build/done_phase8", type: :page}
            ]
          },
          %{title: "Direct Item", path: "/build/done_direct", type: :page}
        ],
        icon: "hero-check-circle",
        state_key: "build_group_done",
        item_count: 3
      }

      assigns = %{
        item: group_with_subgroups,
        current_path: "/build",
        expanded_groups: MapSet.new(["done"])
      }

      html = rendered_to_string(~H"""
      <.nav_item item={@item} current_path={@current_path} expanded_groups={@expanded_groups} />
      """)

      # Should render main group as expandable
      assert html =~ ~r/onclick="toggleNavigationGroup\(this\)"/
      assert html =~ ~r/data-group="done"/
      
      # Should render sub-group as collapsible
      assert html =~ "Phases"
      
      # Should show nested structure when expanded
      assert html =~ "Phase 1"
      assert html =~ "Phase 8"
      assert html =~ "Direct Item"
    end

    test "applies correct CSS classes for different group types" do
      test_cases = [
        {
          "done", 
          "hero-check-circle", 
          "text-green-600",
          ["nav-group-done", "nav-group-header-done"]
        },
        {
          "strategy",
          "hero-document-magnifying-glass", 
          "text-blue-600",
          ["nav-group-strategy", "nav-group-header-strategy"]
        },
        {
          "todo",
          "hero-clipboard-document-list",
          "text-orange-600", 
          ["nav-group-todo", "nav-group-header-todo"]
        }
      ]

      for {group_name, icon, color, css_classes} <- test_cases do
        group_item = %{
          title: String.capitalize(group_name),
          type: :group,
          group: group_name,
          collapsible: true,
          children: [],
          icon: icon,
          icon_color: color,
          css_class: "nav-group nav-group-#{group_name}",
          header_class: "nav-group-header nav-group-header-#{group_name}",
          state_key: "build_group_#{group_name}"
        }

        assigns = %{
          item: group_item,
          current_path: "/build",
          expanded_groups: MapSet.new()
        }

        html = rendered_to_string(~H"""
        <.nav_item item={@item} current_path={@current_path} expanded_groups={@expanded_groups} />
        """)

        # Should have correct icon and color
        assert html =~ icon
        assert html =~ color
        
        # Should have group-specific CSS classes
        for css_class <- css_classes do
          assert html =~ css_class
        end
      end
    end

    test "handles keyboard navigation attributes" do
      group_item = %{
        title: "Done",
        type: :group,
        group: "done",
        collapsible: true,
        children: [%{title: "Child", path: "/child", type: :page}],
        keyboard_shortcuts: %{
          toggle: "Enter",
          focus_first: "ArrowDown",
          focus_parent: "ArrowUp"
        },
        state_key: "build_group_done"
      }

      assigns = %{group_item: group_item}
      
      html = rendered_to_string(~H"""
      <.nav_item item={@group_item} current_path="/build" expanded_groups={MapSet.new()} />
      """)

      # Should have keyboard navigation data attributes
      assert html =~ ~r/data-key-toggle="Enter"/
      assert html =~ ~r/data-key-focus-first="ArrowDown"/
      assert html =~ ~r/data-key-focus-parent="ArrowUp"/
      
      # Should have tabindex for keyboard focus
      assert html =~ ~r/tabindex="0"/
    end

    test "handles mobile responsive behavior" do
      group_item = %{
        title: "Strategy",
        type: :group,
        group: "strategy",
        collapsible: true,
        children: [%{title: "Analysis", path: "/analysis", type: :page}],
        mobile_behavior: %{
          collapse_on_mobile: true,
          show_item_count: true
        },
        item_count: 1,
        state_key: "build_group_strategy"
      }

      assigns = %{group_item: group_item}
      
      html = rendered_to_string(~H"""
      <.nav_item item={@group_item} current_path="/build" expanded_groups={MapSet.new()} />
      """)

      # Should have mobile-specific data attributes
      assert html =~ ~r/data-mobile-collapse/
      assert html =~ ~r/data-mobile-show-count/
      
      # Should show item count for mobile
      assert html =~ ~r/\(1\)/
    end
  end

  describe "navigation state management" do
    test "tracks expanded groups in assigns" do
      # This will be tested when we implement the LiveView logic
      # For now, verify the data structure expectations
      
      expanded_groups = MapSet.new(["todo", "done"])
      
      assert MapSet.member?(expanded_groups, "todo")
      assert MapSet.member?(expanded_groups, "done")
      refute MapSet.member?(expanded_groups, "strategy")
      
      # Test adding/removing groups
      expanded = MapSet.put(expanded_groups, "strategy")
      assert MapSet.member?(expanded, "strategy")
      
      collapsed = MapSet.delete(expanded, "todo")
      refute MapSet.member?(collapsed, "todo")
    end

    test "provides default expansion state based on group metadata" do
      # Test the logic for determining default expanded state
      {:ok, navigation} = MarkdownProcessor.generate_navigation()
      
      build_section = Enum.find(navigation, fn item ->
        Map.get(item, :title) == "Build Docs"
      end)
      
      assert build_section
      
      groups = Map.get(build_section, :children, [])
      |> Enum.filter(fn child -> Map.get(child, :type) == :group end)
      
      # Should have multiple groups
      assert length(groups) > 0
      
      # Todo group should default to expanded
      todo_group = Enum.find(groups, fn g -> Map.get(g, :group) == "todo" end)
      if todo_group do
        assert Map.get(todo_group, :default_expanded) == true
      end
      
      # Done group should default to collapsed
      done_group = Enum.find(groups, fn g -> Map.get(g, :group) == "done" end)
      if done_group do
        assert Map.get(done_group, :default_expanded) == false
      end
    end
  end

  describe "accessibility and ARIA attributes" do
    test "includes proper ARIA labels and roles" do
      group_item = %{
        title: "Done",
        type: :group,
        group: "done",
        collapsible: true,
        children: [%{title: "Child", path: "/child", type: :page}],
        aria_label: "Done group, collapsible section with 1 item",
        aria_expanded: false,
        state_key: "build_group_done"
      }

      assigns = %{group_item: group_item}
      
      html = rendered_to_string(~H"""
      <.nav_item item={@group_item} current_path="/build" expanded_groups={MapSet.new()} />
      """)

      # Should have proper ARIA attributes
      assert html =~ ~r/aria-label="Done group, collapsible section with 1 item"/
      assert html =~ ~r/aria-expanded="false"/
      assert html =~ ~r/role="button"/
      
      # Should have accessible button for screen readers
    end

    test "updates ARIA attributes when state changes" do
      group_item = %{
        title: "Todo",
        type: :group,
        group: "todo",
        collapsible: true,
        children: [%{title: "Plan", path: "/plan", type: :page}],
        aria_label: "Todo group, collapsible section with 1 item",
        state_key: "build_group_todo"
      }

      # Test collapsed state
      assigns = %{group_item: group_item}
      
      html_collapsed = rendered_to_string(~H"""
      <.nav_item item={@group_item} current_path="/build" expanded_groups={MapSet.new()} />
      """)

      assert html_collapsed =~ ~r/aria-expanded="false"/

      # Test expanded state  
      assigns = %{group_item: group_item}
      
      html_expanded = rendered_to_string(~H"""
      <.nav_item item={@group_item} current_path="/build" expanded_groups={MapSet.new(["todo"])} />
      """)

      assert html_expanded =~ ~r/aria-expanded="true"/
    end
  end

  describe "navigation filtering system" do
    test "renders filter controls with status dropdown" do
      filter_state = %{
        status: "",
        category: "",
        priority: "",
        author: "",
        tags: []
      }

      assigns = %{
        filter_state: filter_state,
        available_categories: ["implementation", "security", "admin", "docs", "analysis", "planning"],
        available_priorities: ["high", "medium", "low"],
        available_authors: ["Claude", "User"],
        available_tags: ["phase-1", "ash", "security", "admin", "testing"]
      }

      html = rendered_to_string(~H"""
      <div class="nav-filters mb-4 p-3 bg-gray-50 rounded-md">
        <div class="filter-section mb-2">
          <label class="text-xs font-medium text-gray-700">Status</label>
          <select phx-change="filter-by-status" class="text-xs w-full">
            <option value="">All</option>
            <option value="live" selected={@filter_state.status == "live"}>Live</option>
            <option value="archived" selected={@filter_state.status == "archived"}>Archived</option>
          </select>
        </div>
      </div>
      """)

      # Should render status filter dropdown
      assert html =~ ~s(phx-change="filter-by-status")
      assert html =~ ~s(option value="live")
      assert html =~ ~s(option value="archived")
      assert html =~ "All"
    end

    test "renders category filter dropdown with available categories" do
      filter_state = %{category: "security"}
      available_categories = ["implementation", "security", "admin", "docs"]

      assigns = %{filter_state: filter_state, available_categories: available_categories}

      html = rendered_to_string(~H"""
      <div class="filter-section">
        <label class="text-xs font-medium text-gray-700">Category</label>
        <select phx-change="filter-by-category" class="text-xs w-full">
          <option value="">All Categories</option>
          <%= for category <- @available_categories do %>
            <option value={category} selected={@filter_state.category == category}>
              <%= String.capitalize(category) %>
            </option>
          <% end %>
        </select>
      </div>
      """)

      # Should render category filter with options
      assert html =~ ~s(phx-change="filter-by-category")
      assert html =~ ~s(option value="security" selected)
      assert html =~ "Implementation"
      assert html =~ "Security"
      assert html =~ "Admin"
      assert html =~ "All Categories"
    end

    test "renders priority filter dropdown" do
      filter_state = %{priority: "high"}
      available_priorities = ["high", "medium", "low"]

      assigns = %{filter_state: filter_state, available_priorities: available_priorities}

      html = rendered_to_string(~H"""
      <div class="filter-section">
        <label class="text-xs font-medium text-gray-700">Priority</label>
        <select phx-change="filter-by-priority" class="text-xs w-full">
          <option value="">All Priorities</option>
          <%= for priority <- @available_priorities do %>
            <option value={priority} selected={@filter_state.priority == priority}>
              <%= String.capitalize(priority) %>
            </option>
          <% end %>
        </select>
      </div>
      """)

      # Should render priority filter with selection
      assert html =~ ~s(phx-change="filter-by-priority")
      assert html =~ ~s(option value="high" selected)
      assert html =~ "High"
      assert html =~ "Medium"
      assert html =~ "Low"
    end

    test "renders author filter dropdown" do
      filter_state = %{author: "Claude"}
      available_authors = ["Claude", "User", "System"]

      assigns = %{filter_state: filter_state, available_authors: available_authors}

      html = rendered_to_string(~H"""
      <div class="filter-section">
        <label class="text-xs font-medium text-gray-700">Author</label>
        <select phx-change="filter-by-author" class="text-xs w-full">
          <option value="">All Authors</option>
          <%= for author <- @available_authors do %>
            <option value={author} selected={@filter_state.author == author}>
              <%= author %>
            </option>
          <% end %>
        </select>
      </div>
      """)

      # Should render author filter
      assert html =~ ~s(phx-change="filter-by-author")
      assert html =~ ~s(option value="Claude" selected)
      assert html =~ "All Authors"
    end

    test "renders tag-based multi-select filtering" do
      filter_state = %{tags: ["phase-1", "security"]}
      available_tags = ["phase-1", "ash", "security", "admin", "testing", "implementation"]

      assigns = %{filter_state: filter_state, available_tags: available_tags}

      html = rendered_to_string(~H"""
      <div class="filter-section">
        <label class="text-xs font-medium text-gray-700">Tags</label>
        <div class="tag-filter-container">
          <%= for tag <- @available_tags do %>
            <label class="inline-flex items-center mr-2 mb-1">
              <input 
                type="checkbox" 
                phx-click="toggle-tag-filter" 
                phx-value-tag={tag}
                checked={tag in @filter_state.tags}
                class="text-xs mr-1"
              />
              <span class="text-xs"><%= tag %></span>
            </label>
          <% end %>
        </div>
      </div>
      """)

      # Should render tag checkboxes
      assert html =~ ~s(phx-click="toggle-tag-filter")
      assert html =~ ~s(phx-value-tag="phase-1")
      assert html =~ ~s(checked)
      assert html =~ "phase-1"
      assert html =~ "security"
      assert html =~ "ash"
    end

    test "renders reset filters button" do
      filter_state = %{status: "live", category: "security"}

      assigns = %{filter_state: filter_state}

      html = rendered_to_string(~H"""
      <div class="filter-actions mt-3">
        <button 
          phx-click="reset-filters" 
          class="text-xs px-2 py-1 bg-gray-200 text-gray-700 rounded hover:bg-gray-300"
          disabled={@filter_state.status == "" and @filter_state.category == "" and @filter_state.priority == "" and @filter_state.author == "" and @filter_state.tags == []}
        >
          Reset Filters
        </button>
        <span class="text-xs text-gray-500 ml-2">
          <%= if @filter_state.status != "" or @filter_state.category != "" do %>
            Filters active
          <% else %>
            No filters
          <% end %>
        </span>
      </div>
      """)

      # Should render reset button and status
      assert html =~ ~s(phx-click="reset-filters")
      assert html =~ "Reset Filters"
      assert html =~ "Filters active"
    end

    test "filters navigation items by status" do
      # Mock navigation items with different statuses
      nav_items = [
        %{title: "Live Doc", path: "/live", metadata: %{"status" => "live"}},
        %{title: "Archived Doc", path: "/archived", metadata: %{"status" => "archived"}},
        %{title: "No Status Doc", path: "/none", metadata: %{}}
      ]

      filter_state = %{status: "live"}
      
      # Test filtering logic (this would be in the component)
      filtered_items = Enum.filter(nav_items, fn item ->
        case filter_state.status do
          "" -> true
          status -> Map.get(item.metadata, "status") == status
        end
      end)

      # Should only include live documents
      assert length(filtered_items) == 1
      assert List.first(filtered_items).title == "Live Doc"
    end

    test "filters navigation items by category" do
      nav_items = [
        %{title: "Security Doc", path: "/security", metadata: %{"category" => "security"}},
        %{title: "Admin Doc", path: "/admin", metadata: %{"category" => "admin"}},
        %{title: "Implementation Doc", path: "/impl", metadata: %{"category" => "implementation"}}
      ]

      filter_state = %{category: "security"}
      
      filtered_items = Enum.filter(nav_items, fn item ->
        case filter_state.category do
          "" -> true
          category -> Map.get(item.metadata, "category") == category
        end
      end)

      # Should only include security documents
      assert length(filtered_items) == 1
      assert List.first(filtered_items).title == "Security Doc"
    end

    test "filters navigation items by priority" do
      nav_items = [
        %{title: "High Priority", path: "/high", metadata: %{"priority" => "high"}},
        %{title: "Medium Priority", path: "/med", metadata: %{"priority" => "medium"}},
        %{title: "Low Priority", path: "/low", metadata: %{"priority" => "low"}}
      ]

      filter_state = %{priority: "high"}
      
      filtered_items = Enum.filter(nav_items, fn item ->
        case filter_state.priority do
          "" -> true
          priority -> Map.get(item.metadata, "priority") == priority
        end
      end)

      # Should only include high priority documents
      assert length(filtered_items) == 1
      assert List.first(filtered_items).title == "High Priority"
    end

    test "filters navigation items by tags" do
      nav_items = [
        %{title: "Phase 1 Doc", path: "/p1", metadata: %{"tags" => ["phase-1", "implementation"]}},
        %{title: "Security Doc", path: "/sec", metadata: %{"tags" => ["security", "admin"]}},
        %{title: "Mixed Doc", path: "/mix", metadata: %{"tags" => ["phase-1", "security"]}}
      ]

      filter_state = %{tags: ["phase-1"]}
      
      filtered_items = Enum.filter(nav_items, fn item ->
        case filter_state.tags do
          [] -> true
          filter_tags ->
            item_tags = Map.get(item.metadata, "tags", [])
            Enum.any?(filter_tags, fn tag -> tag in item_tags end)
        end
      end)

      # Should include documents with phase-1 tag
      assert length(filtered_items) == 2
      titles = Enum.map(filtered_items, & &1.title)
      assert "Phase 1 Doc" in titles
      assert "Mixed Doc" in titles
    end

    test "applies multiple filters simultaneously" do
      nav_items = [
        %{title: "Live Security High", path: "/lsh", metadata: %{"status" => "live", "category" => "security", "priority" => "high"}},
        %{title: "Live Security Low", path: "/lsl", metadata: %{"status" => "live", "category" => "security", "priority" => "low"}},
        %{title: "Archived Security High", path: "/ash", metadata: %{"status" => "archived", "category" => "security", "priority" => "high"}},
        %{title: "Live Admin High", path: "/lah", metadata: %{"status" => "live", "category" => "admin", "priority" => "high"}}
      ]

      filter_state = %{status: "live", category: "security", priority: "high"}
      
      filtered_items = Enum.filter(nav_items, fn item ->
        status_match = case filter_state.status do
          "" -> true
          status -> Map.get(item.metadata, "status") == status
        end
        
        category_match = case filter_state.category do
          "" -> true
          category -> Map.get(item.metadata, "category") == category
        end
        
        priority_match = case filter_state.priority do
          "" -> true
          priority -> Map.get(item.metadata, "priority") == priority
        end

        status_match && category_match && priority_match
      end)

      # Should only include items matching all filters
      assert length(filtered_items) == 1
      assert List.first(filtered_items).title == "Live Security High"
    end
  end

  describe "navigation sorting system" do
    test "renders sort controls with dropdown and toggle" do
      sort_state = %{sort_by: "priority", sort_order: :asc}

      assigns = %{
        sort_state: sort_state,
        available_sort_options: [
          %{value: "priority", label: "Priority"},
          %{value: "title", label: "Title"},
          %{value: "last_modified", label: "Date Modified"},
          %{value: "category", label: "Category"}
        ]
      }

      html = rendered_to_string(~H"""
      <div class="nav-sort mb-2">
        <label class="text-xs font-medium text-gray-700">Sort by</label>
        <div class="flex items-center space-x-2">
          <select phx-change="change-sort" class="text-xs flex-1">
            <%= for option <- @available_sort_options do %>
              <option value={option.value} selected={@sort_state.sort_by == option.value}>
                <%= option.label %>
              </option>
            <% end %>
          </select>
          <button 
            phx-click="toggle-sort-order" 
            class="text-xs px-2 py-1 border rounded"
            title={if @sort_state.sort_order == :asc, do: "Sort descending", else: "Sort ascending"}
          >
            <%= if @sort_state.sort_order == :asc, do: "↑", else: "↓" %>
          </button>
        </div>
      </div>
      """)

      # Should render sort dropdown and toggle button
      assert html =~ ~s(phx-change="change-sort")
      assert html =~ ~s(phx-click="toggle-sort-order")
      assert html =~ ~s(option value="priority" selected)
      assert html =~ "Priority"
      assert html =~ "Title"
      assert html =~ "Date Modified"
      assert html =~ "↑"
    end

    test "sorts navigation items by priority" do
      nav_items = [
        %{title: "Medium Doc", metadata: %{"priority" => "medium"}},
        %{title: "High Doc", metadata: %{"priority" => "high"}},
        %{title: "Low Doc", metadata: %{"priority" => "low"}},
        %{title: "No Priority", metadata: %{}}
      ]

      # Test ascending priority sort (high -> medium -> low)
      sorted_items = SertantaiDocs.MarkdownProcessor.sort_by_priority(nav_items, :asc)

      titles = Enum.map(sorted_items, & &1.title)
      assert titles == ["High Doc", "Medium Doc", "Low Doc", "No Priority"]
    end

    test "sorts navigation items by title alphabetically" do
      nav_items = [
        %{title: "Zebra Doc", metadata: %{}},
        %{title: "Alpha Doc", metadata: %{}},
        %{title: "Beta Doc", metadata: %{}}
      ]

      sorted_asc = SertantaiDocs.MarkdownProcessor.sort_by_title(nav_items, :asc)
      sorted_desc = SertantaiDocs.MarkdownProcessor.sort_by_title(nav_items, :desc)

      asc_titles = Enum.map(sorted_asc, & &1.title)
      desc_titles = Enum.map(sorted_desc, & &1.title)

      assert asc_titles == ["Alpha Doc", "Beta Doc", "Zebra Doc"]
      assert desc_titles == ["Zebra Doc", "Beta Doc", "Alpha Doc"]
    end

    test "sorts navigation items by last_modified date" do
      nav_items = [
        %{title: "Old Doc", metadata: %{"last_modified" => "2024-01-01"}},
        %{title: "New Doc", metadata: %{"last_modified" => "2024-12-31"}},
        %{title: "Middle Doc", metadata: %{"last_modified" => "2024-06-15"}},
        %{title: "No Date", metadata: %{}}
      ]

      sorted_items = SertantaiDocs.MarkdownProcessor.sort_by_date(nav_items, :desc)

      titles = Enum.map(sorted_items, & &1.title)
      assert titles == ["New Doc", "Middle Doc", "Old Doc", "No Date"]
    end

    test "sorts navigation items by category" do
      nav_items = [
        %{title: "Security Doc", metadata: %{"category" => "security"}},
        %{title: "Admin Doc", metadata: %{"category" => "admin"}},
        %{title: "Implementation Doc", metadata: %{"category" => "implementation"}},
        %{title: "Analysis Doc", metadata: %{"category" => "analysis"}}
      ]

      sorted_items = SertantaiDocs.MarkdownProcessor.sort_by_category(nav_items, :asc)

      titles = Enum.map(sorted_items, & &1.title)
      assert titles == ["Admin Doc", "Analysis Doc", "Implementation Doc", "Security Doc"]
    end

    test "maintains sort stability for equal values" do
      nav_items = [
        %{title: "First High", metadata: %{"priority" => "high"}},
        %{title: "Second High", metadata: %{"priority" => "high"}},
        %{title: "Third High", metadata: %{"priority" => "high"}}
      ]

      # When priorities are equal, should maintain original order (stable sort)
      sorted_items = SertantaiDocs.MarkdownProcessor.sort_by_priority(nav_items, :asc)

      titles = Enum.map(sorted_items, & &1.title)
      assert titles == ["First High", "Second High", "Third High"]
    end

    test "combines sorting with filtering" do
      nav_items = [
        %{title: "High Security A", metadata: %{"priority" => "high", "category" => "security"}},
        %{title: "Medium Security B", metadata: %{"priority" => "medium", "category" => "security"}},
        %{title: "High Admin C", metadata: %{"priority" => "high", "category" => "admin"}},
        %{title: "Low Security D", metadata: %{"priority" => "low", "category" => "security"}}
      ]

      # Filter by security, then sort by priority
      filtered_items = SertantaiDocs.MarkdownProcessor.filter_by_category(nav_items, "security")
      sorted_filtered = SertantaiDocs.MarkdownProcessor.sort_by_priority(filtered_items, :asc)

      titles = Enum.map(sorted_filtered, & &1.title)
      assert titles == ["High Security A", "Medium Security B", "Low Security D"]
    end
  end

  describe "nav_sidebar integration with filtering/sorting UI" do
    test "renders filter controls within nav_sidebar component" do
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
        items: navigation_items,
        current_path: "/test",
        filter_state: filter_state,
        available_categories: ["security", "admin"],
        available_priorities: ["high", "medium", "low"],
        available_authors: ["Claude", "User"],
        available_tags: ["phase-1", "ash"]
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@items} 
        current_path={@current_path}
        filter_state={@filter_state}
        available_categories={@available_categories}
        available_priorities={@available_priorities}
        available_authors={@available_authors}
        available_tags={@available_tags}
      />
      """)

      # Should render filter controls at the top of sidebar
      assert html =~ ~s(class="nav-filters)
      assert html =~ ~s(phx-change="filter-by-status")
      assert html =~ ~s(phx-change="filter-by-category")
      assert html =~ ~s(phx-change="filter-by-priority")
      assert html =~ ~s(phx-change="filter-by-author")
      assert html =~ ~s(phx-click="toggle-tag-filter")
      assert html =~ ~s(phx-click="reset-filters")
    end

    test "renders sort controls within nav_sidebar component" do
      navigation_items = [
        %{title: "Test Item", path: "/test", type: :page}
      ]

      sort_state = %{sort_by: "priority", sort_order: "asc"}

      assigns = %{
        items: navigation_items,
        current_path: "/test",
        sort_state: sort_state,
        available_sort_options: [
          %{value: "priority", label: "Priority"},
          %{value: "title", label: "Title"},
          %{value: "last_modified", label: "Date Modified"},
          %{value: "category", label: "Category"}
        ]
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@items} 
        current_path={@current_path}
        sort_state={@sort_state}
        available_sort_options={@available_sort_options}
      />
      """)

      # Should render sort controls in sidebar
      assert html =~ ~s(class="nav-sort)
      assert html =~ ~s(phx-change="change-sort")
      assert html =~ ~s(phx-click="toggle-sort-order")
      assert html =~ "Sort"
      assert html =~ "Priority"
      # Check for Heroicon arrow instead of Unicode character
      assert html =~ "hero-bars-arrow-up"
    end

    test "nav_sidebar component structure and content" do
      navigation_items = [
        %{title: "Test Item", path: "/test", type: :page}
      ]

      filter_state = %{
        status: "",
        category: "",
        priority: "",
        author: "",
        tags: []
      }

      sort_state = %{sort_by: "priority", sort_order: "asc"}
      
      available_sort_options = [
        %{value: "priority", label: "Priority"},
        %{value: "title", label: "Title"}
      ]

      assigns = %{
        items: navigation_items,
        current_path: "/test",
        filter_state: filter_state,
        sort_state: sort_state,
        available_sort_options: available_sort_options
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@items} 
        current_path={@current_path}
        filter_state={@filter_state}
        sort_state={@sort_state}
        available_sort_options={@available_sort_options}
      />
      """)

      # Should render filtering and sorting controls within sidebar
      assert html =~ ~s(class="nav-filters)
      assert html =~ ~s(class="nav-sort)
      assert html =~ "Test Item"
      assert html =~ "1 items"
    end

    test "nav_sidebar applies filtering to displayed navigation items" do
      navigation_items = [
        %{title: "Live Security Doc", path: "/live-sec", type: :page, metadata: %{"status" => "live", "category" => "security"}},
        %{title: "Archived Admin Doc", path: "/arch-admin", type: :page, metadata: %{"status" => "archived", "category" => "admin"}},
        %{title: "Live Admin Doc", path: "/live-admin", type: :page, metadata: %{"status" => "live", "category" => "admin"}}
      ]

      # Filter to show only live documents
      filter_state = %{
        status: "live",
        category: "",
        priority: "",
        author: "",
        tags: []
      }

      assigns = %{
        items: navigation_items,
        current_path: "/test",
        filter_state: filter_state
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@items} 
        current_path={@current_path}
        filter_state={@filter_state}
      />
      """)

      # Should only show live documents
      assert html =~ "Live Security Doc"
      assert html =~ "Live Admin Doc"
      refute html =~ "Archived Admin Doc"
    end

    test "nav_sidebar applies sorting to displayed navigation items" do
      navigation_items = [
        %{title: "Zebra Doc", path: "/zebra", type: :page, metadata: %{"priority" => "low"}},
        %{title: "Alpha Doc", path: "/alpha", type: :page, metadata: %{"priority" => "high"}},
        %{title: "Beta Doc", path: "/beta", type: :page, metadata: %{"priority" => "medium"}}
      ]

      # Sort by priority ascending (high -> medium -> low)
      sort_state = %{sort_by: "priority", sort_order: "asc"}

      assigns = %{
        items: navigation_items,
        current_path: "/test",
        sort_state: sort_state
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@items} 
        current_path={@current_path}
        sort_state={@sort_state}
      />
      """)

      # Should render items in priority order: Alpha (high), Beta (medium), Zebra (low)
      alpha_pos = :binary.match(html, "Alpha Doc") |> elem(0)
      beta_pos = :binary.match(html, "Beta Doc") |> elem(0)
      zebra_pos = :binary.match(html, "Zebra Doc") |> elem(0)

      assert alpha_pos < beta_pos
      assert beta_pos < zebra_pos
    end

    test "nav_sidebar combines filtering and sorting" do
      navigation_items = [
        %{title: "High Security A", path: "/hsa", type: :page, metadata: %{"priority" => "high", "category" => "security"}},
        %{title: "Low Security B", path: "/lsb", type: :page, metadata: %{"priority" => "low", "category" => "security"}},
        %{title: "High Admin C", path: "/hac", type: :page, metadata: %{"priority" => "high", "category" => "admin"}},
        %{title: "Medium Security D", path: "/msd", type: :page, metadata: %{"priority" => "medium", "category" => "security"}}
      ]

      # Filter by security category, sort by priority ascending
      filter_state = %{
        status: "",
        category: "security",
        priority: "",
        author: "",
        tags: []
      }

      sort_state = %{sort_by: "priority", sort_order: "asc"}

      assigns = %{
        items: navigation_items,
        current_path: "/test",
        filter_state: filter_state,
        sort_state: sort_state
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@items} 
        current_path={@current_path}
        filter_state={@filter_state}
        sort_state={@sort_state}
      />
      """)

      # Should show only security docs in priority order
      assert html =~ "High Security A"
      assert html =~ "Medium Security D" 
      assert html =~ "Low Security B"
      refute html =~ "High Admin C"

      # Should be in correct priority order
      high_pos = :binary.match(html, "High Security A") |> elem(0)
      medium_pos = :binary.match(html, "Medium Security D") |> elem(0)
      low_pos = :binary.match(html, "Low Security B") |> elem(0)

      assert high_pos < medium_pos
      assert medium_pos < low_pos
    end

    test "nav_sidebar shows filtered item count and active filter indicators" do
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
        items: navigation_items,
        current_path: "/test",
        filter_state: filter_state
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@items} 
        current_path={@current_path}
        filter_state={@filter_state}
      />
      """)

      # Should show filter count and active indicators
      assert html =~ "Showing 2 of 3 items"
      assert html =~ "Filters active"
      # The filter indicator is shown as "Filters active" text, not a specific CSS class
    end

    test "nav_sidebar handles empty filtered results gracefully" do
      navigation_items = [
        %{title: "Admin Doc", path: "/admin", type: :page, metadata: %{"category" => "admin"}}
      ]

      # Filter by category that doesn't exist
      filter_state = %{
        status: "",
        category: "security",
        priority: "",
        author: "",
        tags: []
      }

      assigns = %{
        items: navigation_items,
        current_path: "/test",
        filter_state: filter_state
      }

      html = rendered_to_string(~H"""
      <.nav_sidebar 
        items={@items} 
        current_path={@current_path}
        filter_state={@filter_state}
      />
      """)

      # Should show no results message
      assert html =~ "No items match the current filters"
      assert html =~ "Try adjusting your filter criteria"
      refute html =~ "Admin Doc"
    end
  end
end