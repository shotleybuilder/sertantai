defmodule SertantaiDocs.Navigation.HybridFallbackTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.MarkdownProcessor

  @moduledoc """
  TDD tests for hybrid YAML frontmatter + filename fallback logic.
  
  Tests comprehensive fallback scenarios:
  - YAML frontmatter takes precedence when present and valid
  - Filename inference used when YAML missing or invalid
  - Graceful handling of edge cases and error conditions
  - Integration between YAML and filename-based systems
  """

  describe "hybrid_group_determination/2" do
    test "uses YAML group when present and valid" do
      yaml_metadata = %{"group" => "custom_yaml_group"}
      file_path = "build/done_something.md"
      
      group = MarkdownProcessor.hybrid_group_determination(yaml_metadata, file_path)
      assert group == "custom_yaml_group"
    end

    test "falls back to filename when YAML group is nil" do
      yaml_metadata = %{"group" => nil, "title" => "Some Title"}
      file_path = "build/strategy_analysis.md"
      
      group = MarkdownProcessor.hybrid_group_determination(yaml_metadata, file_path)
      assert group == "strategy"
    end

    test "falls back to filename when YAML group is empty string" do
      yaml_metadata = %{"group" => "", "author" => "Claude"}
      file_path = "build/todo_implementation.md"
      
      group = MarkdownProcessor.hybrid_group_determination(yaml_metadata, file_path)
      assert group == "todo"
    end

    test "falls back to filename when YAML group is invalid type" do
      invalid_types = [123, [], %{}, true, :atom]
      
      for invalid_group <- invalid_types do
        yaml_metadata = %{"group" => invalid_group}
        file_path = "build/meeting_notes.md"
        
        group = MarkdownProcessor.hybrid_group_determination(yaml_metadata, file_path)
        assert group == "meeting"
      end
    end

    test "falls back to filename when no YAML metadata present" do
      yaml_metadata = %{}
      file_path = "build/spec_api_design.md"
      
      group = MarkdownProcessor.hybrid_group_determination(yaml_metadata, file_path)
      assert group == "spec"
    end

    test "handles files with no prefix and no YAML group" do
      yaml_metadata = %{}
      file_path = "build/readme.md"
      
      group = MarkdownProcessor.hybrid_group_determination(yaml_metadata, file_path)
      assert group == "other"
    end
  end

  describe "hybrid_metadata_resolution/2" do
    test "YAML metadata takes full precedence when complete" do
      yaml_metadata = %{
        "title" => "YAML Title",
        "group" => "yaml_group",
        "sub_group" => "yaml_sub",
        "status" => "archived",
        "category" => "yaml_category",
        "priority" => "high",
        "tags" => ["yaml", "tags"],
        "author" => "YAML Author"
      }
      
      file_path = "build/done_phase_implementation.md"
      
      resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
      
      # All YAML values should be preserved
      assert resolved["title"] == "YAML Title"
      assert resolved["group"] == "yaml_group"
      assert resolved["sub_group"] == "yaml_sub"
      assert resolved["status"] == "archived"
      assert resolved["category"] == "yaml_category"
      assert resolved["priority"] == "high"
      assert resolved["tags"] == ["yaml", "tags"]
      assert resolved["author"] == "YAML Author"
    end

    test "fills missing YAML fields with filename inferences" do
      yaml_metadata = %{
        "title" => "YAML Title",
        "author" => "Claude"
        # Missing: group, sub_group, status, category, priority, tags
      }
      
      file_path = "build/done_security_admin_implementation.md"
      
      resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
      
      # YAML fields preserved
      assert resolved["title"] == "YAML Title"
      assert resolved["author"] == "Claude"
      
      # Inferred fields added
      assert resolved["group"] == "done"
      assert resolved["sub_group"] == "security" # or "admin" - depends on implementation
      assert resolved["category"] == "security" # or "implementation"
      assert is_list(resolved["tags"])
      assert "done" in resolved["tags"]
      assert "security" in resolved["tags"]
    end

    test "uses inferred values for invalid YAML fields" do
      yaml_metadata = %{
        "title" => "Valid Title",
        "group" => 123, # invalid type
        "sub_group" => [], # invalid type
        "status" => "invalid_status", # invalid value
        "priority" => %{}, # invalid type
        "tags" => "should_be_array" # wrong type
      }
      
      file_path = "build/strategy_architecture_analysis.md"
      
      resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
      
      # Valid YAML preserved
      assert resolved["title"] == "Valid Title"
      
      # Invalid YAML replaced with inferences
      assert resolved["group"] == "strategy"
      assert resolved["sub_group"] != []
      assert resolved["status"] in ["live", "archived"] # normalized value
      assert resolved["priority"] in ["high", "medium", "low"]
      assert is_list(resolved["tags"])
    end

    test "handles partial YAML with mixed valid and invalid fields" do
      yaml_metadata = %{
        "title" => "Mixed Document",
        "group" => "valid_group", # valid
        "sub_group" => nil, # should use inference  
        "status" => "live", # valid
        "category" => "", # empty - should use inference
        "priority" => "INVALID", # invalid value - should normalize
        "tags" => ["valid", 123, "tags"], # mixed array - should filter
        "author" => "Claude" # valid
      }
      
      file_path = "build/todo_documentation_system.md"
      
      resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
      
      # Valid YAML fields preserved
      assert resolved["title"] == "Mixed Document"
      assert resolved["group"] == "valid_group"
      assert resolved["status"] == "live"
      assert resolved["author"] == "Claude"
      
      # Invalid/empty YAML fields replaced with inferences
      assert resolved["sub_group"] == "docs" # inferred from filename
      assert resolved["category"] == "docs" # inferred from filename
      assert resolved["priority"] == "medium" # normalized from invalid
      assert resolved["tags"] == ["valid", "tags"] # filtered and enhanced with inferences
    end
  end

  describe "fallback_priority_handling/2" do
    test "respects explicit priority order: YAML > filename inference > defaults" do
      scenarios = [
        # YAML present and valid - highest priority
        {%{"priority" => "high"}, "build/todo_plan.md", "high"},
        {%{"priority" => "low"}, "build/done_urgent_task.md", "low"},
        
        # YAML invalid - use filename inference
        {%{"priority" => "invalid"}, "build/done_urgent_security.md", "high"}, # urgent -> high
        {%{"priority" => nil}, "build/todo_low_priority_task.md", "low"}, # low -> low
        
        # No YAML - use filename inference
        {%{}, "build/strategy_critical_analysis.md", "high"}, # critical -> high
        {%{}, "build/done_minor_fix.md", "low"}, # minor -> low
        
        # No indicators - use default
        {%{}, "build/done_regular_task.md", "medium"}, # default
      ]
      
      for {yaml_metadata, file_path, expected_priority} <- scenarios do
        resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
        assert resolved["priority"] == expected_priority, 
               "Failed for #{file_path} with YAML #{inspect(yaml_metadata)}"
      end
    end

    test "normalizes priority values correctly in fallback chain" do
      normalization_cases = [
        # YAML normalization
        {"HIGH", "high"},
        {"Med", "medium"}, 
        {"LOW", "low"},
        {"critical", "high"}, # synonym
        {"urgent", "high"}, # synonym
        {"normal", "medium"}, # synonym
        
        # Invalid YAML - falls back to filename + default
        {"invalid", "medium"}, # default fallback
        {123, "medium"}, # invalid type fallback
      ]
      
      for {yaml_priority, expected} <- normalization_cases do
        yaml_metadata = %{"priority" => yaml_priority}
        file_path = "build/done_regular_task.md"
        
        resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
        assert resolved["priority"] == expected
      end
    end
  end

  describe "status_fallback_handling/2" do
    test "uses YAML status when valid" do
      valid_statuses = ["live", "archived"]
      
      for status <- valid_statuses do
        yaml_metadata = %{"status" => status}
        file_path = "build/done_test.md"
        
        resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
        assert resolved["status"] == status
      end
    end

    test "normalizes and accepts status synonyms from YAML" do
      synonym_cases = [
        {"active", "live"},
        {"published", "live"},
        {"current", "live"},
        {"archive", "archived"},
        {"inactive", "archived"},
        {"deprecated", "archived"},
        {"old", "archived"}
      ]
      
      for {yaml_status, expected} <- synonym_cases do
        yaml_metadata = %{"status" => yaml_status}
        file_path = "build/strategy_analysis.md"
        
        resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
        assert resolved["status"] == expected
      end
    end

    test "falls back to filename inference for invalid YAML status" do
      invalid_statuses = [nil, "", "invalid", 123, []]
      
      for invalid_status <- invalid_statuses do
        yaml_metadata = %{"status" => invalid_status}
        
        # Filename with status indicators
        file_path = "build/archive_old_plan.md"
        resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
        assert resolved["status"] == "archived" # inferred from "archive"
        
        # Filename without status indicators - use default
        file_path2 = "build/done_regular_task.md"
        resolved2 = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path2)
        assert resolved2["status"] == "live" # default
      end
    end
  end

  describe "tags_hybridization/2" do
    test "merges YAML tags with filename-inferred tags" do
      yaml_metadata = %{
        "tags" => ["yaml-tag", "custom", "user-defined"]
      }
      file_path = "build/done_phase_1_security_implementation.md"
      
      resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
      
      # Should include both YAML and inferred tags
      tags = resolved["tags"]
      
      # YAML tags preserved
      assert "yaml-tag" in tags
      assert "custom" in tags
      assert "user-defined" in tags
      
      # Inferred tags added
      assert "done" in tags # from group
      assert "phases" in tags # from sub_group inference
      assert "security" in tags # from keyword detection
      assert "implementation" in tags # from keyword detection
      
      # Should be unique (no duplicates)
      assert length(tags) == length(Enum.uniq(tags))
    end

    test "filters invalid tags and normalizes format" do
      yaml_metadata = %{
        "tags" => ["valid", 123, "also-valid", nil, "", "   whitespace   ", true]
      }
      file_path = "build/strategy_admin_analysis.md"
      
      resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
      tags = resolved["tags"]
      
      # Valid tags preserved and normalized
      assert "valid" in tags
      assert "also-valid" in tags
      assert "whitespace" in tags # trimmed
      
      # Invalid tags filtered out
      refute 123 in tags
      refute nil in tags
      refute "" in tags
      refute true in tags
      
      # Inferred tags added
      assert "strategy" in tags
      assert "admin" in tags
    end

    test "handles YAML tags as string (converts to array)" do
      yaml_metadata = %{
        "tags" => "single-tag-as-string"
      }
      file_path = "build/todo_documentation.md"
      
      resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
      tags = resolved["tags"]
      
      # String converted to array
      assert "single-tag-as-string" in tags
      
      # Inferred tags also added
      assert "todo" in tags
      assert "documentation" in tags
    end

    test "falls back to pure inference when YAML tags invalid" do
      invalid_tag_types = [123, %{}, :atom, nil]
      
      for invalid_tags <- invalid_tag_types do
        yaml_metadata = %{"tags" => invalid_tags}
        file_path = "build/done_security_audit_report.md"
        
        resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
        tags = resolved["tags"]
        
        # Should only contain inferred tags
        assert "done" in tags
        assert "security" in tags
        assert "audit" in tags or "analysis" in tags
        
        # Should not contain any invalid values
        refute invalid_tags in tags
      end
    end
  end

  describe "complete_fallback_integration/2" do
    test "handles completely missing YAML with comprehensive filename inference" do
      # No YAML frontmatter at all
      yaml_metadata = %{}
      file_path = "build/done_phase_8_completion_summary.md"
      
      resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
      
      # All fields should be inferred from filename
      assert resolved["title"] == "Phase 8 Completion Summary"
      assert resolved["group"] == "done"
      assert resolved["sub_group"] == "phases"
      assert resolved["category"] == "implementation"
      assert resolved["priority"] == "medium" # default
      assert resolved["status"] == "live" # default
      assert is_list(resolved["tags"])
      assert "done" in resolved["tags"]
      assert "phases" in resolved["tags"]
    end

    test "handles malformed YAML with graceful fallback" do
      # Completely malformed YAML metadata
      yaml_metadata = %{
        "title" => nil,
        "group" => [],
        "sub_group" => %{invalid: "structure"},
        "status" => :atom,
        "category" => 123,
        "priority" => %{nested: "object"},
        "tags" => "not-an-array",
        "author" => false
      }
      
      file_path = "build/strategy_security_architecture_analysis.md"
      
      resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
      
      # All invalid YAML should be replaced with inferences
      assert resolved["title"] == "Security Architecture Analysis"
      assert resolved["group"] == "strategy"
      assert resolved["sub_group"] in ["security", "architecture"]
      assert resolved["category"] in ["security", "architecture", "analysis"]
      assert resolved["priority"] in ["high", "medium", "low"]
      assert resolved["status"] in ["live", "archived"]
      assert is_list(resolved["tags"])
      assert "strategy" in resolved["tags"]
    end

    test "preserves valid YAML while replacing invalid fields with inferences" do
      # Mix of valid and invalid YAML
      yaml_metadata = %{
        "title" => "Valid YAML Title", # valid - keep
        "author" => "Claude", # valid - keep
        "group" => "custom_group", # valid - keep
        "sub_group" => nil, # invalid - infer
        "status" => "invalid_status", # invalid - normalize/infer
        "category" => "", # invalid - infer
        "priority" => 999, # invalid - normalize/infer  
        "tags" => ["valid", nil, "tags"] # partially valid - filter and merge
      }
      
      file_path = "build/todo_high_priority_security_implementation.md"
      
      resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
      
      # Valid YAML preserved
      assert resolved["title"] == "Valid YAML Title"
      assert resolved["author"] == "Claude"
      assert resolved["group"] == "custom_group"
      
      # Invalid YAML replaced with inferences
      assert resolved["sub_group"] == "security" # inferred
      assert resolved["status"] == "live" # normalized
      assert resolved["category"] == "security" # inferred
      assert resolved["priority"] == "high" # inferred from "high_priority"
      
      # Tags filtered and merged
      tags = resolved["tags"]
      assert "valid" in tags
      assert "tags" in tags
      refute nil in tags
      assert "security" in tags # inferred
      assert "implementation" in tags # inferred
    end
  end

  describe "edge_cases_and_error_handling/2" do
    test "handles empty file paths gracefully" do
      yaml_metadata = %{"title" => "Test"}
      
      edge_cases = ["", nil, "   ", "/", "build/", "build/.md"]
      
      for file_path <- edge_cases do
        resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
        
        # Should not crash and should provide defaults
        assert resolved["group"] == "other"
        assert is_binary(resolved["title"])
        assert is_list(resolved["tags"])
      end
    end

    test "handles extremely long filenames" do
      # Very long filename with many underscores
      long_filename = String.duplicate("very_long_", 50) <> "filename.md"
      file_path = "build/" <> long_filename
      
      yaml_metadata = %{}
      
      resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
      
      # Should handle without performance issues
      assert resolved["group"] == "very"
      assert is_binary(resolved["title"])
      assert length(resolved["title"]) < 200 # reasonable title length
    end

    test "handles special characters in filenames" do
      special_filenames = [
        "build/done_file-with-dashes.md",
        "build/strategy_file.with.dots.md",
        "build/todo_file with spaces.md",
        "build/meeting_file(with)parens.md",
        "build/spec_file[with]brackets.md"
      ]
      
      for file_path <- special_filenames do
        yaml_metadata = %{}
        resolved = MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
        
        # Should handle special characters gracefully
        assert is_binary(resolved["group"])
        assert is_binary(resolved["title"])
        assert is_list(resolved["tags"])
      end
    end

    test "handles concurrent access to fallback resolution" do
      # Test thread safety of fallback resolution
      yaml_metadata = %{"group" => "concurrent"}
      file_path = "build/done_concurrent_test.md"
      
      # Run multiple concurrent resolutions
      tasks = for _i <- 1..10 do
        Task.async(fn ->
          MarkdownProcessor.hybrid_metadata_resolution(yaml_metadata, file_path)
        end)
      end
      
      results = Task.await_many(tasks)
      
      # All results should be identical (thread safe)
      first_result = List.first(results)
      assert Enum.all?(results, & &1 == first_result)
      
      # And should be correct
      assert first_result["group"] == "concurrent"
      assert first_result["title"] == "Concurrent Test"
    end
  end
end