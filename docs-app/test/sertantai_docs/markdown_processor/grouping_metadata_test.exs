defmodule SertantaiDocs.MarkdownProcessor.GroupingMetadataTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.MarkdownProcessor

  @moduledoc """
  TDD tests focused on metadata extraction and processing for the grouping system.
  
  Tests comprehensive YAML frontmatter parsing including:
  - All required properties (title, author, group, sub_group, status, category, priority, tags)
  - Validation and type checking
  - Fallback behaviors for missing or invalid properties
  - Integration with file processing pipeline
  """

  describe "extract_frontmatter/1" do
    test "extracts complete YAML frontmatter with all grouping properties" do
      content = """
      ---
      title: "Complete Test Document"
      author: "Claude"
      group: "done" 
      sub_group: "phases"
      status: "live"
      category: "implementation"
      priority: "high"
      tags: ["phase-1", "ash", "implementation", "completed"]
      last_modified: "2025-01-21"
      description: "Test document with all properties"
      ---
      # Document Content
      
      This is the main content.
      """

      {frontmatter, markdown_body} = MarkdownProcessor.extract_frontmatter(content)
      
      assert frontmatter["title"] == "Complete Test Document"
      assert frontmatter["author"] == "Claude"
      assert frontmatter["group"] == "done"
      assert frontmatter["sub_group"] == "phases"
      assert frontmatter["status"] == "live"
      assert frontmatter["category"] == "implementation"
      assert frontmatter["priority"] == "high"
      assert frontmatter["tags"] == ["phase-1", "ash", "implementation", "completed"]
      assert frontmatter["last_modified"] == "2025-01-21"
      assert frontmatter["description"] == "Test document with all properties"
      
      assert String.starts_with?(markdown_body, "# Document Content")
    end

    test "handles minimal frontmatter with only required fields" do
      content = """
      ---
      title: "Minimal Document"
      ---
      # Content only
      """

      {frontmatter, markdown_body} = MarkdownProcessor.extract_frontmatter(content)
      
      assert frontmatter["title"] == "Minimal Document"
      assert frontmatter["author"] == nil
      assert frontmatter["group"] == nil
      assert frontmatter["sub_group"] == nil
      assert frontmatter["status"] == nil
      assert frontmatter["category"] == nil
      assert frontmatter["priority"] == nil
      assert frontmatter["tags"] == nil
      
      assert String.starts_with?(markdown_body, "# Content only")
    end

    test "handles content without frontmatter" do
      content = """
      # Just Regular Markdown
      
      No YAML frontmatter here.
      """

      {frontmatter, markdown_body} = MarkdownProcessor.extract_frontmatter(content)
      
      assert frontmatter == %{}
      assert markdown_body == content
    end

    test "handles malformed YAML gracefully" do
      content = """
      ---
      title: "Good Title"
      invalid: yaml: structure: here
      group: [this, should, be, string]  
      priority: not_a_valid_priority
      tags: "should be array"
      ---
      # Content
      """

      {frontmatter, markdown_body} = MarkdownProcessor.extract_frontmatter(content)
      
      # Should extract what it can and ignore malformed parts
      assert frontmatter["title"] == "Good Title"
      assert String.starts_with?(markdown_body, "# Content")
      # Malformed fields may be nil or parsed incorrectly, but shouldn't crash
    end
  end

  describe "validate_metadata/1" do  
    test "validates and normalizes valid metadata" do
      metadata = %{
        "title" => "Test Document",
        "author" => "Claude",
        "group" => "done",
        "sub_group" => "phases", 
        "status" => "live",
        "category" => "implementation",
        "priority" => "high",
        "tags" => ["test", "validation"]
      }

      validated = MarkdownProcessor.validate_metadata(metadata)
      
      assert validated["title"] == "Test Document"
      assert validated["author"] == "Claude" 
      assert validated["group"] == "done"
      assert validated["sub_group"] == "phases"
      assert validated["status"] == "live"
      assert validated["category"] == "implementation"
      assert validated["priority"] == "high"
      assert validated["tags"] == ["test", "validation"]
    end

    test "normalizes priority values to valid options" do
      test_cases = [
        {"high", "high"},
        {"HIGH", "high"},
        {"medium", "medium"},
        {"med", "medium"},
        {"low", "low"},
        {"invalid", "medium"}, # default fallback
        {nil, "medium"}, # default fallback
        {123, "medium"} # invalid type fallback
      ]

      for {input, expected} <- test_cases do
        metadata = %{"priority" => input}
        validated = MarkdownProcessor.validate_metadata(metadata)
        assert validated["priority"] == expected
      end
    end

    test "normalizes status values to valid options" do
      test_cases = [
        {"live", "live"},
        {"LIVE", "live"},
        {"archived", "archived"},
        {"archive", "archived"},
        {"inactive", "archived"},
        {"invalid", "live"}, # default fallback
        {nil, "live"}, # default fallback
        {[], "live"} # invalid type fallback
      ]

      for {input, expected} <- test_cases do
        metadata = %{"status" => input}
        validated = MarkdownProcessor.validate_metadata(metadata)
        assert validated["status"] == expected
      end
    end

    test "normalizes and validates tags array" do
      test_cases = [
        {["valid", "tags"], ["valid", "tags"]},
        {"single-tag", ["single-tag"]}, # string to array
        {["mixed", 123, "types"], ["mixed", "types"]}, # filter non-strings
        {[], []},
        {nil, []},
        {"", []} # empty string to empty array
      ]

      for {input, expected} <- test_cases do
        metadata = %{"tags" => input}
        validated = MarkdownProcessor.validate_metadata(metadata)
        assert validated["tags"] == expected
      end
    end

    test "validates group field as string" do
      test_cases = [
        {"done", "done"},
        {"custom-group", "custom-group"},
        {123, nil}, # invalid type
        {[], nil}, # invalid type
        {"", nil}, # empty string
        {nil, nil} # explicit nil
      ]

      for {input, expected} <- test_cases do
        metadata = %{"group" => input}
        validated = MarkdownProcessor.validate_metadata(metadata)
        assert validated["group"] == expected
      end
    end

    test "validates sub_group field as string" do
      test_cases = [
        {"phases", "phases"},
        {"admin-interface", "admin-interface"},
        {nil, nil},
        {"", nil}, # empty string to nil
        {123, nil}, # invalid type
        {["array"], nil} # invalid type
      ]

      for {input, expected} <- test_cases do
        metadata = %{"sub_group" => input}
        validated = MarkdownProcessor.validate_metadata(metadata)
        assert validated["sub_group"] == expected
      end
    end
  end

  describe "infer_metadata_from_filename/1" do
    test "infers group from filename prefix" do
      test_cases = [
        {"done_phase_1_summary.md", "done"},
        {"strategy_security_audit.md", "strategy"},
        {"todo_implementation_plan.md", "todo"},
        {"meeting_notes_2025.md", "meeting"},
        {"spec_api_design.md", "spec"}
      ]

      for {filename, expected_group} <- test_cases do
        inferred = MarkdownProcessor.infer_metadata_from_filename(filename)
        assert inferred["group"] == expected_group
      end
    end

    test "infers category from filename content" do
      test_cases = [
        {"done_security_audit.md", "security"},
        {"strategy_admin_interface.md", "admin"},
        {"todo_documentation_plan.md", "docs"},
        {"done_phase_1_implementation.md", "implementation"},
        {"strategy_architecture_analysis.md", "analysis"},
        {"todo_test_execution_plan.md", "testing"},
        {"done_general_plan.md", "general"} # fallback
      ]

      for {filename, expected_category} <- test_cases do
        inferred = MarkdownProcessor.infer_metadata_from_filename(filename)
        assert inferred["category"] == expected_category
      end
    end

    test "infers sub_group from filename content" do
      test_cases = [
        {"done_phase_1_summary.md", "phases"},
        {"done_custom_admin_interface.md", "admin"},
        {"strategy_security_audit.md", "security"},
        {"todo_documentation_system.md", "docs"},
        {"done_action_plan_part1.md", "planning"},
        {"strategy_test_execution.md", "testing"},
        {"done_applicability_analysis.md", "applicability"}
      ]

      for {filename, expected_sub_group} <- test_cases do
        inferred = MarkdownProcessor.infer_metadata_from_filename(filename)
        assert inferred["sub_group"] == expected_sub_group
      end
    end

    test "infers tags from filename keywords" do
      filename = "done_phase_1_ash_admin_implementation.md"
      inferred = MarkdownProcessor.infer_metadata_from_filename(filename)
      
      expected_tags = ["done", "phases", "ash", "admin", "implementation"]
      assert Enum.all?(expected_tags, & &1 in inferred["tags"])
    end

    test "generates title from filename" do
      test_cases = [
        {"done_phase_1_implementation_summary.md", "Phase 1 Implementation Summary"},
        {"strategy_security_audit_report.md", "Security Audit Report"}, 
        {"todo_custom_admin_plan_phase_5.md", "Custom Admin Plan Phase 5"},
        {"meeting_weekly_standup_notes.md", "Weekly Standup Notes"}
      ]

      for {filename, expected_title} <- test_cases do
        inferred = MarkdownProcessor.infer_metadata_from_filename(filename)
        assert inferred["title"] == expected_title
      end
    end

    test "handles edge cases in filename inference" do
      edge_cases = [
        {"_leading_underscore.md", "other"}, # invalid prefix
        {"trailing_.md", "trailing"}, # trailing underscore ok
        {"no-underscores.md", "other"}, # no prefix
        {"UPPERCASE_FILE.MD", "uppercase"} # case handling
      ]

      for {filename, expected_group} <- edge_cases do
        inferred = MarkdownProcessor.infer_metadata_from_filename(filename)
        assert inferred["group"] == expected_group
      end
    end
  end

  describe "merge_metadata/2" do
    test "merges YAML frontmatter with inferred metadata, prioritizing YAML" do
      yaml_metadata = %{
        "title" => "YAML Title",
        "group" => "yaml_group", 
        "status" => "archived"
      }

      inferred_metadata = %{
        "title" => "Inferred Title", # should be overridden
        "group" => "inferred_group", # should be overridden
        "sub_group" => "inferred_sub", # should be kept
        "category" => "inferred_category", # should be kept
        "tags" => ["inferred", "tags"] # should be kept
      }

      merged = MarkdownProcessor.merge_metadata(yaml_metadata, inferred_metadata)
      
      # YAML takes precedence
      assert merged["title"] == "YAML Title"
      assert merged["group"] == "yaml_group"
      assert merged["status"] == "archived"
      
      # Inferred fills gaps
      assert merged["sub_group"] == "inferred_sub"
      assert merged["category"] == "inferred_category"  
      assert merged["tags"] == ["inferred", "tags"]
    end

    test "uses inferred metadata when YAML is missing or nil" do
      yaml_metadata = %{
        "title" => "YAML Title",
        "group" => nil, # explicit nil - should use inferred
        "status" => ""  # empty string - should use inferred
      }

      inferred_metadata = %{
        "group" => "inferred_group",
        "status" => "live",
        "category" => "implementation"
      }

      merged = MarkdownProcessor.merge_metadata(yaml_metadata, inferred_metadata)
      
      assert merged["title"] == "YAML Title" # YAML value kept
      assert merged["group"] == "inferred_group" # inferred used for nil YAML
      assert merged["status"] == "live" # inferred used for empty YAML
      assert merged["category"] == "implementation" # inferred used for missing YAML
    end
  end

  describe "process_file_metadata/1" do
    test "processes complete file metadata pipeline" do
      # Simulate a file with both YAML frontmatter and inferrable filename
      file_path = "build/done_phase_1_security_implementation.md"
      content = """
      ---
      title: "Phase 1 Security Implementation" 
      author: "Claude"
      status: "live"
      priority: "high"
      tags: ["security", "phase-1"]
      ---
      # Phase 1 Security Implementation
      
      Implementation details...
      """

      # Process through complete pipeline
      {:ok, _html, processed_metadata} = MarkdownProcessor.process_content(content)
      
      # Should have YAML metadata
      assert processed_metadata["title"] == "Phase 1 Security Implementation"
      assert processed_metadata["author"] == "Claude"
      assert processed_metadata["status"] == "live"
      assert processed_metadata["priority"] == "high"
      assert processed_metadata["tags"] == ["security", "phase-1"]
      
      # When integrated with filename processing, should also infer:
      filename_inferred = MarkdownProcessor.infer_metadata_from_filename(file_path)
      merged = MarkdownProcessor.merge_metadata(processed_metadata, filename_inferred)
      
      # Should have both YAML and inferred data
      assert merged["title"] == "Phase 1 Security Implementation" # YAML priority
      assert merged["group"] == "done" # inferred from filename
      assert merged["sub_group"] == "security" # inferred from filename
      assert merged["category"] == "security" # inferred from filename
    end

    test "handles file with no frontmatter using only inference" do
      file_path = "build/strategy_architecture_analysis.md"
      content = """
      # Architecture Analysis
      
      This document analyzes the current architecture.
      """

      # Process content (no frontmatter)
      {:ok, _html, processed_metadata} = MarkdownProcessor.process_content(content)
      assert processed_metadata == %{} # No frontmatter
      
      # Should fall back to filename inference
      inferred = MarkdownProcessor.infer_metadata_from_filename(file_path)
      
      assert inferred["title"] == "Architecture Analysis"
      assert inferred["group"] == "strategy"
      assert inferred["sub_group"] == "architecture"
      assert inferred["category"] == "analysis"
      assert "strategy" in inferred["tags"]
    end
  end

  describe "metadata caching and performance" do
    test "caches processed metadata for repeated access" do
      file_path = "build/test_caching.md"
      
      # First processing
      start_time = System.monotonic_time()
      metadata1 = MarkdownProcessor.get_cached_metadata(file_path)
      first_duration = System.monotonic_time() - start_time
      
      # Second processing (should be cached)
      start_time = System.monotonic_time()
      metadata2 = MarkdownProcessor.get_cached_metadata(file_path)
      second_duration = System.monotonic_time() - start_time
      
      # Results should be identical
      assert metadata1 == metadata2
      
      # Second call should be significantly faster (cached)
      assert second_duration < first_duration / 2
    end

    test "invalidates cache when file content changes" do
      file_path = "build/test_cache_invalidation.md"
      
      # Mock file modification time changes
      original_metadata = MarkdownProcessor.get_cached_metadata(file_path)
      
      # Simulate file modification
      MarkdownProcessor.invalidate_cache(file_path)
      
      # Should reprocess on next access
      new_metadata = MarkdownProcessor.get_cached_metadata(file_path)
      
      # May be same content but should have fresh timestamp
      refute new_metadata[:cached_at] == original_metadata[:cached_at]
    end
  end
end