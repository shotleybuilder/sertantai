defmodule SertantaiDocs.Navigation.GroupedNavigationStructureTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.MarkdownProcessor

  @moduledoc """
  TDD tests for the complete grouped navigation structure output.
  
  Tests the final navigation structure that will be consumed by the UI:
  - Proper nesting and hierarchy (categories > groups > sub-groups > pages)
  - Collapsible group states and metadata
  - Navigation data format and consistency
  - Integration between all grouping components
  - Performance and usability considerations
  """

  describe "generate_grouped_navigation/0" do
    test "generates complete navigation with build category grouped" do
      {:ok, navigation} = MarkdownProcessor.generate_navigation()
      
      # Should contain standard categories
      category_titles = Enum.map(navigation, fn item ->
        Map.get(item, :title) || Map.get(item, "title")
      end)
      
      expected_categories = ["Build Documentation", "Developer Documentation", "User Guide"]
      
      for expected <- expected_categories do
        assert expected in category_titles, 
               "Navigation should include '#{expected}' category"
      end
    end

    test "build category has grouped structure while others remain flat" do
      {:ok, navigation} = MarkdownProcessor.generate_navigation()
      
      build_section = Enum.find(navigation, fn item ->
        title = Map.get(item, :title) || Map.get(item, "title")
        title == "Build Documentation"
      end)
      
      dev_section = Enum.find(navigation, fn item ->
        title = Map.get(item, :title) || Map.get(item, "title")
        String.contains?(title || "", "Developer")
      end)
      
      if build_section do
        build_children = Map.get(build_section, :children) || []
        
        # Build section should have group-type children
        group_children = Enum.filter(build_children, fn child ->
          Map.get(child, :type) == :group
        end)
        
        assert length(group_children) > 0, 
               "Build section should have grouped children"
        
        # Verify group structure
        for group <- group_children do
          assert Map.has_key?(group, :group) # group identifier
          assert Map.get(group, :collapsible) == true
          assert Map.get(group, :type) == :group
          assert is_list(Map.get(group, :children))
        end
      end
      
      if dev_section do
        dev_children = Map.get(dev_section, :children) || []
        
        # Dev section should NOT have group-type children (flat structure)
        group_children = Enum.filter(dev_children, fn child ->
          Map.get(child, :type) == :group
        end)
        
        assert length(group_children) == 0,
               "Dev section should maintain flat structure"
      end
    end
  end

  describe "navigation_data_structure/1" do
    test "produces consistent navigation data structure" do
      mock_grouped_data = %{
        "done" => [
          {"done_phase1.md", %{"title" => "Phase 1", "sub_group" => "phases"}},
          {"done_admin.md", %{"title" => "Admin Plan"}} # no sub_group
        ],
        "strategy" => [
          {"strategy_security.md", %{"title" => "Security Audit"}}
        ]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(mock_grouped_data)
      
      # Top level structure validation
      assert is_list(nav_structure)
      assert length(nav_structure) == 2 # done and strategy groups
      
      for group <- nav_structure do
        # Required group fields
        assert Map.has_key?(group, :title)
        assert Map.has_key?(group, :group)
        assert Map.has_key?(group, :type)
        assert Map.has_key?(group, :collapsible)
        assert Map.has_key?(group, :children)
        
        # Type validation
        assert is_binary(group.title)
        assert is_binary(group.group)
        assert group.type == :group
        assert group.collapsible == true
        assert is_list(group.children)
        
        # Children validation
        for child <- group.children do
          assert Map.has_key?(child, :title)
          assert Map.has_key?(child, :type)
          assert child.type in [:page, :sub_group]
          
          if child.type == :sub_group do
            assert Map.has_key?(child, :collapsible)
            assert Map.has_key?(child, :children)
            assert child.collapsible == true
            assert is_list(child.children)
            
            # Sub-group children should be pages
            for subchild <- child.children do
              assert subchild.type == :page
              assert Map.has_key?(subchild, :path)
              assert String.starts_with?(subchild.path, "/build/")
            end
          end
          
          if child.type == :page do
            assert Map.has_key?(child, :path)
            assert String.starts_with?(child.path, "/build/")
          end
        end
      end
    end

    test "includes group metadata for UI customization" do
      mock_data = %{
        "done" => [{"done_test.md", %{"title" => "Test"}}],
        "todo" => [{"todo_test.md", %{"title" => "Test"}}]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(mock_data)
      
      done_group = Enum.find(nav_structure, & &1.group == "done")
      todo_group = Enum.find(nav_structure, & &1.group == "todo")
      
      # Should have appropriate UI metadata
      assert done_group.title == "Done"
      assert done_group.group == "done"
      
      assert todo_group.title == "Todo"  
      assert todo_group.group == "todo"
      
      # Could include additional UI hints
      expected_ui_metadata = [:icon, :default_expanded, :description]
      for group <- [done_group, todo_group] do
        # These fields might be added for UI customization
        for field <- expected_ui_metadata do
          # Not required but could be present
          if Map.has_key?(group, field) do
            assert not is_nil(Map.get(group, field))
          end
        end
      end
    end

    test "handles empty groups gracefully" do
      empty_data = %{}
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(empty_data)
      
      assert nav_structure == []
    end

    test "preserves file ordering within groups and sub-groups" do
      ordered_data = %{
        "done" => [
          {"done_phase1.md", %{"title" => "A First", "priority" => "high", "sub_group" => "phases"}},
          {"done_phase3.md", %{"title" => "C Third", "priority" => "low", "sub_group" => "phases"}},
          {"done_phase2.md", %{"title" => "B Second", "priority" => "medium", "sub_group" => "phases"}}
        ]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(ordered_data)
      done_group = List.first(nav_structure)
      phases_subgroup = List.first(done_group.children)
      
      # Should be ordered by priority (high, medium, low), then alphabetically
      titles = Enum.map(phases_subgroup.children, & &1.title)
      assert titles == ["A First", "B Second", "C Third"]
    end
  end

  describe "collapsible_state_management/1" do
    test "sets appropriate default expansion states" do
      mock_data = %{
        "done" => [{"done_test.md", %{"title" => "Test"}}],
        "strategy" => [{"strategy_test.md", %{"title" => "Test"}}], 
        "todo" => [{"todo_test.md", %{"title" => "Test"}}]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(mock_data)
      
      done_group = Enum.find(nav_structure, & &1.group == "done")
      strategy_group = Enum.find(nav_structure, & &1.group == "strategy")
      todo_group = Enum.find(nav_structure, & &1.group == "todo")
      
      # Done and strategy should default to collapsed
      assert done_group.default_expanded == false
      assert strategy_group.default_expanded == false
      
      # Todo should default to expanded (active work)
      assert todo_group.default_expanded == true
    end

    test "includes collapsible state in sub-groups" do
      mock_data = %{
        "done" => [
          {"done_phase1.md", %{"title" => "Phase 1", "sub_group" => "phases"}},
          {"done_admin1.md", %{"title" => "Admin 1", "sub_group" => "admin"}}
        ]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(mock_data)
      done_group = List.first(nav_structure)
      
      # All sub-groups should be collapsible
      for child <- done_group.children do
        if child.type == :sub_group do
          assert child.collapsible == true
          assert Map.has_key?(child, :default_expanded)
        end
      end
    end

    test "provides state persistence keys for UI" do
      mock_data = %{
        "done" => [{"done_test.md", %{"title" => "Test"}}]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(mock_data)
      done_group = List.first(nav_structure)
      
      # Should provide unique keys for state persistence
      assert Map.has_key?(done_group, :state_key)
      assert done_group.state_key == "build_group_done"
    end
  end

  describe "icon_and_styling_metadata/1" do
    test "assigns appropriate icons to groups" do
      mock_data = %{
        "done" => [{"done_test.md", %{"title" => "Test"}}],
        "strategy" => [{"strategy_test.md", %{"title" => "Test"}}],
        "todo" => [{"todo_test.md", %{"title" => "Test"}}]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(mock_data)
      
      done_group = Enum.find(nav_structure, & &1.group == "done")
      strategy_group = Enum.find(nav_structure, & &1.group == "strategy")
      todo_group = Enum.find(nav_structure, & &1.group == "todo")
      
      # Should have appropriate icons
      assert done_group.icon == "hero-check-circle"
      assert done_group.icon_color == "text-green-600"
      
      assert strategy_group.icon == "hero-document-magnifying-glass" 
      assert strategy_group.icon_color == "text-blue-600"
      
      assert todo_group.icon == "hero-clipboard-document-list"
      assert todo_group.icon_color == "text-orange-600"
    end

    test "provides CSS classes for styling" do
      mock_data = %{
        "done" => [{"done_test.md", %{"title" => "Test"}}]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(mock_data)
      done_group = List.first(nav_structure)
      
      # Should include styling classes
      assert Map.has_key?(done_group, :css_class)
      assert done_group.css_class == "nav-group nav-group-done"
      
      # Header styling
      assert Map.has_key?(done_group, :header_class) 
      assert done_group.header_class == "nav-group-header nav-group-header-done"
    end

    test "handles custom group types with fallback styling" do
      custom_data = %{
        "meeting" => [{"meeting_test.md", %{"title" => "Test"}}],
        "research" => [{"research_test.md", %{"title" => "Test"}}]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(custom_data)
      
      for group <- nav_structure do
        # Custom groups should get default styling
        assert Map.has_key?(group, :icon)
        assert Map.has_key?(group, :icon_color)
        assert group.icon == "hero-document" # default icon
        assert group.icon_color == "text-gray-600" # default color
      end
    end
  end

  describe "navigation_performance_and_caching/1" do
    test "caches generated navigation structure" do
      # First generation
      start_time = System.monotonic_time()
      {:ok, nav1} = MarkdownProcessor.generate_navigation()
      first_duration = System.monotonic_time() - start_time
      
      # Second generation (should be cached)
      start_time = System.monotonic_time()
      {:ok, nav2} = MarkdownProcessor.generate_navigation()
      second_duration = System.monotonic_time() - start_time
      
      # Results should be identical
      assert nav1 == nav2
      
      # Second call should be faster (cached)
      assert second_duration < first_duration / 2
    end

    test "handles large navigation structures efficiently" do
      # Mock large dataset
      large_mock_data = for i <- 1..100 do
        group = Enum.random(["done", "strategy", "todo"])
        sub_group = Enum.random(["phases", "admin", "security", "docs"])
        
        {"#{group}_file_#{i}.md", %{
          "title" => "File #{i}",
          "sub_group" => sub_group,
          "priority" => Enum.random(["high", "medium", "low"])
        }}
      end
      
      grouped_data = MarkdownProcessor.group_files_by_metadata(large_mock_data, "build")
      
      # Should handle large structures efficiently
      start_time = System.monotonic_time()
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(grouped_data)
      end_time = System.monotonic_time()
      
      processing_time = System.convert_time_unit(end_time - start_time, :native, :millisecond)
      
      # Should complete quickly
      assert processing_time < 50 # 50ms threshold
      
      # Structure should be complete
      total_items = Enum.reduce(nav_structure, 0, fn group, acc ->
        acc + count_all_nav_items(group)
      end)
      
      assert total_items == 100 # All files accounted for
    end

    test "optimizes navigation structure for frontend consumption" do
      mock_data = %{
        "done" => [
          {"done_phase1.md", %{
            "title" => "Phase 1",
            "sub_group" => "phases",
            "author" => "Claude",
            "tags" => ["phase-1", "implementation"],
            "last_modified" => "2025-01-21"
          }}
        ]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(mock_data)
      done_group = List.first(nav_structure)
      phases_subgroup = List.first(done_group.children)
      phase1_page = List.first(phases_subgroup.children)
      
      # Navigation should include essential data for frontend
      assert Map.has_key?(phase1_page, :title)
      assert Map.has_key?(phase1_page, :path) 
      assert Map.has_key?(phase1_page, :type)
      
      # Metadata should be available but not necessarily at top level
      # (to keep navigation structure lean)
      metadata = Map.get(phase1_page, :metadata, %{})
      
      if not Enum.empty?(metadata) do
        # If metadata is included, should have key fields for tooltips/search
        expected_fields = ["author", "tags", "last_modified"]
        for field <- expected_fields do
          if Map.has_key?(metadata, field) do
            assert not is_nil(metadata[field])
          end
        end
      end
    end
  end

  describe "accessibility_and_ui_integration/1" do
    test "provides ARIA labels and accessibility metadata" do
      mock_data = %{
        "done" => [{"done_test.md", %{"title" => "Test Document"}}]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(mock_data)
      done_group = List.first(nav_structure)
      
      # Should include accessibility metadata
      assert Map.has_key?(done_group, :aria_label)
      assert done_group.aria_label == "Done group, collapsible section with 1 item"
      
      assert Map.has_key?(done_group, :aria_expanded)
      assert done_group.aria_expanded == false # default collapsed
      
      # Should include item count for screen readers
      assert Map.has_key?(done_group, :item_count)
      assert done_group.item_count == 1
    end

    test "provides keyboard navigation support metadata" do
      mock_data = %{
        "done" => [
          {"done_phase1.md", %{"title" => "Phase 1", "sub_group" => "phases"}},
          {"done_admin.md", %{"title" => "Admin"}}
        ]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(mock_data)
      done_group = List.first(nav_structure)
      
      # Should include keyboard navigation hints
      assert Map.has_key?(done_group, :keyboard_shortcuts)
      shortcuts = done_group.keyboard_shortcuts
      
      assert Map.has_key?(shortcuts, :toggle) # key to toggle expansion
      assert Map.has_key?(shortcuts, :focus_first) # key to focus first child
      assert Map.has_key?(shortcuts, :focus_parent) # key to focus parent
    end

    test "supports responsive design metadata" do
      mock_data = %{
        "done" => [{"done_test.md", %{"title" => "Test"}}]
      }
      
      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(mock_data)
      done_group = List.first(nav_structure)
      
      # Should include responsive behavior hints
      assert Map.has_key?(done_group, :mobile_behavior)
      mobile_config = done_group.mobile_behavior
      
      assert Map.has_key?(mobile_config, :collapse_on_mobile)
      assert Map.has_key?(mobile_config, :show_item_count)
      assert mobile_config.collapse_on_mobile == true
    end
  end

  # Helper function for counting navigation items
  defp count_all_nav_items(nav_item) do
    base_count = 1
    
    children_count = case Map.get(nav_item, :children) do
      nil -> 0
      [] -> 0
      children when is_list(children) ->
        Enum.reduce(children, 0, fn child, acc ->
          acc + count_all_nav_items(child)
        end)
    end
    
    base_count + children_count
  end
end