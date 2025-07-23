defmodule SertantaiDocs.Navigation.SubGroupTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.MarkdownProcessor

  @moduledoc """
  TDD tests focused on sub-group functionality within the navigation system.
  
  Tests comprehensive sub-grouping features:
  - Sub-group creation from YAML metadata and filename inference
  - Hierarchical navigation structure with collapsible sub-groups
  - Mixed sub-grouped and direct children within main groups
  - Sub-group sorting, ordering, and organization
  - Edge cases and complex sub-group scenarios
  """

  describe "create_sub_groups_from_metadata/1" do
    test "creates sub-groups from sub_group metadata" do
      files_with_subgroups = [
        {"done_phase1.md", %{"title" => "Phase 1", "sub_group" => "phases"}},
        {"done_phase8.md", %{"title" => "Phase 8", "sub_group" => "phases"}},
        {"done_admin1.md", %{"title" => "Admin Plan 1", "sub_group" => "admin"}},
        {"done_admin2.md", %{"title" => "Admin Plan 2", "sub_group" => "admin"}},
        {"done_security.md", %{"title" => "Security Audit", "sub_group" => "security"}}
      ]
      
      sub_groups = MarkdownProcessor.create_sub_groups_from_metadata(files_with_subgroups)
      
      # Should create three sub-groups
      assert Map.keys(sub_groups) |> Enum.sort() == ["admin", "phases", "security"]
      
      # Phases sub-group should have 2 items
      assert length(Map.get(sub_groups, "phases")) == 2
      
      # Admin sub-group should have 2 items  
      assert length(Map.get(sub_groups, "admin")) == 2
      
      # Security sub-group should have 1 item
      assert length(Map.get(sub_groups, "security")) == 1
    end

    test "handles files without sub_group metadata" do
      mixed_files = [
        {"done_phase1.md", %{"title" => "Phase 1", "sub_group" => "phases"}},
        {"done_standalone.md", %{"title" => "Standalone Doc"}}, # no sub_group
        {"done_admin.md", %{"title" => "Admin Plan", "sub_group" => "admin"}},
        {"done_other.md", %{"title" => "Other Doc"}} # no sub_group
      ]
      
      {sub_groups, ungrouped} = MarkdownProcessor.separate_sub_grouped_files(mixed_files)
      
      # Sub-groups created
      assert Map.has_key?(sub_groups, "phases")
      assert Map.has_key?(sub_groups, "admin")
      
      # Ungrouped files separated
      assert length(ungrouped) == 2
      ungrouped_titles = Enum.map(ungrouped, fn {_path, meta} -> meta["title"] end)
      assert "Standalone Doc" in ungrouped_titles
      assert "Other Doc" in ungrouped_titles
    end

    test "groups files by sub_group with proper metadata structure" do
      files = [
        {"done_phase1_summary.md", %{
          "title" => "Phase 1 Summary", 
          "sub_group" => "phases",
          "priority" => "high",
          "tags" => ["phase-1", "summary"]
        }},
        {"done_phase8_completion.md", %{
          "title" => "Phase 8 Completion",
          "sub_group" => "phases", 
          "priority" => "medium",
          "tags" => ["phase-8", "completion"]
        }}
      ]
      
      sub_groups = MarkdownProcessor.create_sub_groups_from_metadata(files)
      phases_files = Map.get(sub_groups, "phases")
      
      # Should preserve all metadata
      phase1_file = Enum.find(phases_files, fn {_path, meta} -> 
        meta["title"] == "Phase 1 Summary" 
      end)
      
      {_path, metadata} = phase1_file
      assert metadata["priority"] == "high"
      assert metadata["tags"] == ["phase-1", "summary"]
      assert metadata["sub_group"] == "phases"
    end
  end

  describe "build_sub_group_navigation_structure/1" do
    test "converts sub-grouped files to hierarchical navigation structure" do
      sub_groups = %{
        "phases" => [
          {"done_phase1.md", %{"title" => "Phase 1 Summary"}},
          {"done_phase8.md", %{"title" => "Phase 8 Completion"}}
        ],
        "admin" => [
          {"done_admin_ui.md", %{"title" => "Admin UI Plan"}},
          {"done_admin_api.md", %{"title" => "Admin API Plan"}}
        ]
      }
      
      nav_structure = MarkdownProcessor.build_sub_group_navigation_structure(sub_groups)
      
      # Should create two sub-group items
      assert length(nav_structure) == 2
      
      # Find phases sub-group
      phases_subgroup = Enum.find(nav_structure, & &1.title == "Phases")
      assert phases_subgroup.type == :sub_group
      assert phases_subgroup.collapsible == true
      assert length(phases_subgroup.children) == 2
      
      # Verify phases children structure
      phase1_child = Enum.find(phases_subgroup.children, & &1.title == "Phase 1 Summary")
      assert phase1_child.type == :page
      assert phase1_child.path == "/build/done_phase1"
      
      # Find admin sub-group
      admin_subgroup = Enum.find(nav_structure, & &1.title == "Admin")
      assert admin_subgroup.type == :sub_group
      assert admin_subgroup.collapsible == true
      assert length(admin_subgroup.children) == 2
    end

    test "sorts sub-group children by priority and title" do
      sub_groups = %{
        "phases" => [
          {"done_phase8.md", %{"title" => "Phase 8 (Medium)", "priority" => "medium"}},
          {"done_phase1.md", %{"title" => "Phase 1 (High)", "priority" => "high"}},
          {"done_phase3.md", %{"title" => "Phase 3 (Low)", "priority" => "low"}},
          {"done_phase2.md", %{"title" => "Phase 2 (High)", "priority" => "high"}}
        ]
      }
      
      nav_structure = MarkdownProcessor.build_sub_group_navigation_structure(sub_groups)
      phases_subgroup = Enum.find(nav_structure, & &1.title == "Phases")
      
      # Should be sorted by priority (high, medium, low), then by title
      titles = Enum.map(phases_subgroup.children, & &1.title)
      expected_order = [
        "Phase 1 (High)",  # high priority, alphabetically first
        "Phase 2 (High)",  # high priority, alphabetically second  
        "Phase 8 (Medium)", # medium priority
        "Phase 3 (Low)"    # low priority
      ]
      
      assert titles == expected_order
    end

    test "creates sub-group titles with proper capitalization" do
      sub_groups = %{
        "admin_interface" => [{"file.md", %{"title" => "Test"}}],
        "security_audit" => [{"file.md", %{"title" => "Test"}}],
        "api_design" => [{"file.md", %{"title" => "Test"}}],
        "user_experience" => [{"file.md", %{"title" => "Test"}}]
      }
      
      nav_structure = MarkdownProcessor.build_sub_group_navigation_structure(sub_groups)
      titles = Enum.map(nav_structure, & &1.title) |> Enum.sort()
      
      expected_titles = [
        "Admin Interface",
        "Api Design", 
        "Security Audit",
        "User Experience"
      ]
      
      assert titles == expected_titles
    end
  end

  describe "merge_sub_groups_with_ungrouped/2" do
    test "merges sub-groups and ungrouped files into unified structure" do
      sub_group_nav = [
        %{title: "Phases", type: :sub_group, collapsible: true, children: [
          %{title: "Phase 1", type: :page, path: "/build/done_phase1"}
        ]},
        %{title: "Admin", type: :sub_group, collapsible: true, children: [
          %{title: "Admin Plan", type: :page, path: "/build/done_admin"}
        ]}
      ]
      
      ungrouped_files = [
        {"done_standalone.md", %{"title" => "Standalone Document"}},
        {"done_other.md", %{"title" => "Other Document"}}
      ]
      
      merged = MarkdownProcessor.merge_sub_groups_with_ungrouped(sub_group_nav, ungrouped_files)
      
      # Should have sub-groups plus direct children
      assert length(merged) == 4 # 2 sub-groups + 2 ungrouped
      
      # Sub-groups preserved
      phases_subgroup = Enum.find(merged, & &1.title == "Phases")
      assert phases_subgroup.type == :sub_group
      
      # Ungrouped files as direct children
      standalone = Enum.find(merged, & &1.title == "Standalone Document")
      assert standalone.type == :page
      assert standalone.path == "/build/done_standalone"
    end

    test "handles empty sub-groups" do
      sub_group_nav = []
      ungrouped_files = [
        {"done_file1.md", %{"title" => "File 1"}},
        {"done_file2.md", %{"title" => "File 2"}}
      ]
      
      merged = MarkdownProcessor.merge_sub_groups_with_ungrouped(sub_group_nav, ungrouped_files)
      
      # Should only have direct children
      assert length(merged) == 2
      assert Enum.all?(merged, & &1.type == :page)
    end

    test "handles no ungrouped files" do
      sub_group_nav = [
        %{title: "Test Group", type: :sub_group, collapsible: true, children: []}
      ]
      ungrouped_files = []
      
      merged = MarkdownProcessor.merge_sub_groups_with_ungrouped(sub_group_nav, ungrouped_files)
      
      # Should only have sub-groups
      assert length(merged) == 1
      assert List.first(merged).type == :sub_group
    end

    test "sorts merged structure with sub-groups first, then ungrouped" do
      sub_group_nav = [
        %{title: "Z Sub Group", type: :sub_group, collapsible: true, children: []},
        %{title: "A Sub Group", type: :sub_group, collapsible: true, children: []}
      ]
      
      ungrouped_files = [
        {"done_z_file.md", %{"title" => "Z File"}},
        {"done_a_file.md", %{"title" => "A File"}}
      ]
      
      merged = MarkdownProcessor.merge_sub_groups_with_ungrouped(sub_group_nav, ungrouped_files)
      
      # Sub-groups should come first (sorted alphabetically)
      # Then ungrouped files (sorted alphabetically)
      titles = Enum.map(merged, & &1.title)
      expected_order = ["A Sub Group", "Z Sub Group", "A File", "Z File"]
      
      assert titles == expected_order
    end
  end

  describe "sub_group_inference_from_filename/1" do
    test "infers sub-groups from filename patterns" do
      inference_cases = [
        {"done_phase_1_summary.md", "phases"},
        {"done_phase_8_completion.md", "phases"},
        {"done_custom_admin_ui.md", "admin"},
        {"done_admin_interface_plan.md", "admin"},
        {"strategy_security_audit.md", "security"},
        {"strategy_auth_implementation.md", "security"},
        {"todo_documentation_system.md", "docs"},
        {"todo_docs_enhancement.md", "docs"},
        {"done_action_plan_part1.md", "planning"},
        {"done_test_execution_plan.md", "testing"},
        {"strategy_architecture_analysis.md", "architecture"},
        {"done_applicability_study.md", "applicability"}
      ]
      
      for {filename, expected_sub_group} <- inference_cases do
        inferred = MarkdownProcessor.infer_sub_group_from_filename(filename)
        assert inferred == expected_sub_group, 
               "Failed to infer '#{expected_sub_group}' from '#{filename}', got '#{inferred}'"
      end
    end

    test "handles multiple possible sub-group indicators" do
      # Filenames with multiple possible sub-group keywords
      ambiguous_cases = [
        {"done_admin_security_plan.md", ["admin", "security"]}, # either is valid
        {"strategy_docs_admin_system.md", ["docs", "admin"]},
        {"todo_phase_1_security_audit.md", ["phases", "security"]}
      ]
      
      for {filename, possible_sub_groups} <- ambiguous_cases do
        inferred = MarkdownProcessor.infer_sub_group_from_filename(filename)
        assert inferred in possible_sub_groups,
               "Expected one of #{inspect(possible_sub_groups)} from '#{filename}', got '#{inferred}'"
      end
    end

    test "provides reasonable fallback for unclear filenames" do
      unclear_cases = [
        "done_general_plan.md",
        "strategy_analysis.md",
        "todo_implementation.md",
        "done_task.md"
      ]
      
      for filename <- unclear_cases do
        inferred = MarkdownProcessor.infer_sub_group_from_filename(filename)
        assert inferred == "general" or is_nil(inferred),
               "Expected 'general' or nil for unclear filename '#{filename}', got '#{inferred}'"
      end
    end
  end

  describe "sub_group_collision_handling/1" do
    test "handles files with conflicting sub_group metadata vs inference" do
      conflicting_files = [
        # YAML says "phases" but filename suggests "admin"
        {"done_admin_phase_1.md", %{
          "title" => "Admin Phase 1", 
          "sub_group" => "phases" # explicit YAML
        }},
        # YAML says "security" but filename suggests "docs"  
        {"done_documentation_security.md", %{
          "title" => "Documentation Security",
          "sub_group" => "security" # explicit YAML
        }}
      ]
      
      sub_groups = MarkdownProcessor.create_sub_groups_from_metadata(conflicting_files)
      
      # Should use explicit YAML sub_group over filename inference
      assert Map.has_key?(sub_groups, "phases")
      assert Map.has_key?(sub_groups, "security")
      refute Map.has_key?(sub_groups, "admin")
      refute Map.has_key?(sub_groups, "docs")
      
      # Verify files are in correct sub-groups based on YAML
      phases_files = Map.get(sub_groups, "phases")
      assert length(phases_files) == 1
      {_path, metadata} = List.first(phases_files)
      assert metadata["title"] == "Admin Phase 1"
    end

    test "merges similar sub-group names intelligently" do
      similar_subgroups = [
        {"file1.md", %{"title" => "File 1", "sub_group" => "admin"}},
        {"file2.md", %{"title" => "File 2", "sub_group" => "administration"}},
        {"file3.md", %{"title" => "File 3", "sub_group" => "admin_interface"}},
        {"file4.md", %{"title" => "File 4", "sub_group" => "security"}},
        {"file5.md", %{"title" => "File 5", "sub_group" => "security_audit"}}
      ]
      
      normalized = MarkdownProcessor.normalize_similar_sub_groups(similar_subgroups)
      
      # Similar admin sub-groups should be merged
      admin_group = Map.get(normalized, "admin")
      assert length(admin_group) >= 2 # merged admin variations
      
      # Similar security sub-groups should be merged
      security_group = Map.get(normalized, "security")  
      assert length(security_group) >= 2 # merged security variations
    end
  end

  describe "complex_sub_group_scenarios/1" do
    test "handles deeply nested sub-group organization" do
      # Complex scenario with multiple levels of organization
      complex_files = [
        # Phase documents with different priorities
        {"done_phase_1_planning.md", %{
          "title" => "Phase 1 Planning", 
          "sub_group" => "phases",
          "category" => "planning",
          "priority" => "high"
        }},
        {"done_phase_1_implementation.md", %{
          "title" => "Phase 1 Implementation",
          "sub_group" => "phases", 
          "category" => "implementation",
          "priority" => "high"
        }},
        {"done_phase_8_completion.md", %{
          "title" => "Phase 8 Completion",
          "sub_group" => "phases",
          "category" => "completion", 
          "priority" => "medium"
        }},
        
        # Admin documents with different aspects
        {"done_admin_ui_design.md", %{
          "title" => "Admin UI Design",
          "sub_group" => "admin",
          "category" => "design",
          "priority" => "medium"
        }},
        {"done_admin_api_implementation.md", %{
          "title" => "Admin API Implementation", 
          "sub_group" => "admin",
          "category" => "implementation",
          "priority" => "high"
        }},
        
        # Standalone documents
        {"done_general_cleanup.md", %{
          "title" => "General Cleanup",
          "priority" => "low"
        }}
      ]
      
      {sub_groups, ungrouped} = MarkdownProcessor.separate_sub_grouped_files(complex_files)
      nav_structure = MarkdownProcessor.build_sub_group_navigation_structure(sub_groups)
      merged = MarkdownProcessor.merge_sub_groups_with_ungrouped(nav_structure, ungrouped)
      
      # Should have organized structure
      assert length(merged) == 3 # phases sub-group, admin sub-group, standalone doc
      
      # Verify phases sub-group
      phases_subgroup = Enum.find(merged, & &1.title == "Phases")
      assert phases_subgroup.type == :sub_group
      assert length(phases_subgroup.children) == 3
      
      # High priority phases should come first
      first_phase = List.first(phases_subgroup.children)
      assert first_phase.metadata["priority"] == "high"
      
      # Verify admin sub-group
      admin_subgroup = Enum.find(merged, & &1.title == "Admin")
      assert admin_subgroup.type == :sub_group
      assert length(admin_subgroup.children) == 2
      
      # High priority admin should come first
      first_admin = List.first(admin_subgroup.children)
      assert first_admin.metadata["priority"] == "high"
      
      # Verify standalone document
      standalone = Enum.find(merged, & &1.title == "General Cleanup")
      assert standalone.type == :page
    end

    test "handles empty sub-groups gracefully" do
      # Sub-group exists but has no files after filtering
      files_with_empty_subgroup = []
      
      sub_groups = MarkdownProcessor.create_sub_groups_from_metadata(files_with_empty_subgroup)
      nav_structure = MarkdownProcessor.build_sub_group_navigation_structure(sub_groups)
      
      assert nav_structure == []
    end

    test "preserves sub-group metadata for filtering and sorting" do
      files = [
        {"done_phase1.md", %{
          "title" => "Phase 1",
          "sub_group" => "phases",
          "tags" => ["phase-1", "initial"],
          "status" => "archived",
          "author" => "Claude"
        }}
      ]
      
      sub_groups = MarkdownProcessor.create_sub_groups_from_metadata(files)
      nav_structure = MarkdownProcessor.build_sub_group_navigation_structure(sub_groups)
      
      phases_subgroup = List.first(nav_structure)
      phase1_child = List.first(phases_subgroup.children)
      
      # Metadata should be preserved for future filtering/sorting
      assert phase1_child.metadata["tags"] == ["phase-1", "initial"]
      assert phase1_child.metadata["status"] == "archived"
      assert phase1_child.metadata["author"] == "Claude"
    end
  end

  describe "sub_group_performance_and_scalability/1" do
    test "handles large numbers of files efficiently" do
      # Generate large number of files across multiple sub-groups
      large_file_set = for i <- 1..1000 do
        sub_group = Enum.random(["phases", "admin", "security", "docs", "testing"])
        {
          "done_file_#{i}.md",
          %{
            "title" => "File #{i}",
            "sub_group" => sub_group,
            "priority" => Enum.random(["high", "medium", "low"])
          }
        }
      end
      
      # Measure performance
      start_time = System.monotonic_time()
      sub_groups = MarkdownProcessor.create_sub_groups_from_metadata(large_file_set)
      nav_structure = MarkdownProcessor.build_sub_group_navigation_structure(sub_groups)
      end_time = System.monotonic_time()
      
      processing_time_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)
      
      # Should complete in reasonable time (< 100ms)
      assert processing_time_ms < 100
      
      # Should produce correct structure
      assert length(nav_structure) <= 5 # max 5 sub-groups
      total_children = Enum.reduce(nav_structure, 0, fn subgroup, acc ->
        acc + length(subgroup.children)
      end)
      assert total_children == 1000 # all files accounted for
    end

    test "maintains consistent memory usage with large sub-groups" do
      # Generate files heavily concentrated in single sub-group
      concentrated_files = for i <- 1..500 do
        {
          "done_phase_#{i}_task.md",
          %{"title" => "Phase #{i} Task", "sub_group" => "phases"}
        }
      end
      
      # Process without memory issues
      sub_groups = MarkdownProcessor.create_sub_groups_from_metadata(concentrated_files)
      nav_structure = MarkdownProcessor.build_sub_group_navigation_structure(sub_groups)
      
      # Should handle large single sub-group
      phases_subgroup = List.first(nav_structure)
      assert phases_subgroup.title == "Phases"
      assert length(phases_subgroup.children) == 500
    end
  end
end