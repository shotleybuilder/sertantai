defmodule SertantaiDocs.CrossRef.ProcessorTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.CrossRef.Processor

  describe "process_cross_references/2" do
    test "processes ash resource links correctly" do
      markdown = """
      Check out the [User Resource](ash:Sertantai.Accounts.User) for authentication.
      """
      
      result = Processor.process_cross_references(markdown)
      
      assert result.html =~ ~s(<a href="/api/ash/Sertantai.Accounts.User")
      assert result.html =~ ~s(class="cross-ref cross-ref-ash")
      assert result.html =~ ~s(data-ref-type="ash")
      assert result.html =~ ~s(data-ref-target="Sertantai.Accounts.User")
      assert result.html =~ "User Resource"
    end

    test "processes exdoc module links correctly" do
      markdown = """
      See the [User Module](exdoc:Sertantai.Accounts.User) documentation.
      """
      
      result = Processor.process_cross_references(markdown)
      
      assert result.html =~ ~s(<a href="/api/docs/Sertantai.Accounts.User.html")
      assert result.html =~ ~s(class="cross-ref cross-ref-exdoc")
      assert result.html =~ ~s(data-ref-type="exdoc")
      assert result.html =~ ~s(data-ref-target="Sertantai.Accounts.User")
      assert result.html =~ "User Module"
    end

    test "processes internal dev documentation links correctly" do
      markdown = """
      Follow the [Setup Guide](dev:setup-guide) to get started.
      """
      
      result = Processor.process_cross_references(markdown)
      
      assert result.html =~ ~s(<a href="/dev/setup-guide")
      assert result.html =~ ~s(class="cross-ref cross-ref-internal")
      assert result.html =~ ~s(data-ref-type="dev")
      assert result.html =~ ~s(data-ref-target="setup-guide")
      assert result.html =~ "Setup Guide"
    end

    test "processes user guide links correctly" do
      markdown = """
      Read the [Feature Overview](user:features/overview) for details.
      """
      
      result = Processor.process_cross_references(markdown)
      
      assert result.html =~ ~s(<a href="/user/features/overview")
      assert result.html =~ ~s(class="cross-ref cross-ref-internal")
      assert result.html =~ ~s(data-ref-type="user")
      assert result.html =~ ~s(data-ref-target="features/overview")
      assert result.html =~ "Feature Overview"
    end

    test "processes multiple cross-reference types in same document" do
      markdown = """
      # Documentation
      
      Check the [User Resource](ash:Sertantai.Accounts.User) and the 
      [Setup Guide](dev:setup-guide) for more information.
      
      Also see [User Module](exdoc:Sertantai.Accounts.User) docs.
      """
      
      result = Processor.process_cross_references(markdown)
      
      # Should contain all three link types
      assert result.html =~ ~s(class="cross-ref cross-ref-ash")
      assert result.html =~ ~s(class="cross-ref cross-ref-internal")
      assert result.html =~ ~s(class="cross-ref cross-ref-exdoc")
      
      # Should track all processed links
      assert length(result.cross_refs) == 3
      assert Enum.any?(result.cross_refs, &(&1.type == :ash))
      assert Enum.any?(result.cross_refs, &(&1.type == :dev))
      assert Enum.any?(result.cross_refs, &(&1.type == :exdoc))
    end

    test "leaves regular markdown links unchanged" do
      markdown = """
      Check out [Google](https://google.com) and [GitHub](https://github.com).
      """
      
      result = Processor.process_cross_references(markdown)
      
      # Regular links should not be processed as cross-references
      refute result.html =~ ~s(class="cross-ref")
      assert result.html =~ ~s(href="https://google.com")
      assert result.html =~ ~s(href="https://github.com")
      assert length(result.cross_refs) == 0
    end

    test "handles malformed cross-reference syntax gracefully" do
      markdown = """
      Invalid: [Link](ash:) and [Another](invalid:format) and [Normal](ash:Valid.Module).
      """
      
      result = Processor.process_cross_references(markdown)
      
      # Should only process valid cross-reference
      assert length(result.cross_refs) == 1
      assert result.cross_refs |> hd() |> Map.get(:target) == "Valid.Module"
      
      # Invalid ones should become regular HTML links (working with MDEx)
      assert result.html =~ ~s(<a href="ash:">Link</a>)
      assert result.html =~ ~s(<a href="invalid:format">Another</a>)
      
      # Only the valid one should have cross-ref class, not the malformed ones
      assert result.html =~ ~s(class="cross-ref cross-ref-ash")
      valid_links = Regex.scan(~r/class="cross-ref/, result.html)
      assert length(valid_links) == 1
    end

    test "extracts cross-reference metadata correctly" do
      markdown = """
      See [User Resource](ash:Sertantai.Accounts.User) for details.
      """
      
      result = Processor.process_cross_references(markdown)
      
      cross_ref = result.cross_refs |> hd()
      assert cross_ref.type == :ash
      assert cross_ref.target == "Sertantai.Accounts.User"
      assert cross_ref.text == "User Resource"
      assert cross_ref.url == "/api/ash/Sertantai.Accounts.User"
      assert cross_ref.line_number == 1
    end

    test "handles nested cross-references in complex markdown" do
      markdown = """
      ## Section
      
      > **Note**: See [User Resource](ash:Sertantai.Accounts.User) 
      > and follow [Setup Guide](dev:setup-guide).
      
      - Item 1: [API Docs](exdoc:Sertantai.API)
      - Item 2: Normal content
      
      ```elixir
      # This [fake link](ash:Should.Not.Process) should be ignored
      """
      
      result = Processor.process_cross_references(markdown)
      
      # Should process cross-references in quotes and lists but not code blocks
      assert length(result.cross_refs) == 3
      refute Enum.any?(result.cross_refs, &(&1.target == "Should.Not.Process"))
    end
  end

  describe "resolve_link_url/2" do
    test "resolves ash resource URLs correctly" do
      cross_ref = %{type: :ash, target: "Sertantai.Accounts.User"}
      
      url = Processor.resolve_link_url(cross_ref, %{})
      
      assert url == "/api/ash/Sertantai.Accounts.User"
    end

    test "resolves exdoc module URLs correctly" do
      cross_ref = %{type: :exdoc, target: "Sertantai.Accounts.User"}
      
      url = Processor.resolve_link_url(cross_ref, %{})
      
      assert url == "/api/docs/Sertantai.Accounts.User.html"
    end

    test "resolves internal documentation URLs correctly" do
      cross_ref = %{type: :dev, target: "setup-guide"}
      
      url = Processor.resolve_link_url(cross_ref, %{})
      
      assert url == "/dev/setup-guide"
    end

    test "resolves user guide URLs correctly" do
      cross_ref = %{type: :user, target: "features/overview"}
      
      url = Processor.resolve_link_url(cross_ref, %{})
      
      assert url == "/user/features/overview"
    end

    test "uses custom base URLs when provided" do
      cross_ref = %{type: :exdoc, target: "MyModule"}
      options = %{exdoc_base_url: "https://hexdocs.pm/my_app"}
      
      url = Processor.resolve_link_url(cross_ref, options)
      
      assert url == "https://hexdocs.pm/my_app/MyModule.html"
    end
  end

  describe "extract_cross_references/1" do
    test "extracts all cross-reference patterns from markdown" do
      markdown = """
      Multiple refs: [User](ash:User), [Guide](dev:guide), [Docs](exdoc:Module).
      """
      
      refs = Processor.extract_cross_references(markdown)
      
      assert length(refs) == 3
      
      assert Enum.find(refs, &(&1.type == :ash)).target == "User"
      assert Enum.find(refs, &(&1.type == :dev)).target == "guide"
      assert Enum.find(refs, &(&1.type == :exdoc)).target == "Module"
    end

    test "preserves line numbers for cross-references" do
      markdown = """
      Line 1
      Line 2 with [User](ash:User.Resource)
      Line 3
      Line 4 with [Guide](dev:setup)
      """
      
      refs = Processor.extract_cross_references(markdown)
      
      user_ref = Enum.find(refs, &(&1.target == "User.Resource"))
      guide_ref = Enum.find(refs, &(&1.target == "setup"))
      
      assert user_ref.line_number == 2
      assert guide_ref.line_number == 4
    end
  end

  describe "validate_cross_reference/2" do
    test "validates ash resource references exist" do
      cross_ref = %{type: :ash, target: "Sertantai.Accounts.User"}
      
      # Mock ash resource check
      result = Processor.validate_cross_reference(cross_ref, %{})
      
      assert result.valid == true
      assert result.exists == true
      assert result.error == nil
    end

    test "detects missing ash resources" do
      cross_ref = %{type: :ash, target: "NonExistent.Resource"}
      
      result = Processor.validate_cross_reference(cross_ref, %{})
      
      assert result.valid == false
      assert result.exists == false
      assert result.error == "Ash resource 'NonExistent.Resource' not found"
    end

    test "validates internal documentation links exist" do
      cross_ref = %{type: :dev, target: "setup-guide"}
      
      result = Processor.validate_cross_reference(cross_ref, %{})
      
      assert result.valid == true
      assert result.exists == true
    end

    test "detects missing internal documentation" do
      cross_ref = %{type: :dev, target: "non-existent-guide"}
      
      result = Processor.validate_cross_reference(cross_ref, %{})
      
      assert result.valid == false
      assert result.exists == false
      assert result.error == "Documentation file '/dev/non-existent-guide' not found"
    end
  end

  describe "options and configuration" do
    test "respects custom URL patterns" do
      markdown = "[User](ash:User.Resource)"
      options = %{
        ash_url_pattern: "/custom/ash/{{target}}",
        exdoc_url_pattern: "/custom/docs/{{target}}.html"
      }
      
      result = Processor.process_cross_references(markdown, options)
      
      assert result.html =~ ~s(href="/custom/ash/User.Resource")
    end

    test "allows disabling specific cross-reference types" do
      markdown = """
      [User](ash:User) and [Guide](dev:guide) and [Docs](exdoc:Module)
      """
      options = %{disabled_types: [:ash, :exdoc]}
      
      result = Processor.process_cross_references(markdown, options)
      
      # Only dev type should be processed
      assert length(result.cross_refs) == 1
      assert result.cross_refs |> hd() |> Map.get(:type) == :dev
    end

    test "supports custom link class patterns" do
      markdown = "[User](ash:User.Resource)"
      options = %{link_class_pattern: "custom-ref custom-ref-{{type}}"}
      
      result = Processor.process_cross_references(markdown, options)
      
      assert result.html =~ ~s(class="custom-ref custom-ref-ash")
    end
  end
end