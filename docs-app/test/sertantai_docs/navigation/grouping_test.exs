defmodule SertantaiDocs.Navigation.GroupingTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.MarkdownProcessor

  @moduledoc """
  TDD tests for the hybrid YAML frontmatter + fallback grouping system.
  
  Based on todo_documentation_grouping_system_plan.md implementation requirements.
  Tests cover:
  - YAML frontmatter-based grouping
  - Filename prefix fallback logic  
  - Dynamic group creation
  - Sub-group functionality
  - Comprehensive metadata extraction
  """

  describe "infer_group_from_filename/1" do
    test "extracts group from filename prefix before first underscore" do
      assert MarkdownProcessor.infer_group_from_filename("done_phase_1_summary.md") == "done"
      assert MarkdownProcessor.infer_group_from_filename("strategy_security_audit.md") == "strategy"
      assert MarkdownProcessor.infer_group_from_filename("todo_grouping_plan.md") == "todo"
      assert MarkdownProcessor.infer_group_from_filename("hello_jason.md") == "hello"
      assert MarkdownProcessor.infer_group_from_filename("meeting_notes_2025.md") == "meeting"
    end

    test "handles files without underscore prefix" do
      assert MarkdownProcessor.infer_group_from_filename("index.md") == "other"
      assert MarkdownProcessor.infer_group_from_filename("readme.md") == "other"
      assert MarkdownProcessor.infer_group_from_filename("single-word.md") == "other"
    end

    test "handles edge cases" do
      assert MarkdownProcessor.infer_group_from_filename("_leading_underscore.md") == "other"
      assert MarkdownProcessor.infer_group_from_filename("trailing_underscore_.md") == "trailing"
      assert MarkdownProcessor.infer_group_from_filename("multiple_under_scores_here.md") == "multiple"
    end
  end

  describe "determine_group/1" do
    test "uses YAML frontmatter group when present" do
      file_metadata = {"test_file.md", %{"group" => "custom"}}
      assert MarkdownProcessor.determine_group(file_metadata) == "custom"

      file_metadata = {"done_something.md", %{"group" => "archive"}}
      assert MarkdownProcessor.determine_group(file_metadata) == "archive"
    end

    test "falls back to filename inference when no YAML group" do
      file_metadata = {"done_phase_1.md", %{}}
      assert MarkdownProcessor.determine_group(file_metadata) == "done"

      file_metadata = {"strategy_analysis.md", %{"title" => "Analysis"}}
      assert MarkdownProcessor.determine_group(file_metadata) == "strategy"
    end

    test "falls back to filename when YAML group is invalid" do
      file_metadata = {"todo_plan.md", %{"group" => nil}}
      assert MarkdownProcessor.determine_group(file_metadata) == "todo"

      file_metadata = {"hello_world.md", %{"group" => 123}}
      assert MarkdownProcessor.determine_group(file_metadata) == "hello"
    end

    test "returns other for files without prefix and no YAML group" do
      file_metadata = {"standalone.md", %{}}
      assert MarkdownProcessor.determine_group(file_metadata) == "other"
    end
  end

  describe "group_files_by_metadata/2" do
    test "groups build category files by metadata and filename fallback" do
      files = [
        {"done_phase1.md", %{"title" => "Phase 1", "group" => "done"}},
        {"done_phase8.md", %{"title" => "Phase 8"}}, # fallback to filename
        {"strategy_security.md", %{"title" => "Security", "group" => "strategy"}},
        {"todo_grouping.md", %{"title" => "Grouping Plan"}}, # fallback to filename
        {"custom_analysis.md", %{"title" => "Analysis", "group" => "research"}}, # custom group
        {"standalone.md", %{"title" => "Standalone"}} # no prefix, should be "other"
      ]

      grouped = MarkdownProcessor.group_files_by_metadata(files, "build")

      assert Map.keys(grouped) |> Enum.sort() == ["done", "other", "research", "strategy", "todo"]
      assert length(Map.get(grouped, "done")) == 2
      assert length(Map.get(grouped, "strategy")) == 1
      assert length(Map.get(grouped, "todo")) == 1
      assert length(Map.get(grouped, "research")) == 1
      assert length(Map.get(grouped, "other")) == 1
    end

    test "handles empty file list" do
      grouped = MarkdownProcessor.group_files_by_metadata([], "build")
      assert grouped == %{}
    end

    test "only groups build category files" do
      files = [{"done_test.md", %{"title" => "Test"}}]
      
      # Should group for build category
      grouped = MarkdownProcessor.group_files_by_metadata(files, "build")
      assert Map.has_key?(grouped, "done")
      
      # Should not group for non-build categories (return original structure)
      ungrouped = MarkdownProcessor.group_files_by_metadata(files, "dev")
      refute is_map(ungrouped) and Map.has_key?(ungrouped, "done")
    end
  end

  describe "convert_groups_to_nav_structure/1" do
    test "converts grouped files to navigation structure with collapsible groups" do
      grouped_files = %{
        "done" => [
          {"done_phase1.md", %{"title" => "Phase 1 Summary", "sub_group" => "phases"}},
          {"done_admin.md", %{"title" => "Admin Plan", "sub_group" => "admin"}}
        ],
        "strategy" => [
          {"strategy_security.md", %{"title" => "Security Audit", "category" => "security"}}
        ]
      }

      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(grouped_files)

      # Should create collapsible group structure
      assert length(nav_structure) == 2
      
      done_group = Enum.find(nav_structure, & &1.group == "done")
      assert done_group.title == "Done"
      assert done_group.type == :group
      assert done_group.collapsible == true
      assert length(done_group.children) == 2

      strategy_group = Enum.find(nav_structure, & &1.group == "strategy")
      assert strategy_group.title == "Strategy"
      assert strategy_group.type == :group
      assert strategy_group.collapsible == true
      assert length(strategy_group.children) == 1
    end

    test "creates sub-groups when sub_group metadata present" do
      grouped_files = %{
        "done" => [
          {"done_phase1.md", %{"title" => "Phase 1", "sub_group" => "phases"}},
          {"done_phase8.md", %{"title" => "Phase 8", "sub_group" => "phases"}},
          {"done_admin1.md", %{"title" => "Admin Plan 1", "sub_group" => "admin"}},
          {"done_admin2.md", %{"title" => "Admin Plan 2", "sub_group" => "admin"}}
        ]
      }

      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(grouped_files)
      done_group = Enum.find(nav_structure, & &1.group == "done")
      
      # Should create sub-groups
      phases_subgroup = Enum.find(done_group.children, & &1.title == "Phases")
      assert phases_subgroup.type == :sub_group
      assert phases_subgroup.collapsible == true
      assert length(phases_subgroup.children) == 2

      admin_subgroup = Enum.find(done_group.children, & &1.title == "Admin")
      assert admin_subgroup.type == :sub_group
      assert admin_subgroup.collapsible == true
      assert length(admin_subgroup.children) == 2
    end

    test "handles files without sub_group as direct children" do
      grouped_files = %{
        "strategy" => [
          {"strategy_analysis.md", %{"title" => "Analysis"}}, # no sub_group
          {"strategy_security.md", %{"title" => "Security", "sub_group" => "security"}}
        ]
      }

      nav_structure = MarkdownProcessor.convert_groups_to_nav_structure(grouped_files)
      strategy_group = Enum.find(nav_structure, & &1.group == "strategy")

      # Should have direct child for file without sub_group
      direct_child = Enum.find(strategy_group.children, & &1.title == "Analysis")
      assert direct_child.type == :page
      assert direct_child.path == "/build/strategy_analysis"

      # Should have sub-group for file with sub_group
      security_subgroup = Enum.find(strategy_group.children, & &1.title == "Security")
      assert security_subgroup.type == :sub_group
    end
  end

  describe "generate_navigation_with_grouping/0" do
    test "generates navigation with build category grouped by metadata" do
      {:ok, navigation} = MarkdownProcessor.generate_navigation()
      
      # Find build section
      build_section = Enum.find(navigation, fn item ->
        title = Map.get(item, :title) || Map.get(item, "title")
        title == "Build Documentation"
      end)

      if build_section do
        # Should have grouped children instead of flat list
        children = Map.get(build_section, :children) || []
        
        if length(children) > 0 do
          # Look for group-type children
          group_children = Enum.filter(children, fn child ->
            Map.get(child, :type) == :group
          end)
          
          # Should have at least one group (done, strategy, or todo)
          assert length(group_children) > 0, "Build section should have grouped children"
          
          # Verify group structure
          for group <- group_children do
            assert Map.has_key?(group, :group)
            assert Map.get(group, :collapsible) == true
            assert is_list(Map.get(group, :children, []))
          end
        end
      end
    end

    test "preserves non-build categories as flat navigation" do
      {:ok, navigation} = MarkdownProcessor.generate_navigation()
      
      # Find non-build sections (dev, user, test)
      non_build_sections = Enum.filter(navigation, fn item ->
        title = Map.get(item, :title) || Map.get(item, "title")
        title != "Build Documentation"
      end)

      # Non-build sections should maintain flat structure
      for section <- non_build_sections do
        children = Map.get(section, :children) || []
        
        if length(children) > 0 do
          # Should not have group-type children
          group_children = Enum.filter(children, fn child ->
            Map.get(child, :type) == :group
          end)
          
          assert length(group_children) == 0, 
                 "Non-build sections should not have grouped children"
        end
      end
    end
  end

  describe "metadata extraction and processing" do
    test "extracts all required YAML properties" do
      content = """
      ---
      title: "Test Document"
      author: "Claude"
      group: "custom"
      sub_group: "testing"
      status: "live"
      category: "implementation"
      priority: "high"
      tags: ["test", "yaml", "metadata"]
      last_modified: "2025-01-21"
      ---
      # Test Content
      """

      {:ok, _html, metadata} = MarkdownProcessor.process_content(content)
      
      assert metadata["title"] == "Test Document"
      assert metadata["author"] == "Claude"
      assert metadata["group"] == "custom"
      assert metadata["sub_group"] == "testing"
      assert metadata["status"] == "live"
      assert metadata["category"] == "implementation"
      assert metadata["priority"] == "high"
      assert metadata["tags"] == ["test", "yaml", "metadata"]
      assert metadata["last_modified"] == "2025-01-21"
    end

    test "handles missing YAML properties gracefully" do
      content = """
      ---
      title: "Minimal Document"
      ---
      # Content
      """

      {:ok, _html, metadata} = MarkdownProcessor.process_content(content)
      
      assert metadata["title"] == "Minimal Document"
      assert metadata["group"] == nil
      assert metadata["sub_group"] == nil
      assert metadata["status"] == nil
    end

    test "processes files for navigation with full metadata" do
      # This would test the integration with actual file processing
      # when the build directory has files with proper frontmatter
      
      # Create mock file data that simulates what would be found
      mock_files = [
        %{
          file_path: "build/done_phase1.md",
          metadata: %{
            "title" => "Phase 1 Summary",
            "author" => "Claude", 
            "group" => "done",
            "sub_group" => "phases",
            "status" => "live",
            "tags" => ["implementation", "phase-1"]
          }
        }
      ]

      # Simulate processing these files into navigation
      for file_data <- mock_files do
        group = MarkdownProcessor.determine_group({
          file_data.file_path, 
          file_data.metadata
        })
        
        assert group == "done"
        assert file_data.metadata["sub_group"] == "phases"
        assert is_list(file_data.metadata["tags"])
      end
    end
  end

  describe "sorting and filtering capabilities" do
    test "sorts files within groups by priority" do
      files = [
        {"done_low.md", %{"title" => "Low Priority", "priority" => "low"}},
        {"done_high.md", %{"title" => "High Priority", "priority" => "high"}},
        {"done_medium.md", %{"title" => "Medium Priority", "priority" => "medium"}}
      ]

      sorted = MarkdownProcessor.sort_files_by_priority(files)
      
      priorities = Enum.map(sorted, fn {_path, metadata} -> 
        Map.get(metadata, "priority") 
      end)
      
      assert priorities == ["high", "medium", "low"]
    end

    test "groups files by category for filtering" do
      files = [
        {"done_security1.md", %{"title" => "Security Plan", "category" => "security"}},
        {"done_admin1.md", %{"title" => "Admin Plan", "category" => "admin"}},
        {"done_security2.md", %{"title" => "Auth Plan", "category" => "security"}},
        {"done_impl.md", %{"title" => "Implementation", "category" => "implementation"}}
      ]

      categories = MarkdownProcessor.group_by_category(files)
      
      assert length(Map.get(categories, "security")) == 2
      assert length(Map.get(categories, "admin")) == 1  
      assert length(Map.get(categories, "implementation")) == 1
    end

    test "filters files by status" do
      files = [
        {"done_live1.md", %{"title" => "Live Doc 1", "status" => "live"}},
        {"done_archived.md", %{"title" => "Archived Doc", "status" => "archived"}},
        {"done_live2.md", %{"title" => "Live Doc 2", "status" => "live"}},
        {"done_no_status.md", %{"title" => "No Status"}}
      ]

      live_files = MarkdownProcessor.filter_by_status(files, "live")
      archived_files = MarkdownProcessor.filter_by_status(files, "archived")
      
      assert length(live_files) == 2
      assert length(archived_files) == 1
    end

    test "filters files by tags" do
      files = [
        {"done_impl.md", %{"title" => "Implementation", "tags" => ["implementation", "ash"]}},
        {"done_security.md", %{"title" => "Security", "tags" => ["security", "auth"]}},
        {"done_phase.md", %{"title" => "Phase 1", "tags" => ["phase-1", "implementation"]}},
        {"done_admin.md", %{"title" => "Admin", "tags" => ["admin", "ui"]}}
      ]

      impl_files = MarkdownProcessor.filter_by_tag(files, "implementation")
      security_files = MarkdownProcessor.filter_by_tag(files, "security")
      
      assert length(impl_files) == 2  # implementation and phase files
      assert length(security_files) == 1
    end
  end

  describe "dynamic group creation" do
    test "creates new groups automatically from filename prefixes" do
      files = [
        {"meeting_notes.md", %{"title" => "Meeting Notes"}},
        {"spec_api.md", %{"title" => "API Spec"}},
        {"research_analysis.md", %{"title" => "Research"}},
        {"done_phase.md", %{"title" => "Phase 1"}}
      ]

      grouped = MarkdownProcessor.group_files_by_metadata(files, "build")
      
      # Should automatically create groups for new prefixes
      assert Map.has_key?(grouped, "meeting")
      assert Map.has_key?(grouped, "spec")
      assert Map.has_key?(grouped, "research")
      assert Map.has_key?(grouped, "done")
      
      assert map_size(grouped) == 4
    end

    test "handles mixed existing and new group prefixes" do
      files = [
        {"done_existing.md", %{"title" => "Existing Group"}},
        {"brainstorm_ideas.md", %{"title" => "New Group 1"}},
        {"proposal_feature.md", %{"title" => "New Group 2"}},
        {"todo_existing.md", %{"title" => "Another Existing"}}
      ]

      grouped = MarkdownProcessor.group_files_by_metadata(files, "build")
      
      # Should handle both existing and new groups
      groups = Map.keys(grouped) |> Enum.sort()
      assert groups == ["brainstorm", "done", "proposal", "todo"]
    end
  end

  describe "error handling and edge cases" do
    test "handles files with malformed frontmatter gracefully" do
      content = """
      ---
      title: "Good Title"
      group: ["invalid", "array", "for", "group"]
      status: 123
      tags: "should be array but is string"
      ---
      # Content
      """

      {:ok, _html, metadata} = MarkdownProcessor.process_content(content)
      
      # Should extract valid fields and skip invalid ones
      assert metadata["title"] == "Good Title"
      # Invalid group should fallback to filename inference
    end

    test "handles empty groups gracefully" do
      grouped = MarkdownProcessor.convert_groups_to_nav_structure(%{})
      assert grouped == []
    end

    test "handles files without proper filename structure" do
      files = [
        {"file-with-dashes.md", %{"title" => "Dashes"}},
        {"file.without.extension", %{"title" => "No Ext"}},
        {"", %{"title" => "Empty Filename"}}
      ]

      for {filename, metadata} <- files do
        group = MarkdownProcessor.determine_group({filename, metadata})
        assert group == "other"
      end
    end
  end
end