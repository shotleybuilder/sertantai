defmodule SertantaiDocs.Search.Ranking do
  @moduledoc """
  Search result ranking and scoring functionality.
  
  Implements TF-IDF scoring with field weighting and
  additional ranking factors like recency.
  """

  @title_weight 3.0
  @tag_weight 2.0
  @content_weight 1.0
  @recency_boost_days 30

  @doc """
  Calculates TF-IDF score for a document given query terms.
  
  Takes into account:
  - Term frequency in different fields (title, content, tags)
  - Inverse document frequency
  - Field weights (title > tags > content)
  """
  def calculate_score(document, query_terms, df_map, total_docs) do
    Enum.reduce(query_terms, 0.0, fn term, acc ->
      # Calculate term frequency in each field
      tf_content = count_term_frequency(document.content_terms, term)
      tf_title = count_term_frequency(document.title_terms, term)
      tf_tags = count_term_frequency(document.tag_terms, term)
      
      # Apply field weights
      weighted_tf = 
        (tf_content * @content_weight) +
        (tf_title * @title_weight) +
        (tf_tags * @tag_weight)
      
      if weighted_tf > 0 do
        # Calculate IDF
        doc_frequency = Map.get(df_map, term, 1)
        idf = :math.log((total_docs + 1) / (doc_frequency + 1))
        
        # Add TF-IDF score for this term
        acc + (weighted_tf * idf)
      else
        acc
      end
    end)
  end

  @doc """
  Sorts documents by relevance score in descending order.
  
  Options:
  - :limit - maximum number of results to return
  """
  def sort_by_relevance(documents, opts \\ []) do
    limit = Keyword.get(opts, :limit, length(documents))
    
    documents
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Boosts score for recently modified content.
  
  Documents modified within the boost window get higher scores.
  """
  def boost_recent_content(document, reference_time \\ DateTime.utc_now()) do
    case Map.get(document, :last_modified) do
      nil ->
        document
      
      last_modified ->
        days_old = DateTime.diff(reference_time, last_modified, :day)
        
        boost_factor = if days_old <= @recency_boost_days do
          # Linear decay from 1.5x to 1.0x over the boost period
          1.5 - (0.5 * days_old / @recency_boost_days)
        else
          1.0
        end
        
        Map.update!(document, :score, &(&1 * boost_factor))
    end
  end

  @doc """
  Provides detailed explanation of how a document's score was calculated.
  
  Useful for debugging and understanding search rankings.
  """
  def explain_score(document, query_terms, df_map, total_docs) do
    term_scores = 
      Enum.reduce(query_terms, %{}, fn term, acc ->
        tf_content = count_term_frequency(document.content_terms, term)
        tf_title = count_term_frequency(document.title_terms, term)
        tf_tags = count_term_frequency(document.tag_terms, term)
        
        doc_frequency = Map.get(df_map, term, 1)
        idf = :math.log((total_docs + 1) / (doc_frequency + 1))
        
        term_breakdown = %{
          content_tf: tf_content,
          title_tf: tf_title,
          tags_tf: tf_tags,
          idf: idf,
          content_score: tf_content * @content_weight * idf,
          title_score: tf_title * @title_weight * idf,
          tags_score: tf_tags * @tag_weight * idf,
          total: (tf_content * @content_weight + 
                 tf_title * @title_weight + 
                 tf_tags * @tag_weight) * idf
        }
        
        Map.put(acc, term, term_breakdown)
      end)
    
    total_score = 
      term_scores
      |> Map.values()
      |> Enum.map(& &1.total)
      |> Enum.sum()
    
    field_contributions = %{
      title: calculate_field_contribution(term_scores, :title_score),
      content: calculate_field_contribution(term_scores, :content_score),
      tags: calculate_field_contribution(term_scores, :tags_score)
    }
    
    %{
      total_score: total_score,
      term_scores: term_scores,
      field_contributions: field_contributions,
      document: %{
        id: document.id,
        title: document.title
      }
    }
  end

  # Private functions

  defp count_term_frequency(terms, term) do
    Enum.count(terms, &(&1 == term))
  end

  defp calculate_field_contribution(term_scores, field) do
    term_scores
    |> Map.values()
    |> Enum.map(&Map.get(&1, field, 0))
    |> Enum.sum()
  end
end