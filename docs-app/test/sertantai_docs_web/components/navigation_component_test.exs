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
        Map.get(item, :title) == "Build Documentation"
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
end