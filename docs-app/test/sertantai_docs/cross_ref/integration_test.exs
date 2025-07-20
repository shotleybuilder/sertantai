defmodule SertantaiDocs.CrossRef.IntegrationTest do
  use ExUnit.Case, async: true
  use SertantaiDocsWeb.ConnCase

  alias SertantaiDocs.CrossRef
  alias SertantaiDocs.MarkdownProcessor

  describe "complete cross-reference workflow" do
    test "processes document with all cross-reference types end-to-end" do
      markdown = """
      # Cross-Reference Integration Test
      
      This document tests all cross-reference types:
      
      ## Ash Resources
      User management is handled by [User Resource](ash:Sertantai.Accounts.User).
      
      ## ExDoc Links
      For collections, see [Enum Module](exdoc:Enum) documentation.
      Custom modules like [Scanner](exdoc:SertantaiDocs.Navigation.Scanner) are also linked.
      
      ## Internal Documentation
      Follow the [Setup Guide](dev:setup-guide) to get started.
      Check the [User Manual](user:getting-started) for basics.
      
      ## Mixed Content
      Compare [User Resource](ash:Sertantai.Accounts.User) with 
      [Enum Module](exdoc:Enum) and read [Setup Guide](dev:setup-guide).
      """
      
      options = %{
        validate_cross_refs: true,
        generate_previews: true,
        enable_hover_tooltips: true
      }
      
      result = CrossRef.process_document(markdown, options)
      
      # Should successfully process all cross-reference types
      assert result.success == true
      assert length(result.cross_refs) == 6
      
      # Check individual cross-reference types
      ash_refs = Enum.filter(result.cross_refs, &(&1.type == :ash))
      exdoc_refs = Enum.filter(result.cross_refs, &(&1.type == :exdoc))
      internal_refs = Enum.filter(result.cross_refs, &(&1.type in [:dev, :user]))
      
      assert length(ash_refs) == 2
      assert length(exdoc_refs) == 2
      assert length(internal_refs) == 2
      
      # All valid references should be processed correctly
      valid_refs = Enum.filter(result.cross_refs, &(&1.valid == true))
      assert length(valid_refs) >= 4  # Most should be valid
      
      # HTML should contain processed cross-reference links
      assert result.html =~ ~s(class="cross-ref cross-ref-ash")
      assert result.html =~ ~s(class="cross-ref cross-ref-exdoc")
      assert result.html =~ ~s(class="cross-ref cross-ref-internal")
      assert result.html =~ ~s(data-preview-enabled="true")
      
      # Validation report should be included
      assert result.validation_report != nil
      assert result.validation_report.total_count == 6
    end

    test "handles broken cross-references gracefully in full workflow" do
      markdown = """
      # Document with Broken Links
      
      Valid: [User Resource](ash:Sertantai.Accounts.User)
      Broken: [Missing Resource](ash:Missing.Resource)
      Invalid: [Bad Link](invalid:format)
      """
      
      options = %{
        validate_cross_refs: true,
        fail_on_broken_links: false,
        generate_error_reports: true
      }
      
      result = CrossRef.process_document(markdown, options)
      
      assert result.success == true  # Should not fail with broken links
      assert length(result.cross_refs) == 2  # Should ignore invalid format
      
      valid_ref = Enum.find(result.cross_refs, &(&1.target == "Sertantai.Accounts.User"))
      broken_ref = Enum.find(result.cross_refs, &(&1.target == "Missing.Resource"))
      
      assert valid_ref.valid == true
      assert broken_ref.valid == false
      assert broken_ref.error != nil
      
      # HTML should mark broken links appropriately
      assert result.html =~ ~s(class="cross-ref cross-ref-ash")
      assert result.html =~ ~s(class="cross-ref cross-ref-ash cross-ref-broken")
      
      # Error report should be generated
      assert result.error_report != nil
      assert result.error_report.broken_links == 1
    end

    test "integrates with MarkdownProcessor seamlessly" do
      markdown = """
      # Markdown + Cross-References
      
      Regular **bold** text and `code` blocks work fine.
      
      ```elixir
      # This [fake link](ash:Should.Not.Process) should be ignored
      def example, do: :ok
      ```
      
      But this [User Resource](ash:Sertantai.Accounts.User) should be processed.
      
      > **Note**: See [Enum](exdoc:Enum) for details.
      """
      
      # Process through MarkdownProcessor with cross-ref integration
      result = MarkdownProcessor.process_with_cross_refs(markdown, %{})
      
      # Should have all MDEx features plus cross-references
      assert result.html =~ ~s(<strong data-sourcepos=)  # MDEx formatting
      assert result.html =~ ~s(<pre class=)              # Syntax highlighting
      assert result.html =~ ~s(class="cross-ref")        # Cross-references
      
      # Cross-references in code blocks should be ignored
      refute result.html =~ ~s(href="/api/ash/Should.Not.Process")
      
      # But regular cross-references should work
      assert result.html =~ ~s(href="/api/ash/Sertantai.Accounts.User")
      assert result.html =~ ~s(href="/api/docs/Enum.html")
      
      # Should include both TOC and cross-references
      assert result.toc != nil
      assert result.cross_refs != nil
    end

    test "generates comprehensive preview data for all link types" do
      markdown = """
      Links: [User](ash:Sertantai.Accounts.User), [Enum](exdoc:Enum), [Setup](dev:setup-guide)
      """
      
      options = %{
        generate_previews: true,
        cache_previews: true,
        include_examples: true
      }
      
      result = CrossRef.process_document(markdown, options)
      
      # All cross-references should have preview data
      for cross_ref <- result.cross_refs do
        if cross_ref.valid do
          assert cross_ref.preview_data != nil
          
          case cross_ref.type do
            :ash ->
              assert cross_ref.preview_data.resource_type != nil
              assert cross_ref.preview_data.actions != nil
              
            :exdoc ->
              assert cross_ref.preview_data.module_type != nil
              assert cross_ref.preview_data.functions != nil
              
            type when type in [:dev, :user] ->
              assert cross_ref.preview_data.title != nil
              assert cross_ref.preview_data.category != nil
          end
        end
      end
      
      # HTML should include preview data attributes
      assert result.html =~ ~s(data-preview-data=)
      assert result.html =~ ~s(data-preview-type=)
    end

    test "validates all cross-references with detailed reporting" do
      markdown = """
      # Validation Test
      
      Valid: [User](ash:Sertantai.Accounts.User)
      Valid: [Enum](exdoc:Enum)  
      Valid: [Setup](dev:setup-guide)
      Broken: [Missing](ash:Missing.Resource)
      Broken: [NotFound](dev:not-found)
      """
      
      options = %{
        validate_cross_refs: true,
        detailed_validation: true,
        check_anchors: true,
        suggest_fixes: true
      }
      
      result = CrossRef.process_document(markdown, options)
      
      assert result.validation_report.total_count == 5
      assert result.validation_report.valid_count == 3
      assert result.validation_report.invalid_count == 2
      
      # Should provide suggestions for broken links
      broken_refs = Enum.filter(result.cross_refs, &(&1.valid == false))
      for broken_ref <- broken_refs do
        assert broken_ref.suggestions != nil
        assert is_list(broken_ref.suggestions)
      end
      
      # Validation report should include fix suggestions
      assert result.validation_report.fix_suggestions != []
      assert result.validation_report.similar_references != []
    end

    test "handles concurrent processing of multiple documents" do
      documents = for i <- 1..10 do
        """
        # Document #{i}
        
        See [User Resource](ash:Sertantai.Accounts.User) and [Enum](exdoc:Enum).
        Check [Setup Guide](dev:setup-guide) for details.
        """
      end
      
      options = %{
        concurrent: true,
        max_workers: 4,
        timeout: 5000
      }
      
      {time, results} = :timer.tc(fn ->
        CrossRef.process_documents(documents, options)
      end)
      
      assert length(results) == 10
      assert time < 10_000  # Should complete reasonably fast
      
      # All documents should be processed successfully
      for result <- results do
        assert result.success == true
        assert length(result.cross_refs) == 3
      end
      
      # Should respect concurrency limits
      assert results |> hd() |> Map.get(:processing_info) |> Map.get(:concurrent) == true
    end

    test "integrates with live preview updates" do
      markdown = """
      # Live Preview Test
      
      This [User Resource](ash:Sertantai.Accounts.User) has live preview.
      """
      
      {:ok, view, _html} = live(build_conn(), "/test-cross-ref-preview")
      
      # Send markdown to LiveView for processing
      send(view.pid, {:update_document, markdown})
      
      html = render(view)
      
      # Should render cross-reference with preview attributes
      assert html =~ ~s(class="cross-ref cross-ref-ash")
      assert html =~ ~s(data-preview-enabled="true")
      assert html =~ ~s(data-ref-target="Sertantai.Accounts.User")
      
      # Simulate hover to load preview
      view
      |> element("[data-ref-target='Sertantai.Accounts.User']")
      |> render_hook("load_preview", %{target: "Sertantai.Accounts.User", type: "ash"})
      
      # Should receive preview data
      assert_receive {:preview_loaded, "Sertantai.Accounts.User", _preview_data}, 1000
    end

    test "exports cross-reference data for external tools" do
      markdown = """
      # Export Test
      
      Multiple references: [User](ash:Sertantai.Accounts.User), 
      [Enum](exdoc:Enum), [Setup](dev:setup-guide).
      """
      
      result = CrossRef.process_document(markdown, %{export_data: true})
      
      # Should export structured data
      export_data = result.export_data
      
      assert export_data.document_title == "Export Test"
      assert length(export_data.cross_references) == 3
      assert export_data.cross_reference_types == [:ash, :exdoc, :dev]
      assert export_data.validation_summary != nil
      
      # Export should be in multiple formats
      assert export_data.formats.json != nil
      assert export_data.formats.yaml != nil
      assert export_data.formats.csv != nil
      
      # JSON export should be valid
      json_data = Jason.decode!(export_data.formats.json)
      assert json_data["cross_references"] |> length() == 3
    end

    test "handles edge cases and error conditions gracefully" do
      test_cases = [
        {"", %{}},  # Empty document
        {"# No Cross-Refs\n\nJust regular content.", %{}},  # No cross-references
        {"[Malformed](ash:)", %{}},  # Malformed syntax
        {"[Circular](dev:circular) -> [Circular](dev:circular)", %{}},  # Circular references
        {String.duplicate("# Section\n[Link](ash:Test.Resource)\n", 1000), %{}}  # Very large document
      ]
      
      for {markdown, options} <- test_cases do
        result = CrossRef.process_document(markdown, options)
        
        # Should never crash, always return a result
        assert result != nil
        assert Map.has_key?(result, :success)
        assert Map.has_key?(result, :cross_refs)
        assert Map.has_key?(result, :html)
      end
    end
  end

  describe "cross-reference system configuration" do
    test "respects global configuration settings" do
      # Configure cross-reference system
      config = %{
        ash_base_url: "/custom/ash",
        exdoc_base_url: "/custom/docs",
        internal_base_url: "/custom/internal",
        enable_validation: true,
        enable_previews: true,
        cache_ttl: 3600
      }
      
      CrossRef.configure(config)
      
      markdown = """
      Links: [User](ash:Test.Resource), [Module](exdoc:Test.Module), [Doc](dev:test-doc)
      """
      
      result = CrossRef.process_document(markdown, %{})
      
      # Should use configured URLs
      ash_ref = Enum.find(result.cross_refs, &(&1.type == :ash))
      exdoc_ref = Enum.find(result.cross_refs, &(&1.type == :exdoc))
      dev_ref = Enum.find(result.cross_refs, &(&1.type == :dev))
      
      assert ash_ref.url =~ "/custom/ash"
      assert exdoc_ref.url =~ "/custom/docs"
      assert dev_ref.url =~ "/custom/internal"
    end

    test "allows per-document configuration overrides" do
      markdown = "[User](ash:Test.Resource)"
      
      document_options = %{
        ash_base_url: "/override/ash",
        force_validation: false
      }
      
      result = CrossRef.process_document(markdown, document_options)
      
      ref = result.cross_refs |> hd()
      assert ref.url =~ "/override/ash"
      assert ref.validation_forced == false
    end

    test "provides configuration validation and warnings" do
      invalid_config = %{
        ash_base_url: "invalid-url",
        cache_ttl: -1,
        unknown_option: true
      }
      
      result = CrossRef.validate_configuration(invalid_config)
      
      assert result.valid == false
      assert length(result.errors) >= 2
      assert "Invalid ash_base_url" in result.errors
      assert "Invalid cache_ttl" in result.errors
      assert length(result.warnings) >= 1
      assert "Unknown option: unknown_option" in result.warnings
    end
  end

  describe "performance and caching" do
    test "caches cross-reference processing results effectively" do
      markdown = """
      # Cache Test
      
      Links: [User](ash:Sertantai.Accounts.User), [Enum](exdoc:Enum)
      """
      
      options = %{cache: true, cache_key: "test-doc-1"}
      
      # First processing - should be slow
      {time1, result1} = :timer.tc(fn ->
        CrossRef.process_document(markdown, options)
      end)
      
      # Second processing - should use cache and be faster
      {time2, result2} = :timer.tc(fn ->
        CrossRef.process_document(markdown, options)
      end)
      
      assert result1.cross_refs == result2.cross_refs
      assert result2.cache_hit == true
      assert time2 < time1 / 2  # Should be significantly faster
    end

    test "handles cache invalidation properly" do
      markdown = """
      [User](ash:Sertantai.Accounts.User)
      """
      
      # Process with cache
      result1 = CrossRef.process_document(markdown, %{cache: true, cache_key: "invalidation-test"})
      assert result1.cache_hit == false
      
      # Process again - should hit cache
      result2 = CrossRef.process_document(markdown, %{cache: true, cache_key: "invalidation-test"})
      assert result2.cache_hit == true
      
      # Invalidate cache
      CrossRef.invalidate_cache("invalidation-test")
      
      # Process again - should miss cache
      result3 = CrossRef.process_document(markdown, %{cache: true, cache_key: "invalidation-test"})
      assert result3.cache_hit == false
    end

    test "processes large documents efficiently" do
      # Generate large document with many cross-references
      sections = for i <- 1..100 do
        """
        ## Section #{i}
        
        Content with [User #{i}](ash:Sertantai.Test.User#{i}) and 
        [Module #{i}](exdoc:Test.Module#{i}) references.
        """
      end
      
      large_markdown = "# Large Document\n\n" <> Enum.join(sections, "\n")
      
      {time, result} = :timer.tc(fn ->
        CrossRef.process_document(large_markdown, %{})
      end)
      
      assert length(result.cross_refs) == 200
      assert time < 30_000  # Should complete in reasonable time (30s)
      assert result.performance_metrics.processing_time != nil
      assert result.performance_metrics.cross_refs_per_second > 5
    end
  end
end