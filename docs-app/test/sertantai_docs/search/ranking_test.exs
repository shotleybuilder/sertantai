defmodule SertantaiDocs.Search.RankingTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.Search.Ranking

  describe "calculate_score/3" do
    test "calculates basic TF-IDF score" do
      document = %{
        id: "doc1",
        content_terms: ["elixir", "phoenix", "web", "framework", "elixir"],
        title_terms: ["elixir", "guide"],
        tag_terms: ["tutorial"]
      }
      
      query_terms = ["elixir"]
      
      # Document frequency map (how many docs contain each term)
      df_map = %{
        "elixir" => 10,
        "phoenix" => 5,
        "web" => 20,
        "framework" => 15,
        "guide" => 8,
        "tutorial" => 12
      }
      
      total_docs = 100
      
      score = Ranking.calculate_score(document, query_terms, df_map, total_docs)
      
      # Score should be positive since "elixir" appears in the document
      assert score > 0
      
      # Score should reflect that "elixir" appears 3 times (2 in content, 1 in title)
      # and title matches should be weighted higher
      assert score > 1.0
    end

    test "gives higher scores for multiple matching terms" do
      document = %{
        id: "doc1",
        content_terms: ["elixir", "phoenix", "web", "framework"],
        title_terms: ["phoenix", "framework"],
        tag_terms: []
      }
      
      df_map = %{
        "elixir" => 10,
        "phoenix" => 5,
        "web" => 20,
        "framework" => 15
      }
      
      total_docs = 100
      
      score1 = Ranking.calculate_score(document, ["phoenix"], df_map, total_docs)
      score2 = Ranking.calculate_score(document, ["phoenix", "framework"], df_map, total_docs)
      
      # Multiple matching terms should yield higher score
      assert score2 > score1
    end

    test "weights title matches higher than content matches" do
      doc_title_match = %{
        id: "doc1",
        content_terms: ["web", "development"],
        title_terms: ["elixir", "guide"],
        tag_terms: []
      }
      
      doc_content_match = %{
        id: "doc2",
        content_terms: ["elixir", "guide"],
        title_terms: ["web", "development"],
        tag_terms: []
      }
      
      df_map = %{"elixir" => 10, "guide" => 10, "web" => 10, "development" => 10}
      total_docs = 100
      query_terms = ["elixir", "guide"]
      
      score_title = Ranking.calculate_score(doc_title_match, query_terms, df_map, total_docs)
      score_content = Ranking.calculate_score(doc_content_match, query_terms, df_map, total_docs)
      
      # Title matches should score higher
      assert score_title > score_content
    end

    test "weights tag matches appropriately" do
      doc_with_tags = %{
        id: "doc1",
        content_terms: ["content"],
        title_terms: ["title"],
        tag_terms: ["elixir", "phoenix"]
      }
      
      doc_without_tags = %{
        id: "doc2",
        content_terms: ["content", "elixir", "phoenix"],
        title_terms: ["title"],
        tag_terms: []
      }
      
      df_map = %{"elixir" => 10, "phoenix" => 10, "content" => 50, "title" => 50}
      total_docs = 100
      query_terms = ["elixir", "phoenix"]
      
      score_tags = Ranking.calculate_score(doc_with_tags, query_terms, df_map, total_docs)
      score_no_tags = Ranking.calculate_score(doc_without_tags, query_terms, df_map, total_docs)
      
      # Both should have scores, but tag matches are weighted between title and content
      assert score_tags > 0
      assert score_no_tags > 0
    end

    test "handles rare terms with higher IDF scores" do
      document = %{
        id: "doc1",
        content_terms: ["common", "rare"],
        title_terms: [],
        tag_terms: []
      }
      
      df_map = %{
        "common" => 90,  # Appears in 90/100 docs
        "rare" => 2      # Appears in only 2/100 docs
      }
      
      total_docs = 100
      
      score_common = Ranking.calculate_score(document, ["common"], df_map, total_docs)
      score_rare = Ranking.calculate_score(document, ["rare"], df_map, total_docs)
      
      # Rare term should have much higher score due to higher IDF
      assert score_rare > score_common * 2
    end
  end

  describe "sort_by_relevance/2" do
    test "sorts documents by score in descending order" do
      documents = [
        %{id: "doc1", score: 1.5},
        %{id: "doc2", score: 3.0},
        %{id: "doc3", score: 2.0},
        %{id: "doc4", score: 0.5}
      ]
      
      sorted = Ranking.sort_by_relevance(documents, limit: 10)
      
      assert length(sorted) == 4
      assert Enum.map(sorted, & &1.id) == ["doc2", "doc3", "doc1", "doc4"]
      assert Enum.map(sorted, & &1.score) == [3.0, 2.0, 1.5, 0.5]
    end

    test "limits results to specified number" do
      documents = for i <- 1..20, do: %{id: "doc#{i}", score: :rand.uniform()}
      
      sorted = Ranking.sort_by_relevance(documents, limit: 5)
      
      assert length(sorted) == 5
      
      # Verify they are the top 5 by score
      all_sorted = Enum.sort_by(documents, & &1.score, :desc)
      top_5_ids = all_sorted |> Enum.take(5) |> Enum.map(& &1.id)
      result_ids = Enum.map(sorted, & &1.id)
      
      assert result_ids == top_5_ids
    end

    test "handles empty document list" do
      sorted = Ranking.sort_by_relevance([], limit: 10)
      
      assert sorted == []
    end

    test "handles limit larger than document count" do
      documents = [
        %{id: "doc1", score: 1.0},
        %{id: "doc2", score: 2.0}
      ]
      
      sorted = Ranking.sort_by_relevance(documents, limit: 10)
      
      assert length(sorted) == 2
    end
  end

  describe "boost_recent_content/2" do
    test "boosts scores for recent documents" do
      now = DateTime.utc_now()
      
      recent_doc = %{
        id: "recent",
        score: 1.0,
        last_modified: DateTime.add(now, -1, :day)  # 1 day ago
      }
      
      old_doc = %{
        id: "old",
        score: 1.0,
        last_modified: DateTime.add(now, -365, :day)  # 1 year ago
      }
      
      boosted_recent = Ranking.boost_recent_content(recent_doc, now)
      boosted_old = Ranking.boost_recent_content(old_doc, now)
      
      # Recent document should get a higher boost
      assert boosted_recent.score > boosted_old.score
      assert boosted_recent.score > recent_doc.score  # Should be boosted
      assert boosted_old.score >= old_doc.score  # Might get small or no boost
    end

    test "handles missing last_modified date" do
      document = %{id: "doc1", score: 1.0}
      
      boosted = Ranking.boost_recent_content(document, DateTime.utc_now())
      
      # Should not crash and score should remain the same
      assert boosted.score == document.score
    end
  end

  describe "explain_score/3" do
    test "provides detailed scoring explanation" do
      document = %{
        id: "doc1",
        title: "Elixir Phoenix Guide",
        content_terms: ["elixir", "phoenix", "web", "framework", "elixir"],
        title_terms: ["elixir", "phoenix", "guide"],
        tag_terms: ["tutorial", "phoenix"]
      }
      
      query_terms = ["elixir", "phoenix"]
      
      df_map = %{
        "elixir" => 10,
        "phoenix" => 5,
        "web" => 20,
        "framework" => 15,
        "guide" => 8,
        "tutorial" => 12
      }
      
      total_docs = 100
      
      explanation = Ranking.explain_score(document, query_terms, df_map, total_docs)
      
      assert is_map(explanation)
      assert Map.has_key?(explanation, :total_score)
      assert Map.has_key?(explanation, :term_scores)
      assert Map.has_key?(explanation, :field_contributions)
      
      # Should have breakdown for each query term
      assert Map.has_key?(explanation.term_scores, "elixir")
      assert Map.has_key?(explanation.term_scores, "phoenix")
      
      # Should show contributions from different fields
      assert Map.has_key?(explanation.field_contributions, :title)
      assert Map.has_key?(explanation.field_contributions, :content)
      assert Map.has_key?(explanation.field_contributions, :tags)
    end
  end
end