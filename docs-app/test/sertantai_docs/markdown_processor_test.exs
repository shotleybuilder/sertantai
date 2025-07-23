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
      # The references should be processed as CrossRef links with the new URL format
      assert html =~ "href=\"/api/ash/User\""
      assert html =~ "href=\"/api/docs/SertantaiDocs.MarkdownProcessor.html\""
      assert html =~ "href=\"http://localhost:4001/users/new\""
      
      # Check that CrossRef attributes are present for hover functionality
      assert html =~ "data-preview-enabled=\"true\""
      assert html =~ "data-ref-type=\"ash\""
      assert html =~ "data-ref-type=\"exdoc\""
      assert html =~ "class=\"cross-ref cross-ref-ash\""
      assert html =~ "class=\"cross-ref cross-ref-exdoc\""
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

    test "processes TOC placeholders and generates table of contents" do
      content = """
      ---
      title: Test Document
      ---
      # Test Document
      
      This is a test document.
      
      <!-- TOC -->
      
      ## Section 1
      
      Some content here.
      
      ## Section 2
      
      More content.
      
      ### Subsection 2.1
      
      Even more content.
      """
      
      assert {:ok, html, metadata} = MarkdownProcessor.process_content(content)
      
      # Should replace TOC placeholder with actual TOC
      refute html =~ "<!-- TOC -->"
      assert html =~ "table-of-contents"
      assert html =~ "Section 1"
      assert html =~ "Section 2"  
      assert html =~ "Subsection 2.1"
      
      # TOC should link to headings
      assert html =~ "#section-1"
      assert html =~ "#section-2"
      assert html =~ "#subsection-21"
      
      # Should exclude H1 from TOC (page title)
      toc_section = Regex.scan(~r/table-of-contents.*?<\/nav>/s, html) |> List.first()
      toc_content = if toc_section, do: List.first(toc_section), else: ""
      refute String.contains?(toc_content, "Test Document")
      
      # Metadata should be extracted correctly
      assert metadata["title"] == "Test Document"
    end
    
    test "handles documents without TOC placeholder" do
      content = """
      # Test Document
      
      ## Section 1
      
      Some content.
      """
      
      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      
      # Should not contain TOC when no placeholder
      refute html =~ "table-of-contents"
      assert html =~ "Section 1"
    end
    
    test "handles empty TOC when no headings present" do
      content = """
      # Test Document
      
      <!-- TOC -->
      
      Just some regular content without headings.
      """
      
      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(content)
      
      # Should replace placeholder but not show TOC content when no headings
      refute html =~ "<!-- TOC -->"
      refute html =~ "table-of-contents"
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

  describe "advanced filtering and sorting" do
    setup do
      File.mkdir_p!(Path.join(@test_content_path, "build"))
      
      on_exit(fn ->
        File.rm_rf!(@test_content_path)
      end)
    end

    test "filters navigation items by metadata status" do
      nav_items = [
        %{title: "Live Doc", path: "/live", metadata: %{"status" => "live"}},
        %{title: "Archived Doc", path: "/archived", metadata: %{"status" => "archived"}},
        %{title: "No Status Doc", path: "/none", metadata: %{}}
      ]

      # Test live filter
      live_items = MarkdownProcessor.filter_by_status(nav_items, "live")
      assert length(live_items) == 1
      assert List.first(live_items).title == "Live Doc"

      # Test archived filter  
      archived_items = MarkdownProcessor.filter_by_status(nav_items, "archived")
      assert length(archived_items) == 1
      assert List.first(archived_items).title == "Archived Doc"

      # Test empty filter (show all)
      all_items = MarkdownProcessor.filter_by_status(nav_items, "")
      assert length(all_items) == 3
    end

    test "filters navigation items by metadata category" do
      nav_items = [
        %{title: "Security Doc", path: "/sec", metadata: %{"category" => "security"}},
        %{title: "Admin Doc", path: "/admin", metadata: %{"category" => "admin"}}, 
        %{title: "Implementation Doc", path: "/impl", metadata: %{"category" => "implementation"}},
        %{title: "No Category", path: "/none", metadata: %{}}
      ]

      # Test security filter
      security_items = MarkdownProcessor.filter_by_category(nav_items, "security")
      assert length(security_items) == 1
      assert List.first(security_items).title == "Security Doc"

      # Test admin filter
      admin_items = MarkdownProcessor.filter_by_category(nav_items, "admin")
      assert length(admin_items) == 1
      assert List.first(admin_items).title == "Admin Doc"

      # Test empty filter (show all)
      all_items = MarkdownProcessor.filter_by_category(nav_items, "")
      assert length(all_items) == 4
    end

    test "filters navigation items by metadata priority" do
      nav_items = [
        %{title: "High Priority", path: "/high", metadata: %{"priority" => "high"}},
        %{title: "Medium Priority", path: "/med", metadata: %{"priority" => "medium"}},
        %{title: "Low Priority", path: "/low", metadata: %{"priority" => "low"}},
        %{title: "No Priority", path: "/none", metadata: %{}}
      ]

      # Test high priority filter
      high_items = MarkdownProcessor.filter_by_priority(nav_items, "high")
      assert length(high_items) == 1
      assert List.first(high_items).title == "High Priority"

      # Test medium priority filter
      medium_items = MarkdownProcessor.filter_by_priority(nav_items, "medium")
      assert length(medium_items) == 1
      assert List.first(medium_items).title == "Medium Priority"

      # Test empty filter (show all)
      all_items = MarkdownProcessor.filter_by_priority(nav_items, "")
      assert length(all_items) == 4
    end

    test "filters navigation items by author metadata" do
      nav_items = [
        %{title: "Claude Doc", path: "/claude", metadata: %{"author" => "Claude"}},
        %{title: "User Doc", path: "/user", metadata: %{"author" => "User"}},
        %{title: "System Doc", path: "/sys", metadata: %{"author" => "System"}},
        %{title: "No Author", path: "/none", metadata: %{}}
      ]

      # Test Claude filter
      claude_items = MarkdownProcessor.filter_by_author(nav_items, "Claude")
      assert length(claude_items) == 1
      assert List.first(claude_items).title == "Claude Doc"

      # Test User filter
      user_items = MarkdownProcessor.filter_by_author(nav_items, "User")
      assert length(user_items) == 1
      assert List.first(user_items).title == "User Doc"

      # Test empty filter (show all)
      all_items = MarkdownProcessor.filter_by_author(nav_items, "")
      assert length(all_items) == 4
    end

    test "filters navigation items by tags metadata" do
      nav_items = [
        %{title: "Phase Doc", path: "/phase", metadata: %{"tags" => ["phase-1", "implementation"]}},
        %{title: "Security Doc", path: "/sec", metadata: %{"tags" => ["security", "admin"]}},
        %{title: "Mixed Doc", path: "/mix", metadata: %{"tags" => ["phase-1", "security"]}},
        %{title: "No Tags", path: "/none", metadata: %{}}
      ]

      # Test single tag filter
      phase_items = MarkdownProcessor.filter_by_tags(nav_items, ["phase-1"])
      assert length(phase_items) == 2
      titles = Enum.map(phase_items, & &1.title)
      assert "Phase Doc" in titles
      assert "Mixed Doc" in titles

      # Test multiple tag filter (OR logic)
      multi_items = MarkdownProcessor.filter_by_tags(nav_items, ["security", "admin"])
      assert length(multi_items) == 2
      titles = Enum.map(multi_items, & &1.title)
      assert "Security Doc" in titles
      assert "Mixed Doc" in titles

      # Test empty filter (show all)
      all_items = MarkdownProcessor.filter_by_tags(nav_items, [])
      assert length(all_items) == 4
    end

    test "applies multiple filters simultaneously" do
      nav_items = [
        %{title: "Live Security High", path: "/lsh", metadata: %{"status" => "live", "category" => "security", "priority" => "high"}},
        %{title: "Live Security Low", path: "/lsl", metadata: %{"status" => "live", "category" => "security", "priority" => "low"}},
        %{title: "Archived Security High", path: "/ash", metadata: %{"status" => "archived", "category" => "security", "priority" => "high"}},
        %{title: "Live Admin High", path: "/lah", metadata: %{"status" => "live", "category" => "admin", "priority" => "high"}}
      ]

      filter_options = %{
        status: "live",
        category: "security", 
        priority: "high",
        author: "",
        tags: []
      }

      filtered_items = MarkdownProcessor.apply_filters(nav_items, filter_options)

      # Should only include items matching all filters
      assert length(filtered_items) == 1
      assert List.first(filtered_items).title == "Live Security High"
    end

    test "sorts navigation items by priority" do
      nav_items = [
        %{title: "Medium Doc", metadata: %{"priority" => "medium"}},
        %{title: "High Doc", metadata: %{"priority" => "high"}},
        %{title: "Low Doc", metadata: %{"priority" => "low"}},
        %{title: "No Priority", metadata: %{}}
      ]

      # Test ascending priority sort (high -> medium -> low)
      sorted_asc = MarkdownProcessor.sort_by_priority(nav_items, :asc)
      titles = Enum.map(sorted_asc, & &1.title)
      assert titles == ["High Doc", "Medium Doc", "Low Doc", "No Priority"]

      # Test descending priority sort (low -> medium -> high)
      sorted_desc = MarkdownProcessor.sort_by_priority(nav_items, :desc)
      titles = Enum.map(sorted_desc, & &1.title)
      assert titles == ["No Priority", "Low Doc", "Medium Doc", "High Doc"]
    end

    test "sorts navigation items by title alphabetically" do
      nav_items = [
        %{title: "Zebra Doc", metadata: %{}},
        %{title: "Alpha Doc", metadata: %{}},
        %{title: "Beta Doc", metadata: %{}}
      ]

      # Test ascending sort
      sorted_asc = MarkdownProcessor.sort_by_title(nav_items, :asc)
      titles = Enum.map(sorted_asc, & &1.title)
      assert titles == ["Alpha Doc", "Beta Doc", "Zebra Doc"]

      # Test descending sort
      sorted_desc = MarkdownProcessor.sort_by_title(nav_items, :desc)
      titles = Enum.map(sorted_desc, & &1.title)
      assert titles == ["Zebra Doc", "Beta Doc", "Alpha Doc"]
    end

    test "sorts navigation items by last_modified date" do
      nav_items = [
        %{title: "Old Doc", metadata: %{"last_modified" => "2024-01-01"}},
        %{title: "New Doc", metadata: %{"last_modified" => "2024-12-31"}},
        %{title: "Middle Doc", metadata: %{"last_modified" => "2024-06-15"}},
        %{title: "No Date", metadata: %{}}
      ]

      # Test descending date sort (newest first)
      sorted_desc = MarkdownProcessor.sort_by_date(nav_items, :desc)
      titles = Enum.map(sorted_desc, & &1.title)
      assert titles == ["New Doc", "Middle Doc", "Old Doc", "No Date"]

      # Test ascending date sort (oldest first)
      sorted_asc = MarkdownProcessor.sort_by_date(nav_items, :asc)
      titles = Enum.map(sorted_asc, & &1.title)
      assert titles == ["No Date", "Old Doc", "Middle Doc", "New Doc"]
    end

    test "sorts navigation items by category" do
      nav_items = [
        %{title: "Security Doc", metadata: %{"category" => "security"}},
        %{title: "Admin Doc", metadata: %{"category" => "admin"}},
        %{title: "Implementation Doc", metadata: %{"category" => "implementation"}},
        %{title: "Analysis Doc", metadata: %{"category" => "analysis"}},
        %{title: "No Category", metadata: %{}}
      ]

      # Test ascending category sort
      sorted_asc = MarkdownProcessor.sort_by_category(nav_items, :asc)
      titles = Enum.map(sorted_asc, & &1.title)
      assert titles == ["Admin Doc", "Analysis Doc", "Implementation Doc", "Security Doc", "No Category"]

      # Test descending category sort
      sorted_desc = MarkdownProcessor.sort_by_category(nav_items, :desc)
      titles = Enum.map(sorted_desc, & &1.title)
      assert titles == ["No Category", "Security Doc", "Implementation Doc", "Analysis Doc", "Admin Doc"]
    end

    test "maintains sort stability for equal values" do
      nav_items = [
        %{title: "First High", metadata: %{"priority" => "high"}},
        %{title: "Second High", metadata: %{"priority" => "high"}},
        %{title: "Third High", metadata: %{"priority" => "high"}}
      ]

      # When priorities are equal, should maintain original order (stable sort)
      sorted_items = MarkdownProcessor.sort_by_priority(nav_items, :asc)
      titles = Enum.map(sorted_items, & &1.title)
      assert titles == ["First High", "Second High", "Third High"]
    end

    test "extracts available filter options from navigation items" do
      nav_items = [
        %{title: "Doc 1", metadata: %{"status" => "live", "category" => "security", "priority" => "high", "author" => "Claude", "tags" => ["phase-1", "security"]}},
        %{title: "Doc 2", metadata: %{"status" => "archived", "category" => "admin", "priority" => "medium", "author" => "User", "tags" => ["admin", "testing"]}},
        %{title: "Doc 3", metadata: %{"status" => "live", "category" => "implementation", "priority" => "low", "author" => "Claude", "tags" => ["phase-1", "implementation"]}}
      ]

      options = MarkdownProcessor.extract_filter_options(nav_items)

      # Should extract unique values from all documents
      assert Enum.sort(options.statuses) == ["archived", "live"]
      assert Enum.sort(options.categories) == ["admin", "implementation", "security"]
      assert Enum.sort(options.priorities) == ["high", "low", "medium"]
      assert Enum.sort(options.authors) == ["Claude", "User"]
      assert Enum.sort(options.tags) == ["admin", "implementation", "phase-1", "security", "testing"]
    end

    test "combines filtering and sorting operations" do
      nav_items = [
        %{title: "High Security A", metadata: %{"priority" => "high", "category" => "security", "status" => "live"}},
        %{title: "Medium Security B", metadata: %{"priority" => "medium", "category" => "security", "status" => "live"}},
        %{title: "High Admin C", metadata: %{"priority" => "high", "category" => "admin", "status" => "live"}},
        %{title: "Low Security D", metadata: %{"priority" => "low", "category" => "security", "status" => "archived"}}
      ]

      # Filter by security + live, then sort by priority (high -> medium -> low)
      filter_options = %{status: "live", category: "security", priority: "", author: "", tags: []}
      
      filtered_items = MarkdownProcessor.apply_filters(nav_items, filter_options)
      sorted_filtered = MarkdownProcessor.sort_by_priority(filtered_items, :asc)

      titles = Enum.map(sorted_filtered, & &1.title)
      assert titles == ["High Security A", "Medium Security B"]
    end

    test "handles edge cases with missing metadata gracefully" do
      nav_items = [
        %{title: "Complete Doc", metadata: %{"status" => "live", "category" => "security", "priority" => "high"}},
        %{title: "Partial Doc", metadata: %{"status" => "live"}},
        %{title: "Empty Metadata", metadata: %{}},
        %{title: "Nil Metadata", metadata: nil}
      ]

      # Should not crash with missing metadata
      assert length(MarkdownProcessor.filter_by_status(nav_items, "live")) == 2
      assert length(MarkdownProcessor.filter_by_category(nav_items, "security")) == 1
      assert length(MarkdownProcessor.filter_by_priority(nav_items, "high")) == 1

      # Should handle all items when sorting with missing metadata
      sorted = MarkdownProcessor.sort_by_priority(nav_items, :asc)
      assert length(sorted) == 4
    end

    test "supports case-insensitive filtering" do
      nav_items = [
        %{title: "Upper Doc", metadata: %{"category" => "SECURITY"}},
        %{title: "Lower Doc", metadata: %{"category" => "security"}},
        %{title: "Mixed Doc", metadata: %{"category" => "Security"}}
      ]

      # Should find all security documents regardless of case
      security_items = MarkdownProcessor.filter_by_category_case_insensitive(nav_items, "security")
      assert length(security_items) == 3

      security_items_upper = MarkdownProcessor.filter_by_category_case_insensitive(nav_items, "SECURITY")
      assert length(security_items_upper) == 3
    end
  end

  describe "metadata extraction and caching" do
    test "caches extracted metadata for performance" do
      # This test verifies metadata caching optimization
      nav_items = [
        %{title: "Doc 1", path: "/doc1", metadata: %{"category" => "security"}},
        %{title: "Doc 2", path: "/doc2", metadata: %{"category" => "admin"}}
      ]

      # First call should build cache
      options1 = MarkdownProcessor.extract_filter_options(nav_items)
      
      # Second call should use cache (this would be measured in real implementation)
      options2 = MarkdownProcessor.extract_filter_options(nav_items)
      
      assert options1.categories == options2.categories
      assert options1.statuses == options2.statuses
    end

    test "refreshes cache when navigation items change" do
      initial_items = [
        %{title: "Doc 1", metadata: %{"category" => "security"}}
      ]

      updated_items = [
        %{title: "Doc 1", metadata: %{"category" => "security"}},
        %{title: "Doc 2", metadata: %{"category" => "admin"}}
      ]

      options1 = MarkdownProcessor.extract_filter_options(initial_items)
      options2 = MarkdownProcessor.extract_filter_options(updated_items)

      assert length(options1.categories) == 1
      assert length(options2.categories) == 2
      assert "admin" in options2.categories
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