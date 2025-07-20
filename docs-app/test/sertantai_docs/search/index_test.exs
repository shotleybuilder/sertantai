defmodule SertantaiDocs.Search.IndexTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.Search.Index

  describe "build_index/1" do
    test "builds empty index from empty file list" do
      files = []
      
      index = Index.build_index(files)
      
      assert index == %{
        documents: %{},
        terms: %{},
        document_count: 0
      }
    end

    test "indexes single document with title and content" do
      files = [
        %{
          id: "getting-started",
          title: "Getting Started Guide",
          content: "This guide helps you get started with Phoenix",
          path: "/getting-started",
          category: "user",
          tags: ["beginner", "setup"]
        }
      ]
      
      index = Index.build_index(files)
      
      assert index.document_count == 1
      assert Map.has_key?(index.documents, "getting-started")
      
      doc = index.documents["getting-started"]
      assert doc.title == "Getting Started Guide"
      assert doc.path == "/getting-started"
      
      # Check that terms are indexed
      assert Map.has_key?(index.terms, "getting")
      assert Map.has_key?(index.terms, "started")
      assert Map.has_key?(index.terms, "guide")
      assert Map.has_key?(index.terms, "phoenix")
    end

    test "indexes multiple documents" do
      files = [
        %{
          id: "installation",
          title: "Installation Guide",
          content: "How to install Phoenix framework",
          path: "/installation",
          category: "dev",
          tags: ["setup"]
        },
        %{
          id: "configuration",
          title: "Configuration",
          content: "Configure your Phoenix application",
          path: "/configuration",
          category: "dev",
          tags: ["config"]
        }
      ]
      
      index = Index.build_index(files)
      
      assert index.document_count == 2
      assert Map.keys(index.documents) |> Enum.sort() == ["configuration", "installation"]
      
      # Check term indexing across documents
      assert "installation" in index.terms["phoenix"]
      assert "configuration" in index.terms["phoenix"]
    end

    test "handles special characters and case sensitivity" do
      files = [
        %{
          id: "elixir-basics",
          title: "Elixir Basics: Pattern-Matching & Pipes",
          content: "Learn about Elixir's pattern-matching and |> pipe operator",
          path: "/elixir-basics",
          category: "dev",
          tags: []
        }
      ]
      
      index = Index.build_index(files)
      
      # Should lowercase and handle special chars
      assert Map.has_key?(index.terms, "elixir")
      assert Map.has_key?(index.terms, "pattern")
      assert Map.has_key?(index.terms, "matching")
      assert Map.has_key?(index.terms, "pipes")
      assert Map.has_key?(index.terms, "operator")
    end

    test "indexes tags as searchable terms" do
      files = [
        %{
          id: "testing",
          title: "Testing Guide",
          content: "How to write tests",
          path: "/testing",
          category: "dev",
          tags: ["testing", "exunit", "tdd"]
        }
      ]
      
      index = Index.build_index(files)
      
      # Tags should be indexed
      assert Map.has_key?(index.terms, "testing")
      assert Map.has_key?(index.terms, "exunit")
      assert Map.has_key?(index.terms, "tdd")
      assert "testing" in index.terms["testing"]
    end
  end

  describe "search/2" do
    setup do
      files = [
        %{
          id: "phoenix-intro",
          title: "Introduction to Phoenix",
          content: "Phoenix is a web framework for Elixir",
          path: "/phoenix-intro",
          category: "dev",
          tags: ["phoenix", "intro"]
        },
        %{
          id: "phoenix-channels",
          title: "Phoenix Channels for Phoenix",
          content: "Real-time features with Phoenix Channels and WebSockets using Phoenix",
          path: "/phoenix-channels",
          category: "dev",
          tags: ["phoenix", "channels", "websocket"]
        },
        %{
          id: "ecto-basics",
          title: "Ecto Basics",
          content: "Database queries with Ecto in Elixir",
          path: "/ecto-basics",
          category: "dev",
          tags: ["ecto", "database"]
        }
      ]
      
      index = Index.build_index(files)
      {:ok, index: index}
    end

    test "finds documents by single term", %{index: index} do
      results = Index.search(index, "phoenix")
      
      assert length(results) == 2
      assert Enum.all?(results, &String.contains?(&1.id, "phoenix"))
    end

    test "finds documents by multiple terms", %{index: index} do
      results = Index.search(index, "phoenix channels")
      
      assert length(results) == 2
      # Phoenix channels doc should rank higher
      assert hd(results).id == "phoenix-channels"
    end

    test "returns empty list for non-existent terms", %{index: index} do
      results = Index.search(index, "nonexistent")
      
      assert results == []
    end

    test "handles case-insensitive search", %{index: index} do
      results1 = Index.search(index, "PHOENIX")
      results2 = Index.search(index, "phoenix")
      results3 = Index.search(index, "Phoenix")
      
      assert results1 == results2
      assert results2 == results3
    end

    test "searches in titles, content, and tags", %{index: index} do
      # Search by title word
      results = Index.search(index, "introduction")
      assert length(results) == 1
      assert hd(results).id == "phoenix-intro"
      
      # Search by content word
      results = Index.search(index, "websockets")
      assert length(results) == 1
      assert hd(results).id == "phoenix-channels"
      
      # Search by tag
      results = Index.search(index, "database")
      assert length(results) == 1
      assert hd(results).id == "ecto-basics"
    end

    test "ranks results by relevance", %{index: index} do
      results = Index.search(index, "phoenix")
      
      # Both results contain "phoenix", but should be ranked by frequency
      assert length(results) == 2
      
      # The document with more occurrences should rank higher
      [first, second] = results
      assert first.score > second.score
    end
  end

  describe "update_index/3" do
    test "adds new document to existing index" do
      initial_files = [
        %{
          id: "doc1",
          title: "Document 1",
          content: "Content 1",
          path: "/doc1",
          category: "test",
          tags: []
        }
      ]
      
      index = Index.build_index(initial_files)
      assert index.document_count == 1
      
      new_doc = %{
        id: "doc2",
        title: "Document 2",
        content: "Content 2",
        path: "/doc2",
        category: "test",
        tags: []
      }
      
      updated_index = Index.update_index(index, :add, new_doc)
      
      assert updated_index.document_count == 2
      assert Map.has_key?(updated_index.documents, "doc2")
    end

    test "removes document from index" do
      files = [
        %{
          id: "doc1",
          title: "Document 1",
          content: "Content 1",
          path: "/doc1",
          category: "test",
          tags: []
        },
        %{
          id: "doc2",
          title: "Document 2",
          content: "Content 2",
          path: "/doc2",
          category: "test",
          tags: []
        }
      ]
      
      index = Index.build_index(files)
      assert index.document_count == 2
      
      updated_index = Index.update_index(index, :remove, "doc1")
      
      assert updated_index.document_count == 1
      refute Map.has_key?(updated_index.documents, "doc1")
      assert Map.has_key?(updated_index.documents, "doc2")
    end

    test "updates existing document" do
      files = [
        %{
          id: "doc1",
          title: "Old Title",
          content: "Old content",
          path: "/doc1",
          category: "test",
          tags: []
        }
      ]
      
      index = Index.build_index(files)
      
      updated_doc = %{
        id: "doc1",
        title: "New Title",
        content: "New content with different terms",
        path: "/doc1",
        category: "test",
        tags: ["updated"]
      }
      
      updated_index = Index.update_index(index, :update, updated_doc)
      
      assert updated_index.document_count == 1
      assert updated_index.documents["doc1"].title == "New Title"
      
      # Old terms should be removed, new terms added
      refute Map.has_key?(updated_index.terms, "old")
      assert Map.has_key?(updated_index.terms, "new")
      assert Map.has_key?(updated_index.terms, "different")
    end
  end

  describe "search with filters" do
    setup do
      files = [
        %{
          id: "user-guide",
          title: "User Guide",
          content: "Guide for end users",
          path: "/user-guide",
          category: "user",
          tags: ["guide", "beginner"]
        },
        %{
          id: "dev-guide",
          title: "Developer Guide",
          content: "Guide for developers",
          path: "/dev-guide",
          category: "dev",
          tags: ["guide", "advanced"]
        },
        %{
          id: "api-guide",
          title: "API Guide",
          content: "Guide for API usage",
          path: "/api-guide",
          category: "api",
          tags: ["guide", "reference"]
        }
      ]
      
      index = Index.build_index(files)
      {:ok, index: index}
    end

    test "filters by category", %{index: index} do
      results = Index.search(index, "guide", category: "dev")
      
      assert length(results) == 1
      assert hd(results).id == "dev-guide"
    end

    test "filters by multiple categories", %{index: index} do
      results = Index.search(index, "guide", category: ["dev", "api"])
      
      assert length(results) == 2
      assert Enum.all?(results, &(&1.category in ["dev", "api"]))
    end

    test "filters by tags", %{index: index} do
      results = Index.search(index, "guide", tags: ["advanced"])
      
      assert length(results) == 1
      assert hd(results).id == "dev-guide"
    end

    test "combines multiple filters", %{index: index} do
      results = Index.search(index, "guide", category: "user", tags: ["beginner"])
      
      assert length(results) == 1
      assert hd(results).id == "user-guide"
    end
  end

  describe "performance" do
    test "handles large document sets efficiently" do
      # Generate 1000 documents
      files = for i <- 1..1000 do
        %{
          id: "doc-#{i}",
          title: "Document #{i} about Elixir and Phoenix",
          content: "This is document number #{i} with content about web development",
          path: "/doc-#{i}",
          category: Enum.random(["dev", "user", "api"]),
          tags: Enum.take_random(["elixir", "phoenix", "ecto", "liveview", "tutorial"], 2)
        }
      end
      
      # Building index should be reasonably fast
      {time, index} = :timer.tc(fn -> Index.build_index(files) end)
      assert time < 1_000_000  # Less than 1 second
      assert index.document_count == 1000
      
      # Searching should be fast
      {search_time, results} = :timer.tc(fn -> Index.search(index, "elixir phoenix") end)
      assert search_time < 100_000  # Less than 100ms
      assert length(results) > 0
    end
  end
end