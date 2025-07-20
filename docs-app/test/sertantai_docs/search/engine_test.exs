defmodule SertantaiDocs.Search.EngineTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.Search.Engine

  setup do
    # Sample data for testing
    scan_result = %{
      files: [
        %{
          id: "intro",
          title: "Introduction",
          path: "/intro",
          file_path: "intro.md",
          category: "root",
          priority: 1,
          tags: ["intro"]
        },
        %{
          id: "guide",
          title: "User Guide",
          path: "/guide",
          file_path: "guide.md",
          category: "user",
          priority: 2,
          tags: ["guide", "user"]
        }
      ],
      categories: %{
        "user" => %{
          title: "User Documentation",
          path: "/user",
          files: []
        }
      }
    }
    
    {:ok, scan_result: scan_result}
  end

  describe "start_link/1" do
    test "starts the search engine with initial scan result", %{scan_result: scan_result} do
      {:ok, pid} = Engine.start_link(scan_result: scan_result)
      
      assert Process.alive?(pid)
      
      # Should be able to search immediately
      results = Engine.search(pid, "introduction")
      assert length(results) == 1
      assert hd(results).id == "intro"
    end

    test "registers with a name when provided" do
      {:ok, _pid} = Engine.start_link(
        name: :test_search_engine,
        scan_result: %{files: [], categories: %{}}
      )
      
      # Should be able to access by name
      assert Process.whereis(:test_search_engine) != nil
    end
  end

  describe "search/3" do
    setup %{scan_result: scan_result} do
      {:ok, pid} = Engine.start_link(scan_result: scan_result)
      {:ok, engine: pid}
    end

    test "performs basic search", %{engine: engine} do
      results = Engine.search(engine, "user")
      
      assert length(results) == 1
      assert hd(results).title == "User Guide"
    end

    test "searches with filters", %{engine: engine} do
      results = Engine.search(engine, "guide", category: "user")
      
      assert length(results) == 1
      assert hd(results).category == "user"
      
      # Non-matching category
      results = Engine.search(engine, "guide", category: "dev")
      assert length(results) == 0
    end

    test "returns empty list for no matches", %{engine: engine} do
      results = Engine.search(engine, "nonexistent")
      
      assert results == []
    end

    test "handles concurrent searches", %{engine: engine} do
      # Launch multiple concurrent searches
      tasks = for query <- ["user", "guide", "intro", "documentation"] do
        Task.async(fn -> Engine.search(engine, query) end)
      end
      
      results = Task.await_many(tasks)
      
      # All searches should complete successfully
      assert Enum.all?(results, &is_list/1)
    end
  end

  describe "update_document/2" do
    setup %{scan_result: scan_result} do
      {:ok, pid} = Engine.start_link(scan_result: scan_result)
      {:ok, engine: pid}
    end

    test "updates existing document", %{engine: engine} do
      # Initial search
      results = Engine.search(engine, "introduction")
      assert length(results) == 1
      old_content = hd(results)
      
      # Update document
      updated_doc = %{
        id: "intro",
        title: "Introduction Updated",
        content: "New introduction content with different terms",
        path: "/intro",
        file_path: "intro.md",
        category: "root",
        tags: ["intro", "updated"]
      }
      
      :ok = Engine.update_document(engine, updated_doc)
      
      # Search with new terms
      new_results = Engine.search(engine, "updated")
      assert length(new_results) == 1
      assert hd(new_results).title == "Introduction Updated"
      
      # Old terms might not match as strongly
      old_results = Engine.search(engine, "introduction")
      assert hd(old_results).title == "Introduction Updated"
    end

    test "adds new document", %{engine: engine} do
      new_doc = %{
        id: "new-doc",
        title: "New Documentation",
        content: "This is a brand new document",
        path: "/new-doc",
        file_path: "new-doc.md",
        category: "user",
        tags: ["new"]
      }
      
      :ok = Engine.update_document(engine, new_doc)
      
      # Should find the new document
      results = Engine.search(engine, "brand new")
      assert length(results) == 1
      assert hd(results).id == "new-doc"
    end
  end

  describe "remove_document/2" do
    setup %{scan_result: scan_result} do
      {:ok, pid} = Engine.start_link(scan_result: scan_result)
      {:ok, engine: pid}
    end

    test "removes document from index", %{engine: engine} do
      # Verify document exists
      results = Engine.search(engine, "introduction")
      assert length(results) == 1
      
      # Remove document
      :ok = Engine.remove_document(engine, "intro")
      
      # Should no longer find it
      new_results = Engine.search(engine, "introduction")
      assert length(new_results) == 0
    end

    test "handles removing non-existent document", %{engine: engine} do
      # Should not crash
      :ok = Engine.remove_document(engine, "non-existent-id")
      
      # Search should still work
      results = Engine.search(engine, "user")
      assert length(results) == 1
    end
  end

  describe "batch_update/2" do
    setup %{scan_result: scan_result} do
      {:ok, pid} = Engine.start_link(scan_result: scan_result)
      {:ok, engine: pid}
    end

    test "updates multiple documents efficiently", %{engine: engine} do
      updates = [
        %{
          id: "doc1",
          title: "Document One",
          content: "First batch document",
          path: "/doc1",
          file_path: "doc1.md",
          category: "batch",
          tags: ["batch"]
        },
        %{
          id: "doc2",
          title: "Document Two",
          content: "Second batch document",
          path: "/doc2",
          file_path: "doc2.md",
          category: "batch",
          tags: ["batch"]
        },
        %{
          id: "doc3",
          title: "Document Three",
          content: "Third batch document",
          path: "/doc3",
          file_path: "doc3.md",
          category: "batch",
          tags: ["batch"]
        }
      ]
      
      :ok = Engine.batch_update(engine, updates)
      
      # All documents should be searchable
      results = Engine.search(engine, "batch document")
      assert length(results) == 3
      
      # Should be findable individually by unique terms
      results = Engine.search(engine, "One")
      assert length(results) == 1
      assert hd(results).title == "Document One"
      
      results = Engine.search(engine, "Two")
      assert length(results) == 1
      assert hd(results).title == "Document Two"
      
      results = Engine.search(engine, "Three")
      assert length(results) == 1
      assert hd(results).title == "Document Three"
    end
  end

  describe "get_stats/1" do
    setup %{scan_result: scan_result} do
      {:ok, pid} = Engine.start_link(scan_result: scan_result)
      {:ok, engine: pid}
    end

    test "returns search engine statistics", %{engine: engine} do
      stats = Engine.get_stats(engine)
      
      assert is_map(stats)
      assert stats.document_count == 2
      assert stats.total_terms > 0
      assert Map.has_key?(stats, :index_size)
      assert Map.has_key?(stats, :last_updated)
    end

    test "updates stats after document changes", %{engine: engine} do
      initial_stats = Engine.get_stats(engine)
      
      # Add a document
      new_doc = %{
        id: "new",
        title: "New",
        content: "New content",
        path: "/new",
        file_path: "new.md",
        category: "test",
        tags: []
      }
      
      Engine.update_document(engine, new_doc)
      
      updated_stats = Engine.get_stats(engine)
      
      assert updated_stats.document_count == initial_stats.document_count + 1
      assert updated_stats.total_terms >= initial_stats.total_terms
    end
  end

  describe "rebuild_index/2" do
    setup %{scan_result: scan_result} do
      {:ok, pid} = Engine.start_link(scan_result: scan_result)
      {:ok, engine: pid}
    end

    test "rebuilds index with new scan result", %{engine: engine} do
      # Add some documents first
      Engine.update_document(engine, %{
        id: "temp",
        title: "Temporary",
        content: "Will be gone",
        path: "/temp",
        file_path: "temp.md",
        category: "temp",
        tags: []
      })
      
      # Verify it exists
      results = Engine.search(engine, "temporary")
      assert length(results) == 1
      
      # Rebuild with fresh scan result
      new_scan_result = %{
        files: [
          %{
            id: "fresh",
            title: "Fresh Document",
            content: "Brand new index",
            path: "/fresh",
            file_path: "fresh.md",
            category: "new",
            tags: ["fresh"]
          }
        ],
        categories: %{}
      }
      
      :ok = Engine.rebuild_index(engine, new_scan_result)
      
      # Old documents should be gone
      old_results = Engine.search(engine, "temporary")
      assert length(old_results) == 0
      
      # New documents should be present
      new_results = Engine.search(engine, "fresh")
      assert length(new_results) == 1
    end
  end

  # Helper functions
  
  defp number_word(1), do: "One"
  defp number_word(2), do: "Two"
  defp number_word(3), do: "Three"
end