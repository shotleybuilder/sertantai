defmodule SertantaiDocs.Navigation.ScannerTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.Navigation.Scanner

  @test_docs_path "test/fixtures/docs"

  describe "scan_directory/1" do
    test "scans empty directory and returns empty structure" do
      # Create empty temp directory for test
      temp_dir = System.tmp_dir!() |> Path.join("empty_docs_#{:rand.uniform(1000)}")
      File.mkdir_p!(temp_dir)

      result = Scanner.scan_directory(temp_dir)

      assert result == %{categories: %{}, files: []}

      # Clean up
      File.rm_rf!(temp_dir)
    end

    test "scans directory with single markdown file" do
      # Create temp directory with single file
      temp_dir = System.tmp_dir!() |> Path.join("single_docs_#{:rand.uniform(1000)}")
      File.mkdir_p!(temp_dir)
      
      file_content = """
      ---
      title: "Test Document"
      category: "test"
      priority: 1
      ---
      # Test Content
      """
      
      File.write!(Path.join(temp_dir, "test.md"), file_content)

      result = Scanner.scan_directory(temp_dir)

      assert %{categories: categories, files: files} = result
      assert length(files) == 1
      
      [file] = files
      assert file.title == "Test Document"
      assert file.category == "test"
      assert file.priority == 1
      assert file.path =~ "test.md"

      # Clean up
      File.rm_rf!(temp_dir)
    end

    test "scans nested directory structure with categories" do
      # Create nested structure
      temp_dir = System.tmp_dir!() |> Path.join("nested_docs_#{:rand.uniform(1000)}")
      dev_dir = Path.join(temp_dir, "dev")
      user_dir = Path.join(temp_dir, "user")
      
      File.mkdir_p!(dev_dir)
      File.mkdir_p!(user_dir)
      
      # Create dev category index
      dev_index = """
      ---
      title: "Developer Documentation"
      category: "dev"
      ---
      # Developer Docs
      """
      File.write!(Path.join(dev_dir, "index.md"), dev_index)
      
      # Create dev subcontent
      dev_setup = """
      ---
      title: "Setup Guide"
      category: "dev"
      priority: 1
      tags: ["setup", "getting-started"]
      ---
      # Setup Guide
      """
      File.write!(Path.join(dev_dir, "setup.md"), dev_setup)
      
      # Create user category
      user_guide = """
      ---
      title: "User Guide"
      category: "user"
      priority: 1
      ---
      # User Guide
      """
      File.write!(Path.join(user_dir, "guide.md"), user_guide)

      result = Scanner.scan_directory(temp_dir)

      assert %{categories: categories, files: files} = result
      assert length(files) == 3
      
      # Check categories structure
      assert Map.has_key?(categories, "dev")
      assert Map.has_key?(categories, "user")
      
      dev_category = categories["dev"]
      assert dev_category.title == "Developer Documentation"
      assert length(dev_category.files) == 2

      user_category = categories["user"]
      assert length(user_category.files) == 1

      # Clean up
      File.rm_rf!(temp_dir)
    end

    test "handles files with missing or invalid frontmatter" do
      temp_dir = System.tmp_dir!() |> Path.join("invalid_docs_#{:rand.uniform(1000)}")
      File.mkdir_p!(temp_dir)
      
      # File with no frontmatter
      File.write!(Path.join(temp_dir, "no-frontmatter.md"), "# Just content")
      
      # File with invalid YAML
      invalid_yaml = """
      ---
      title: "Invalid YAML
      broken: [unclosed
      ---
      # Content
      """
      File.write!(Path.join(temp_dir, "invalid.md"), invalid_yaml)

      result = Scanner.scan_directory(temp_dir)

      assert %{files: files} = result
      assert length(files) == 2
      
      # Files should have default values for missing frontmatter
      for file <- files do
        assert is_binary(file.title)
        assert file.category == "uncategorized"
        assert is_integer(file.priority)
      end

      # Clean up
      File.rm_rf!(temp_dir)
    end

    test "sorts files by priority and then alphabetically" do
      temp_dir = System.tmp_dir!() |> Path.join("sorted_docs_#{:rand.uniform(1000)}")
      File.mkdir_p!(temp_dir)
      
      # Create files with different priorities
      files_data = [
        {"zebra.md", "Zebra", 3},
        {"alpha.md", "Alpha", 1},
        {"beta.md", "Beta", 1},
        {"gamma.md", "Gamma", 2}
      ]
      
      for {filename, title, priority} <- files_data do
        content = """
        ---
        title: "#{title}"
        priority: #{priority}
        ---
        # #{title}
        """
        File.write!(Path.join(temp_dir, filename), content)
      end

      result = Scanner.scan_directory(temp_dir)
      files = result.files

      # Should be sorted by priority first, then title
      expected_order = ["Alpha", "Beta", "Gamma", "Zebra"]
      actual_order = Enum.map(files, & &1.title)
      
      assert actual_order == expected_order

      # Clean up
      File.rm_rf!(temp_dir)
    end
  end

  describe "extract_frontmatter/1" do
    test "extracts valid frontmatter" do
      content = """
      ---
      title: "Test Title"
      category: "test"
      priority: 5
      tags: ["tag1", "tag2"]
      ---
      # Content here
      """

      {frontmatter, markdown} = Scanner.extract_frontmatter(content)

      assert frontmatter["title"] == "Test Title"
      assert frontmatter["category"] == "test"
      assert frontmatter["priority"] == 5
      assert frontmatter["tags"] == ["tag1", "tag2"]
      assert String.trim(markdown) == "# Content here"
    end

    test "handles missing frontmatter" do
      content = "# Just markdown content"

      {frontmatter, markdown} = Scanner.extract_frontmatter(content)

      assert frontmatter == %{}
      assert markdown == content
    end

    test "handles invalid YAML in frontmatter" do
      content = """
      ---
      invalid: yaml: content
      ---
      # Content
      """

      {frontmatter, markdown} = Scanner.extract_frontmatter(content)

      assert frontmatter == %{}
      assert String.contains?(markdown, "# Content")
    end
  end
end