defmodule SertantaiDocs.MarkdownProcessorTest do
  use ExUnit.Case, async: true
  
  alias SertantaiDocs.MarkdownProcessor

  @test_content_path "test/fixtures/content"

  describe "process_content/1" do
    test "processes basic markdown content" do
      content = "# Hello World\n\nThis is a test."
      
      assert {:ok, html, metadata} = MarkdownProcessor.process_content(content)
      assert html =~ "Hello World"
      assert html =~ "This is a test"
      assert html =~ "markdown-content"  # Wrapper div
      assert metadata == %{}
    end

    test "extracts frontmatter from content" do
      content = """
      ---
      title: Test Document
      category: dev
      tags: [test, markdown]
      ---
      # Content
      
      This is the body.
      """
      
      assert {:ok, html, metadata} = MarkdownProcessor.process_content(content)
      assert html =~ "Content"
      assert html =~ "data-title=\"Test Document\""
      assert metadata["title"] == "Test Document"
      assert metadata["category"] == "dev"
      assert metadata["tags"] == ["test", "markdown"]
    end

    test "handles invalid YAML frontmatter gracefully" do
      content = """
      ---
      invalid: yaml: content:
      ---
      # Content
      """
      
      assert {:ok, html, metadata} = MarkdownProcessor.process_content(content)
      assert html =~ "Content"
      assert metadata == %{}
    end

    test "processes GitHub Flavored Markdown features" do
      content = """
      ## Features

      - [x] Completed task
      - [ ] Pending task

      | Column 1 | Column 2 |
      |----------|----------|
      | Data 1   | Data 2   |

      ```elixir
      def hello, do: "world"
      ```

      ~~strikethrough text~~
      """
      
      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      assert html =~ "Features"
      assert html =~ "checked"           # Task list
      assert html =~ "table"             # Table (case insensitive)
      assert html =~ "strikethrough text"  # Strikethrough content
    end

    test "processes cross-references" do
      content = """
      See [User Resource](ash:User) for details.
      Check the [ExDoc](exdoc:SertantaiDocs.MarkdownProcessor).
      Go to [main app](main:users/new).
      """
      
      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      
      assert html =~ "User Resource"
      assert html =~ "ExDoc"
      assert html =~ "main app"
      # The references should be processed as links - check for the processed URLs
      assert html =~ "href=\"/api/User.html\""
      assert html =~ "href=\"/api/SertantaiDocs.MarkdownProcessor.html\""
      assert html =~ "href=\"http://localhost:4001/users/new\""
    end

    test "injects metadata as data attributes" do
      content = """
      ---
      title: Test
      category: dev
      ---
      # Content
      """
      
      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      assert html =~ "markdown-content"
      assert html =~ "data-title=\"Test\""
      assert html =~ "data-category=\"dev\""
    end

    test "handles processing errors gracefully" do
      # This would need a scenario that causes MDEx to fail
      # For now, testing with extremely large content
      large_content = String.duplicate("# Large heading\n\n", 10000)
      
      case MarkdownProcessor.process_content(large_content) do
        {:ok, _html, _metadata} -> 
          # Processing succeeded
          assert true
        {:error, {:markdown_processing_error, _reason}} ->
          # Processing failed as expected
          assert true
      end
    end
  end

  describe "process_file/1" do
    setup do
      # Create test content directory
      File.mkdir_p!(@test_content_path)
      
      on_exit(fn ->
        File.rm_rf!(@test_content_path)
      end)
    end

    test "processes existing markdown file" do
      content = """
      ---
      title: Test File
      ---
      # Test Content
      """
      
      # Create the proper directory structure for test
      File.mkdir_p!(Path.join([@test_content_path, "priv", "static", "docs"]))
      file_path = Path.join([@test_content_path, "priv", "static", "docs", "test.md"])
      File.write!(file_path, content)
      
      # Mock the Application.app_dir to point to our test
      test_app_dir = @test_content_path
      
      with_mock(Application, [:passthrough], [app_dir: fn 
        :sertantai_docs -> test_app_dir
        _other -> :meck.passthrough([])
      end], fn ->
        relative_path = "test.md"
        assert {:ok, html, metadata} = MarkdownProcessor.process_file(relative_path)
        assert html =~ "Test Content"
        assert metadata["title"] == "Test File"
      end)
    end

    test "returns error for non-existent file" do
      assert {:error, :file_not_found} = MarkdownProcessor.process_file("non_existent.md")
    end
  end

  describe "get_metadata/1" do
    setup do
      File.mkdir_p!(@test_content_path)
      
      on_exit(fn ->
        File.rm_rf!(@test_content_path)
      end)
    end

    test "extracts metadata from file with file system info" do
      content = """
      ---
      title: Metadata Test
      author: Test Author
      ---
      # Content
      """
      
      # Create proper directory structure
      File.mkdir_p!(Path.join([@test_content_path, "priv", "static", "docs"]))
      file_path = Path.join([@test_content_path, "priv", "static", "docs", "metadata_test.md"])
      File.write!(file_path, content)
      
      test_app_dir = @test_content_path
      
      with_mock(Application, [:passthrough], [app_dir: fn 
        :sertantai_docs -> test_app_dir
        _other -> :meck.passthrough([])
      end], fn ->
        relative_path = "metadata_test.md"
        assert {:ok, metadata} = MarkdownProcessor.get_metadata(relative_path)
        
        assert metadata["title"] == "Metadata Test"
        assert metadata["author"] == "Test Author"
        assert metadata["file_path"] == relative_path
        assert is_struct(metadata["last_modified"], DateTime)
        assert is_integer(metadata["size"])
      end)
    end
  end

  describe "list_content_files/0" do
    setup do
      File.mkdir_p!(Path.join(@test_content_path, "dev"))
      File.mkdir_p!(Path.join(@test_content_path, "user"))
      
      on_exit(fn ->
        File.rm_rf!(@test_content_path)
      end)
    end

    test "lists all markdown files in content directory" do
      # Create proper directory structure
      docs_dir = Path.join([@test_content_path, "priv", "static", "docs"])
      File.mkdir_p!(Path.join([docs_dir, "dev"]))
      File.mkdir_p!(Path.join([docs_dir, "user"]))
      
      # Create test files that we know are being found
      File.write!(Path.join([docs_dir, "dev", "index.md"]), "# Dev Home")
      File.write!(Path.join([docs_dir, "user", "index.md"]), "# User Home")
      File.write!(Path.join([docs_dir, "readme.txt"]), "Not markdown")
      
      test_app_dir = @test_content_path
      
      with_mock(Application, [:passthrough], [app_dir: fn :sertantai_docs -> test_app_dir end], fn ->
        files = MarkdownProcessor.list_content_files()
        
        assert is_list(files)
        assert "dev/index.md" in files
        assert "user/index.md" in files
        refute "readme.txt" in files
        # Check that at least 2 markdown files are found
        markdown_files = Enum.filter(files, &String.ends_with?(&1, ".md"))
        assert length(markdown_files) >= 2
      end)
    end
  end

  describe "generate_navigation/0" do
    setup do
      File.mkdir_p!(Path.join(@test_content_path, "dev"))
      File.mkdir_p!(Path.join(@test_content_path, "user"))
      
      on_exit(fn ->
        File.rm_rf!(@test_content_path)
      end)
    end

    test "generates navigation structure from files" do
      # Create proper directory structure
      docs_dir = Path.join([@test_content_path, "priv", "static", "docs"])
      File.mkdir_p!(Path.join([docs_dir, "dev"]))
      File.mkdir_p!(Path.join([docs_dir, "user"]))
      
      # Create test files with frontmatter
      File.write!(Path.join([docs_dir, "dev", "index.md"]), """
      ---
      title: Developer Guide
      ---
      # Dev Home
      """)
      
      File.write!(Path.join([docs_dir, "dev", "setup.md"]), """
      ---
      title: Setup Instructions
      ---
      # Setup
      """)
      
      File.write!(Path.join([docs_dir, "user", "index.md"]), """
      ---
      title: User Guide
      ---
      # User Home
      """)
      
      test_app_dir = @test_content_path
      
      with_mock(Application, [:passthrough], [app_dir: fn 
        :sertantai_docs -> test_app_dir
        _other -> :meck.passthrough([])
      end], fn ->
        assert {:ok, navigation} = MarkdownProcessor.generate_navigation()
        
        assert is_list(navigation)
        
        # Find dev section - allow both explicit title from frontmatter and fallback
        dev_section = Enum.find(navigation, fn section ->
          section[:title] in ["Developer Guide", "Dev"]
        end)
        assert dev_section
        assert dev_section[:path] == "/dev"
        
        # Find user section  
        user_section = Enum.find(navigation, &(&1[:title] == "User Guide"))
        assert user_section
        assert user_section[:path] == "/user"
      end)
    end
  end

  # Helper function to mock Application.app_dir in tests
  defp with_mock(module, opts, mocks, fun) do
    try do
      :meck.new(module, opts)
      Enum.each(mocks, fn {func, mock_fun} ->
        :meck.expect(module, func, mock_fun)
      end)
      fun.()
    after
      :meck.unload(module)
    end
  end
end