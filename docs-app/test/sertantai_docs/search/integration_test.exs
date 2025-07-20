defmodule SertantaiDocs.Search.IntegrationTest do
  use ExUnit.Case, async: false

  alias SertantaiDocs.Navigation.Scanner
  alias SertantaiDocs.Search.{Index, Engine}

  @test_docs_dir "test/fixtures/search_test_docs"

  setup do
    # Create test directory structure
    File.rm_rf!(@test_docs_dir)
    File.mkdir_p!(Path.join(@test_docs_dir, "user"))
    File.mkdir_p!(Path.join(@test_docs_dir, "dev"))
    
    # Create test documents
    create_test_documents()
    
    on_exit(fn ->
      File.rm_rf!(@test_docs_dir)
    end)
    
    :ok
  end

  describe "navigation and search integration" do
    test "indexes all documents found by scanner" do
      # Scan directory
      scan_result = Scanner.scan_directory(@test_docs_dir)
      
      # Build search index from scan results
      search_index = Engine.index_from_scan_result(scan_result)
      
      assert search_index.document_count == length(scan_result.files)
      
      # All scanned files should be searchable
      for file <- scan_result.files do
        results = Index.search(search_index, file.title)
        assert length(results) > 0
        assert Enum.any?(results, &(&1.id == file_id_from_path(file.file_path)))
      end
    end

    test "maintains consistency between navigation and search" do
      # Initial scan and index
      scan_result = Scanner.scan_directory(@test_docs_dir)
      search_index = Engine.index_from_scan_result(scan_result)
      
      initial_nav_count = length(scan_result.files)
      initial_search_count = search_index.document_count
      
      assert initial_nav_count == initial_search_count
      
      # Add a new document
      new_doc_path = Path.join(@test_docs_dir, "new-doc.md")
      File.write!(new_doc_path, """
      ---
      title: "New Document"
      category: "user"
      ---
      # New Document
      This is a newly added document.
      """)
      
      # Rescan and reindex
      new_scan_result = Scanner.scan_directory(@test_docs_dir)
      new_search_index = Engine.index_from_scan_result(new_scan_result)
      
      assert length(new_scan_result.files) == initial_nav_count + 1
      assert new_search_index.document_count == initial_search_count + 1
      
      # New document should be searchable
      {:ok, engine_pid} = Engine.start_link(scan_result: new_scan_result)
      results = Engine.search(engine_pid, "newly added")
      assert length(results) == 1
      assert hd(results).title == "New Document"
    end

    test "search results include navigation metadata" do
      scan_result = Scanner.scan_directory(@test_docs_dir)
      {:ok, engine_pid} = Engine.start_link(scan_result: scan_result)
      
      results = Engine.search(engine_pid, "phoenix")
      
      assert length(results) > 0
      
      # Each result should have navigation metadata
      for result <- results do
        assert Map.has_key?(result, :path)
        assert Map.has_key?(result, :category)
        assert Map.has_key?(result, :breadcrumbs)
        assert Map.has_key?(result, :snippet)
        
        # Breadcrumbs should be properly formatted
        assert is_list(result.breadcrumbs)
        assert hd(result.breadcrumbs) == %{title: "Home", path: "/"}
      end
    end

    test "category filtering works with navigation structure" do
      scan_result = Scanner.scan_directory(@test_docs_dir)
      search_index = Engine.index_from_scan_result(scan_result)
      
      # Search in specific category
      dev_results = Index.search(search_index, "guide", category: "dev")
      user_results = Index.search(search_index, "guide", category: "user")
      
      # Results should be properly filtered
      assert Enum.all?(dev_results, &(&1.category == "dev"))
      assert Enum.all?(user_results, &(&1.category == "user"))
      
      # Should match navigation category counts
      dev_files = Enum.filter(scan_result.files, &(&1.category == "dev"))
      user_files = Enum.filter(scan_result.files, &(&1.category == "user"))
      
      dev_guides = Enum.filter(dev_files, &String.contains?(&1.title, "Guide"))
      user_guides = Enum.filter(user_files, &String.contains?(&1.title, "Guide"))
      
      assert length(dev_results) <= length(dev_guides)
      assert length(user_results) <= length(user_guides)
    end
  end

  describe "real-time updates" do
    test "updates search index when document changes" do
      scan_result = Scanner.scan_directory(@test_docs_dir)
      {:ok, engine_pid} = Engine.start_link(scan_result: scan_result)
      
      # Initial search
      results = Engine.search(engine_pid, "Phoenix Framework")
      initial_count = length(results)
      
      # Modify a document
      doc_path = Path.join(@test_docs_dir, "user/getting-started.md")
      File.write!(doc_path, """
      ---
      title: "Getting Started with Phoenix Framework"
      category: "user"
      ---
      # Getting Started
      This guide covers Phoenix Framework basics and advanced topics.
      """)
      
      # Notify engine of change
      Engine.update_document(engine_pid, doc_path)
      
      # Search again
      new_results = Engine.search(engine_pid, "Phoenix Framework")
      
      # Should find updated content
      assert length(new_results) >= initial_count
      assert Enum.any?(new_results, &String.contains?(&1.content, "advanced topics"))
    end

    test "handles document deletion" do
      scan_result = Scanner.scan_directory(@test_docs_dir)
      {:ok, engine_pid} = Engine.start_link(scan_result: scan_result)
      
      # Verify document exists in search
      results = Engine.search(engine_pid, "API Documentation")
      assert length(results) > 0
      
      # Delete document
      doc_path = Path.join(@test_docs_dir, "dev/api-docs.md")
      File.rm!(doc_path)
      
      # Notify engine (need to use the document ID, not path)
      doc_id = file_id_from_path(doc_path)
      Engine.remove_document(engine_pid, doc_id)
      
      # Should no longer find deleted document
      new_results = Engine.search(engine_pid, "API Documentation")
      assert length(new_results) == 0
    end

    test "batch updates for performance" do
      scan_result = Scanner.scan_directory(@test_docs_dir)
      {:ok, engine_pid} = Engine.start_link(scan_result: scan_result)
      
      # Add multiple documents at once
      new_docs = for i <- 1..10 do
        path = Path.join(@test_docs_dir, "batch-doc-#{i}.md")
        content = """
        ---
        title: "Batch Document #{i}"
        category: "user"
        ---
        # Batch Document #{i}
        Content for batch document number #{i}.
        """
        File.write!(path, content)
        path
      end
      
      # Batch update
      Engine.batch_update(engine_pid, new_docs)
      
      # All new documents should be searchable
      results = Engine.search(engine_pid, "batch document")
      assert length(results) == 10
    end
  end

  describe "search quality" do
    test "ranks exact title matches highest" do
      scan_result = Scanner.scan_directory(@test_docs_dir)
      search_index = Engine.index_from_scan_result(scan_result)
      
      results = Index.search(search_index, "Phoenix Guide")
      
      assert length(results) > 0
      
      # First result should be exact title match
      first_result = hd(results)
      assert first_result.title == "Phoenix Guide"
    end

    test "handles typos and fuzzy matching" do
      scan_result = Scanner.scan_directory(@test_docs_dir)
      search_index = Engine.index_from_scan_result(scan_result)
      
      # Search with typo
      results = Index.search(search_index, "pheonix", fuzzy: true)
      
      # Should still find Phoenix documents
      assert length(results) > 0
      assert Enum.any?(results, &String.contains?(String.downcase(&1.title), "phoenix"))
    end

    test "provides relevant snippets" do
      scan_result = Scanner.scan_directory(@test_docs_dir)
      {:ok, engine_pid} = Engine.start_link(scan_result: scan_result)
      
      results = Engine.search(engine_pid, "build web applications")
      
      assert length(results) > 0
      
      # Each result should have a relevant snippet
      for result <- results do
        assert Map.has_key?(result, :snippet)
        assert String.length(result.snippet) > 0
        assert String.length(result.snippet) <= 200  # Reasonable snippet length
        
        # Snippet should contain at least one search term
        assert String.contains?(String.downcase(result.snippet), "build") or
               String.contains?(String.downcase(result.snippet), "web") or
               String.contains?(String.downcase(result.snippet), "applications")
      end
    end
  end

  # Helper functions

  defp create_test_documents do
    documents = [
      {Path.join(@test_docs_dir, "user/getting-started.md"), """
      ---
      title: "Getting Started"
      category: "user"
      tags: ["beginner", "tutorial"]
      ---
      # Getting Started
      Learn how to build web applications with Phoenix.
      """},
      
      {Path.join(@test_docs_dir, "user/phoenix-guide.md"), """
      ---
      title: "Phoenix Guide"
      category: "user"
      tags: ["phoenix", "guide"]
      ---
      # Phoenix Guide
      Complete guide to Phoenix framework features.
      """},
      
      {Path.join(@test_docs_dir, "dev/api-docs.md"), """
      ---
      title: "API Documentation"
      category: "dev"
      tags: ["api", "reference"]
      ---
      # API Documentation
      Technical API reference for developers.
      """},
      
      {Path.join(@test_docs_dir, "dev/architecture.md"), """
      ---
      title: "Architecture Guide"
      category: "dev"
      tags: ["architecture", "guide"]
      ---
      # Architecture Guide
      Understanding the Phoenix application architecture.
      """}
    ]
    
    for {path, content} <- documents do
      File.write!(path, content)
    end
  end

  defp file_id_from_path(file_path) do
    file_path
    |> Path.basename(".md")
    |> String.replace("-", "_")
  end
end