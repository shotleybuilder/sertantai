defmodule SertantaiDocsWeb.CodeBlockStylingTest do
  use SertantaiDocsWeb.ConnCase

  @moduledoc """
  Integration tests for code block styling, features, and functionality.
  
  Tests verify:
  - Light grey background (no dark background)
  - Language detection and display
  - Copy button functionality 
  - Proper HTML structure
  - JavaScript integration
  """

  describe "code block styling and features" do
    test "code blocks have light grey background, not dark", %{conn: conn} do
      conn = get(conn, "/dev/documentation-system")
      response_body = response(conn, 200)
      
      # Should have our custom light grey code blocks
      assert response_body =~ ~s(class="relative group mb-4 rounded-lg border border-gray-200 bg-gray-50 overflow-hidden")
      assert response_body =~ ~s(bg-gray-50)
      assert response_body =~ ~s(text-gray-800)
      
      # Should NOT have dark background styling
      refute String.contains?(response_body, "background-color: #282c34"), "Should not contain dark background"
      refute String.contains?(response_body, "color: #abb2bf"), "Should not contain light text for dark theme"
      refute String.contains?(response_body, ~s(class="athl")), "Should not contain dark theme class"
    end

    test "code blocks include language headers", %{conn: conn} do
      conn = get(conn, "/dev/documentation-system")
      response_body = response(conn, 200)
      
      # Should show language headers
      assert response_body =~ ~s(<span class="text-sm font-medium text-gray-700 capitalize">)
      
      # Should detect and display different languages appropriately
      # For text/plaintext content, should show "text"
      assert response_body =~ ~s(capitalize">text</span>)
      
      # Should have code bracket icon
      assert response_body =~ ~s(d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"), "Should include code bracket icon"
    end

    test "code blocks include copy button with proper attributes", %{conn: conn} do
      conn = get(conn, "/dev/documentation-system")
      response_body = response(conn, 200)
      
      # Should have copy button
      assert response_body =~ ~s(onclick="copyToClipboard(')
      assert response_body =~ ~s(title="Copy to clipboard")
      assert response_body =~ ~s(<span>Copy</span>)
      
      # Should have document duplicate icon for copy
      assert response_body =~ ~s(d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"), "Should include copy icon"
    end

    test "code blocks have unique IDs for copy functionality", %{conn: conn} do
      conn = get(conn, "/dev/documentation-system")
      response_body = response(conn, 200)
      
      # Should have unique code block IDs
      assert response_body =~ ~r/id="code-block-[a-f0-9]{8}"/
      assert response_body =~ ~r/id="code-block-[a-f0-9]{8}-content"/
      
      # Should have matching onclick handlers
      assert response_body =~ ~r/onclick="copyToClipboard\('code-block-[a-f0-9]{8}'\)"/
    end

    test "code block structure is well-formed", %{conn: conn} do
      conn = get(conn, "/dev/documentation-system")
      response_body = response(conn, 200)
      
      # Should have proper nested structure
      # Container -> Header (with language + copy button) -> Content
      assert response_body =~ ~s(<div class="flex items-center justify-between px-4 py-2 bg-gray-100 border-b border-gray-200">)
      assert response_body =~ ~s(<div class="relative">)
      assert response_body =~ ~s(<pre class="athl sertantai-code-block")
    end

    test "code content is properly escaped and structured", %{conn: conn} do
      conn = get(conn, "/dev/documentation-system")
      response_body = response(conn, 200)
      
      # Should contain expected code content
      assert response_body =~ "docs-app/priv/static/docs/"
      
      # Code content should be in proper <code> tags with our IDs
      assert response_body =~ ~r/<code id="code-block-[a-f0-9]{8}-content">/
      
      # Should not contain unescaped HTML or malformed content from cleaning
      refute String.contains?(response_body, "<span class=\"line\""), "Should not contain line span tags from MDEx"
      refute String.contains?(response_body, "data-line="), "Should not contain data-line attributes"
    end
  end

  describe "language detection for different code types" do
    test "detects different programming languages correctly" do
      # Test different language detection by creating content with various languages
      
      # Create a test markdown content with different code blocks
      test_content = """
      # Test Document

      ```elixir
      def hello_world do
        "Hello, World!"
      end
      ```

      ```javascript
      function helloWorld() {
        return "Hello, World!";
      }
      ```

      ```yaml
      title: "Test"
      language: "yaml"
      ```

      ```markdown
      # This is markdown
      - List item
      ```
      """
      
      # Process the content
      case SertantaiDocs.MarkdownProcessor.process_content(test_content) do
        {:ok, html_content, _frontmatter} ->
          # Should detect elixir language
          assert html_content =~ ~s(capitalize">elixir</span>)
          
          # Should detect javascript language  
          assert html_content =~ ~s(capitalize">javascript</span>)
          
          # Should detect yaml language
          assert html_content =~ ~s(capitalize">yaml</span>)
          
          # Should detect markdown language
          assert html_content =~ ~s(capitalize">markdown</span>)
          
          # All should have light grey styling
          assert html_content =~ ~s(bg-gray-50)
          refute String.contains?(html_content, "#282c34"), "Should not have dark background"
          
        {:error, reason} ->
          flunk("Failed to process test content: #{inspect(reason)}")
      end
    end

    test "handles edge cases in language detection" do
      test_content = """
      ```
      Code without language specified
      ```

      ```plaintext
      Plain text content
      ```
      """
      
      case SertantaiDocs.MarkdownProcessor.process_content(test_content) do
        {:ok, html_content, _frontmatter} ->
          # Should default to "text" for unspecified language
          assert html_content =~ ~s(capitalize">text</span>)
          
          # Should convert plaintext to text
          assert html_content =~ ~s(capitalize">text</span>)
          
        {:error, reason} ->
          flunk("Failed to process edge case content: #{inspect(reason)}")
      end
    end
  end

  describe "copy functionality structure" do
    test "JavaScript copy function should be available", %{conn: conn} do
      # Get any page to check if JavaScript is loaded
      conn = get(conn, "/dev")
      response_body = response(conn, 200)
      
      # Should include app.js which contains our copy functions
      assert response_body =~ ~s(src="/assets/app.js")
    end

    test "copy button generates correct JavaScript calls", %{conn: conn} do
      conn = get(conn, "/dev/documentation-system")
      response_body = response(conn, 200)
      
      # Extract a code block ID from the response
      id_match = Regex.run(~r/id="(code-block-[a-f0-9]{8})"/, response_body)
      assert id_match, "Should find at least one code block ID"
      
      [_, block_id] = id_match
      
      # Should have corresponding onclick handler
      assert response_body =~ "onclick=\"copyToClipboard('#{block_id}')\""
      
      # Should have corresponding content element
      assert response_body =~ "id=\"#{block_id}-content\""
    end
  end

  describe "code block content formatting" do
    test "removes leading spaces from code block content" do
      test_content = """
      ```elixir
      def hello do
        "world"
      end
      ```
      """

      case SertantaiDocs.MarkdownProcessor.process_content(test_content) do
        {:ok, html_content, _frontmatter} ->
          # Extract the code content from the HTML (now includes syntax highlighting spans)
          case Regex.run(~r/<code[^>]*>(.*?)<\/code>/s, html_content) do
            [_full_match, code_content] ->
              # Strip syntax highlighting spans to get plain text
              plain_content = code_content
                |> String.replace(~r/<span[^>]*>/, "")
                |> String.replace("</span>", "")
                # Decode HTML entities to get the actual content
                |> String.replace("&lt;", "<")
                |> String.replace("&gt;", ">")
                |> String.replace("&amp;", "&")
                |> String.replace("&quot;", "\"")
                |> String.trim()
              
              # The code should start with "def hello do" without any leading space
              assert String.starts_with?(plain_content, "def hello do"),
                     "Code should start with 'def hello do', got: #{inspect(String.slice(plain_content, 0, 20))}"
              
              # Should not start with a space or newline
              refute String.starts_with?(plain_content, " "),
                     "Code should not start with space, got: #{inspect(String.slice(plain_content, 0, 10))}"
              refute String.starts_with?(plain_content, "\n"),
                     "Code should not start with newline, got: #{inspect(String.slice(plain_content, 0, 10))}"
              
              # Verify the complete expected content without leading space
              expected_lines = [
                "def hello do",
                "  \"world\"",
                "end"
              ]
              expected_content = Enum.join(expected_lines, "\n")
              assert plain_content == expected_content,
                     "Expected:\n#{expected_content}\nGot:\n#{plain_content}"
              
            nil ->
              flunk("Could not extract code content from HTML: #{String.slice(html_content, 0, 500)}")
          end
          
        {:error, reason} ->
          flunk("Failed to process test content: #{inspect(reason)}")
      end
    end

    test "preserves relative indentation while removing leading spaces" do
      test_content = """
      ```ruby
      class Hello
        def initialize
          @message = "world"
        end
        
        def greet
          puts @message
        end
      end
      ```
      """

      case SertantaiDocs.MarkdownProcessor.process_content(test_content) do
        {:ok, html_content, _frontmatter} ->
          case Regex.run(~r/<code[^>]*>(.*?)<\/code>/s, html_content) do
            [_full_match, code_content] ->
              # Strip syntax highlighting spans and decode HTML entities
              plain_content = code_content
                |> String.replace(~r/<span[^>]*>/, "")
                |> String.replace("</span>", "")
                |> String.replace("&lt;", "<")
                |> String.replace("&gt;", ">")
                |> String.replace("&amp;", "&")
                |> String.replace("&quot;", "\"")
                |> String.trim()
              
              # Should start with the class definition
              assert String.starts_with?(plain_content, "class Hello"),
                     "Should start with 'class Hello'"
              
              # Should maintain relative indentation (2 spaces for method content)
              lines = String.split(plain_content, "\n")
              assert Enum.at(lines, 1) =~ ~r/^  def initialize$/,
                     "Second line should have 2-space indentation"
              assert Enum.at(lines, 2) =~ ~r/^    @message = "world"$/,
                     "Third line should have 4-space indentation"
              
            nil ->
              flunk("Could not extract code content from HTML")
          end
          
        {:error, reason} ->
          flunk("Failed to process test content: #{inspect(reason)}")
      end
    end
  end
end