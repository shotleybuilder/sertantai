defmodule SertantaiDocs.CodeBlockRenderingTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.MarkdownProcessor

  describe "code block rendering with cross-reference integration" do
    test "renders code blocks with syntax highlighting classes" do
      content = """
      # Test Document

      ```elixir
      def hello do
        IO.puts("Hello, World!")
      end
      ```
      """

      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      
      # Should have the sertantai-code-block class for custom styling
      assert html =~ "sertantai-code-block"
      
      # Should have syntax highlighting spans
      assert html =~ "<span"
      
      # Should preserve the code content (encoded in HTML)
      assert html =~ "hello"
      assert html =~ "puts"
    end

    test "renders code block headers with language display" do
      content = """
      ```elixir
      defmodule Example do
        def test, do: :ok
      end
      ```
      """

      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      
      # Should have the header section with language
      assert html =~ "flex items-center justify-between"
      
      # Should display the language name
      assert html =~ "elixir"
      
      # Should have the code icon
      assert html =~ "svg"
      assert html =~ "h-4 w-4"
    end

    test "renders code blocks with copy button" do
      content = """
      ```javascript
      console.log("Test");
      ```
      """

      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      
      # Should have copy button
      assert html =~ "Copy"
      assert html =~ "copyToClipboard"
      
      # Should have proper button styling
      assert html =~ "hover:bg-gray-200"
      
      # Should have unique ID for the code block
      assert html =~ ~r/code-block-[a-f0-9]{8}/
    end

    test "renders code blocks with proper container structure" do
      content = """
      ```python
      print("Hello")
      ```
      """

      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      
      # Should have the outer container with proper styling
      assert html =~ "relative group mb-4 rounded-lg border border-gray-200 bg-gray-50 overflow-hidden"
      
      # Should have header section
      assert html =~ "px-4 py-2 bg-gray-100 border-b border-gray-200"
      
      # Should have code section
      assert html =~ "<pre"
      assert html =~ "<code"
    end

    test "preserves code block content with cross-references in markdown" do
      content = """
      # Documentation with Cross-References

      Check the [User Resource](ash:Sertantai.Accounts.User) for more info.

      ```elixir
      # This should not be processed as a cross-reference
      # [Fake Link](ash:Should.Not.Process)
      def example do
        :ok
      end
      ```

      But this [Setup Guide](dev:setup-guide) should be processed.
      """

      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      
      # Cross-references outside code blocks should be processed
      assert html =~ "data-preview-enabled=\"true\""
      assert html =~ "class=\"cross-ref cross-ref-ash\""
      assert html =~ "href=\"/dev/setup-guide\""
      
      # Cross-references inside code blocks should NOT be processed as links
      # The text should be preserved but not as a cross-reference link
      assert html =~ "Should.Not.Process"
      refute html =~ "href=\"/api/ash/Should.Not.Process\""
      
      # Code block should still have enhanced rendering
      assert html =~ "sertantai-code-block"
      assert html =~ "Copy"
    end

    test "handles multiple code blocks with different languages" do
      content = """
      ## Multiple Examples

      ```elixir
      defmodule One do
        def test, do: 1
      end
      ```

      Some text between blocks.

      ```javascript
      function two() {
        return 2;
      }
      ```

      More text.

      ```bash
      echo "three"
      ```
      """

      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      
      # Each language should be displayed
      assert html =~ ">elixir<"
      assert html =~ ">javascript<"
      assert html =~ ">bash<"
      
      # Each should have a unique ID
      code_block_ids = Regex.scan(~r/code-block-([a-f0-9]{8})/, html)
      assert length(code_block_ids) >= 3
      
      # All should have copy buttons
      copy_buttons = Regex.scan(~r/copyToClipboard/, html)
      assert length(copy_buttons) >= 3
    end

    test "handles code blocks without language specification" do
      content = """
      ```
      plain text code block
      ```
      """

      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      
      # Should default to "text" language
      assert html =~ ">text<"
      
      # Should still have all enhancements
      assert html =~ "Copy"
      assert html =~ "sertantai-code-block"
    end

    test "preserves MDEx syntax highlighting while adding enhancements" do
      content = """
      ```elixir
      @moduledoc "Test module"
      
      def function_name(param) do
        {:ok, param}
      end
      ```
      """

      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      
      # Should have MDEx syntax highlighting classes/elements
      assert html =~ "sertantai-code-block"
      
      # Should have the enhanced container
      assert html =~ "relative group mb-4"
      
      # Should preserve syntax-highlighted content
      assert html =~ "moduledoc"
      assert html =~ "function_name"
    end
  end
end