defmodule SertantaiDocs.CrossRef.ValidatorTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.CrossRef.Validator

  describe "validate_document/2" do
    test "validates all cross-references in a document" do
      markdown = """
      # Test Document
      
      Check [User Resource](ash:Sertantai.Accounts.User) and 
      [Setup Guide](dev:setup-guide) for details.
      
      Also see [API Docs](exdoc:Sertantai.API) and
      [Missing Resource](ash:Missing.Resource).
      """
      
      result = Validator.validate_document(markdown, %{})
      
      assert length(result.cross_refs) == 4
      assert result.total_count == 4
      assert result.valid_count == 3
      assert result.invalid_count == 1
      assert result.has_errors == true
      
      # Check specific validation results
      invalid_ref = Enum.find(result.cross_refs, &(&1.target == "Missing.Resource"))
      assert invalid_ref.valid == false
      assert invalid_ref.error =~ "not found"
      
      valid_ref = Enum.find(result.cross_refs, &(&1.target == "Sertantai.Accounts.User"))
      assert valid_ref.valid == true
      assert valid_ref.error == nil
    end

    test "returns clean validation for document with no cross-references" do
      markdown = """
      # Regular Document
      
      This has [normal links](https://example.com) but no cross-references.
      """
      
      result = Validator.validate_document(markdown, %{})
      
      assert length(result.cross_refs) == 0
      assert result.total_count == 0
      assert result.valid_count == 0
      assert result.invalid_count == 0
      assert result.has_errors == false
    end

    test "validates ash resource references" do
      markdown = """
      Valid: [User](ash:Sertantai.Accounts.User)
      Invalid: [Missing](ash:Missing.Resource)
      """
      
      result = Validator.validate_document(markdown, %{})
      
      user_ref = Enum.find(result.cross_refs, &(&1.target == "Sertantai.Accounts.User"))
      missing_ref = Enum.find(result.cross_refs, &(&1.target == "Missing.Resource"))
      
      assert user_ref.valid == true
      assert user_ref.exists == true
      assert user_ref.resource_type == "ash_resource"
      
      assert missing_ref.valid == false
      assert missing_ref.exists == false
      assert missing_ref.error == "Ash resource 'Missing.Resource' not found in domain"
    end

    test "validates exdoc module references" do
      markdown = """
      Valid: [Enum](exdoc:Enum)
      Invalid: [Missing](exdoc:Missing.Module)
      """
      
      result = Validator.validate_document(markdown, %{})
      
      enum_ref = Enum.find(result.cross_refs, &(&1.target == "Enum"))
      missing_ref = Enum.find(result.cross_refs, &(&1.target == "Missing.Module"))
      
      assert enum_ref.valid == true
      assert enum_ref.exists == true
      assert enum_ref.module_type == "elixir_module"
      
      assert missing_ref.valid == false
      assert missing_ref.exists == false
      assert missing_ref.error == "Module 'Missing.Module' not found or not documented"
    end

    test "validates internal documentation references" do
      markdown = """
      Valid: [Setup](dev:setup-guide)
      Invalid: [Missing](dev:non-existent)
      """
      
      result = Validator.validate_document(markdown, %{})
      
      setup_ref = Enum.find(result.cross_refs, &(&1.target == "setup-guide"))
      missing_ref = Enum.find(result.cross_refs, &(&1.target == "non-existent"))
      
      assert setup_ref.valid == true
      assert setup_ref.exists == true
      assert setup_ref.file_path =~ "setup-guide"
      
      assert missing_ref.valid == false
      assert missing_ref.exists == false
      assert missing_ref.error == "Documentation file '/dev/non-existent' not found"
    end

    test "provides detailed error context for broken links" do
      markdown = """
      Line 1
      Line 2 has [Broken Link](ash:Broken.Resource)
      Line 3
      """
      
      result = Validator.validate_document(markdown, %{file_path: "/docs/test.md"})
      
      broken_ref = result.cross_refs |> hd()
      assert broken_ref.valid == false
      assert broken_ref.line_number == 2
      assert broken_ref.file_path == "/docs/test.md"
      assert broken_ref.context == "Line 2 has [Broken Link](ash:Broken.Resource)"
    end

    test "handles validation options correctly" do
      markdown = "[Test](ash:Test.Resource)"
      
      options = %{
        skip_ash_validation: true,
        strict_mode: false,
        base_path: "/custom/docs"
      }
      
      result = Validator.validate_document(markdown, options)
      
      # Should skip ash validation when option is set
      ref = result.cross_refs |> hd()
      assert ref.validation_skipped == true
      assert ref.skip_reason == "ash validation disabled"
    end
  end

  describe "validate_cross_reference/2" do
    test "validates ash resource existence" do
      cross_ref = %{
        type: :ash,
        target: "Sertantai.Accounts.User",
        text: "User Resource"
      }
      
      result = Validator.validate_cross_reference(cross_ref, %{})
      
      assert result.valid == true
      assert result.exists == true
      assert result.resource_type == "ash_resource"
      assert result.domain == "Sertantai.Accounts"
      assert result.actions != nil
      assert result.url == "/api/ash/Sertantai.Accounts.User"
    end

    test "detects missing ash resources" do
      cross_ref = %{
        type: :ash,
        target: "NonExistent.Resource",
        text: "Missing Resource"
      }
      
      result = Validator.validate_cross_reference(cross_ref, %{})
      
      assert result.valid == false
      assert result.exists == false
      assert result.error == "Ash resource 'NonExistent.Resource' not found in domain"
      assert result.suggestions != nil
      assert is_list(result.suggestions)
    end

    test "validates elixir module existence for exdoc links" do
      cross_ref = %{
        type: :exdoc,
        target: "Enum",
        text: "Enum Module"
      }
      
      result = Validator.validate_cross_reference(cross_ref, %{})
      
      assert result.valid == true
      assert result.exists == true
      assert result.module_type == "elixir_module"
      assert result.documented == true
      assert result.url == "/api/docs/Enum.html"
    end

    test "validates custom module existence for exdoc links" do
      cross_ref = %{
        type: :exdoc,
        target: "SertantaiDocs.Navigation.Scanner",
        text: "Scanner Module"
      }
      
      result = Validator.validate_cross_reference(cross_ref, %{})
      
      assert result.valid == true
      assert result.exists == true
      assert result.module_type == "custom_module"
      assert result.functions != nil
    end

    test "validates internal documentation file existence" do
      cross_ref = %{
        type: :dev,
        target: "setup-guide",
        text: "Setup Guide"
      }
      
      result = Validator.validate_cross_reference(cross_ref, %{})
      
      assert result.valid == true
      assert result.exists == true
      assert result.file_path =~ "setup-guide"
      assert result.file_type == "markdown"
      assert result.url == "/dev/setup-guide"
    end

    test "detects missing internal documentation files" do
      cross_ref = %{
        type: :dev,
        target: "non-existent-guide",
        text: "Missing Guide"
      }
      
      result = Validator.validate_cross_reference(cross_ref, %{})
      
      assert result.valid == false
      assert result.exists == false
      assert result.error == "Documentation file '/dev/non-existent-guide' not found"
      assert result.checked_paths != nil
      assert is_list(result.checked_paths)
    end

    test "provides suggestions for similar existing references" do
      cross_ref = %{
        type: :ash,
        target: "Sertantai.Account.User",  # Missing 's' in Accounts
        text: "User Resource"
      }
      
      result = Validator.validate_cross_reference(cross_ref, %{})
      
      assert result.valid == false
      assert result.suggestions != nil
      assert "Sertantai.Accounts.User" in result.suggestions
    end

    test "validates with custom validation rules" do
      cross_ref = %{
        type: :ash,
        target: "Sertantai.Accounts.User",
        text: "User Resource"
      }
      
      options = %{
        custom_validators: [
          fn ref -> 
            if String.contains?(ref.target, "User") do
              %{valid: true, custom_check: "user_resource_approved"}
            else
              %{valid: false, error: "Only User resources allowed"}
            end
          end
        ]
      }
      
      result = Validator.validate_cross_reference(cross_ref, options)
      
      assert result.custom_check == "user_resource_approved"
    end
  end

  describe "batch_validate/2" do
    test "validates multiple cross-references efficiently" do
      cross_refs = [
        %{type: :ash, target: "Sertantai.Accounts.User", text: "User"},
        %{type: :dev, target: "setup-guide", text: "Setup"},
        %{type: :exdoc, target: "Enum", text: "Enum"},
        %{type: :ash, target: "Missing.Resource", text: "Missing"}
      ]
      
      result = Validator.batch_validate(cross_refs, %{})
      
      assert length(result.results) == 4
      assert result.total_count == 4
      assert result.valid_count == 3
      assert result.invalid_count == 1
      assert result.processing_time != nil
      
      # Should return results in same order as input
      assert Enum.at(result.results, 0).target == "Sertantai.Accounts.User"
      assert Enum.at(result.results, 3).target == "Missing.Resource"
    end

    test "handles concurrent validation correctly" do
      # Create many cross-references to test concurrency
      cross_refs = for i <- 1..50 do
        %{
          type: :dev,
          target: "test-#{i}",
          text: "Test #{i}"
        }
      end
      
      result = Validator.batch_validate(cross_refs, %{concurrent: true})
      
      assert length(result.results) == 50
      assert result.concurrent == true
      assert result.processing_time < 5000  # Should be faster with concurrency
    end

    test "respects validation timeouts" do
      cross_refs = [
        %{type: :ash, target: "Sertantai.Accounts.User", text: "User"}
      ]
      
      options = %{timeout: 100}  # 100ms timeout
      
      result = Validator.batch_validate(cross_refs, options)
      
      # Should complete within timeout for simple validation
      assert result.timed_out == false
      assert result.processing_time < 100
    end
  end

  describe "generate_validation_report/2" do
    test "generates comprehensive validation report" do
      validation_results = [
        %{valid: true, type: :ash, target: "User.Resource", url: "/api/ash/User.Resource"},
        %{valid: false, type: :dev, target: "missing", error: "File not found", line_number: 5},
        %{valid: true, type: :exdoc, target: "Enum", url: "/api/docs/Enum.html"}
      ]
      
      report = Validator.generate_validation_report(validation_results, %{})
      
      assert report.summary.total == 3
      assert report.summary.valid == 2
      assert report.summary.invalid == 1
      assert report.summary.success_rate == 66.67
      
      assert length(report.errors) == 1
      error = report.errors |> hd()
      assert error.target == "missing"
      assert error.line_number == 5
      assert error.severity == "error"
      
      assert length(report.by_type.ash) == 1
      assert length(report.by_type.dev) == 1
      assert length(report.by_type.exdoc) == 1
    end

    test "includes fix suggestions in report" do
      validation_results = [
        %{
          valid: false, 
          type: :ash, 
          target: "User.Accont",  # Typo
          error: "Resource not found",
          suggestions: ["User.Account", "Sertantai.Accounts.User"]
        }
      ]
      
      report = Validator.generate_validation_report(validation_results, %{})
      
      error = report.errors |> hd()
      assert error.suggestions == ["User.Account", "Sertantai.Accounts.User"]
      assert error.fix_suggestion == "Did you mean 'User.Account'?"
    end

    test "groups errors by type and severity" do
      validation_results = [
        %{valid: false, type: :ash, error: "Critical error", severity: :critical},
        %{valid: false, type: :ash, error: "Warning", severity: :warning},
        %{valid: false, type: :dev, error: "File missing", severity: :error}
      ]
      
      report = Validator.generate_validation_report(validation_results, %{})
      
      assert report.by_severity.critical == 1
      assert report.by_severity.error == 1
      assert report.by_severity.warning == 1
      
      assert length(report.by_type.ash) == 2
      assert length(report.by_type.dev) == 1
    end
  end

  describe "continuous validation" do
    test "sets up file watcher for automatic validation" do
      options = %{
        watch_paths: ["/docs"],
        auto_validate: true,
        validation_interval: 5000
      }
      
      {:ok, watcher_pid} = Validator.start_continuous_validation(options)
      
      assert Process.alive?(watcher_pid)
      assert Validator.is_watching?(watcher_pid)
      
      # Clean up
      Validator.stop_continuous_validation(watcher_pid)
    end

    test "triggers validation on file changes" do
      test_pid = self()
      
      options = %{
        watch_paths: ["/test/docs"],
        on_validation: fn results -> 
          send(test_pid, {:validation_complete, results})
        end
      }
      
      {:ok, watcher_pid} = Validator.start_continuous_validation(options)
      
      # Simulate file change
      Validator.trigger_validation(watcher_pid, "/test/docs/test.md")
      
      assert_receive {:validation_complete, _results}, 1000
      
      Validator.stop_continuous_validation(watcher_pid)
    end
  end

  describe "integration with MarkdownProcessor" do
    test "validates cross-references during markdown processing" do
      markdown = """
      # Test Document
      
      See [User Resource](ash:Sertantai.Accounts.User) for authentication.
      Check [Setup Guide](dev:setup-guide) for installation.
      """
      
      options = %{validate_cross_refs: true}
      
      result = Validator.validate_during_processing(markdown, options)
      
      assert result.html != nil
      assert result.validation_report != nil
      assert result.validation_report.summary.total == 2
      assert result.validation_report.summary.valid == 2
    end

    test "handles validation errors gracefully during processing" do
      markdown = """
      Broken link: [Missing](ash:Missing.Resource)
      """
      
      options = %{
        validate_cross_refs: true,
        fail_on_broken_links: false
      }
      
      result = Validator.validate_during_processing(markdown, options)
      
      # Should still process HTML even with broken links
      assert result.html != nil
      assert result.validation_report.summary.invalid == 1
      assert result.processing_errors == []
    end

    test "fails processing on broken links when strict mode enabled" do
      markdown = """
      Broken link: [Missing](ash:Missing.Resource)
      """
      
      options = %{
        validate_cross_refs: true,
        fail_on_broken_links: true
      }
      
      assert_raise Validator.BrokenLinksError, fn ->
        Validator.validate_during_processing(markdown, options)
      end
    end
  end
end