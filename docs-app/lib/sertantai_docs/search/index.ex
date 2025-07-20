defmodule SertantaiDocs.Search.Index do
  @moduledoc """
  Search index implementation for documentation.
  
  Provides full-text search with term frequency indexing,
  filtering capabilities, and index management.
  """

  @doc """
  Builds a search index from a list of documents.
  
  Returns a map containing:
  - :documents - map of document ID to document data
  - :terms - inverted index of terms to document IDs
  - :document_count - total number of documents
  """
  def build_index(files) do
    documents = 
      files
      |> Enum.map(fn file ->
        {file.id, process_document(file)}
      end)
      |> Map.new()
    
    terms = build_term_index(documents)
    
    %{
      documents: documents,
      terms: terms,
      document_count: map_size(documents)
    }
  end

  @doc """
  Searches the index for documents matching the query.
  
  Options:
  - :category - filter by category (string or list)
  - :tags - filter by tags
  - :fuzzy - enable fuzzy matching
  """
  def search(index, query, opts \\ []) do
    query_terms = tokenize(query)
    
    if Enum.empty?(query_terms) do
      []
    else
      index.documents
      |> find_matching_documents(index.terms, query_terms, opts[:fuzzy] || false)
      |> apply_filters(opts)
      |> calculate_scores(query_terms, index)
      |> Enum.sort_by(& &1.score, :desc)
    end
  end

  @doc """
  Updates the index with a document operation.
  
  Operations:
  - :add - adds a new document
  - :remove - removes a document by ID
  - :update - updates an existing document
  """
  def update_index(index, :add, document) do
    processed_doc = process_document(document)
    
    updated_documents = Map.put(index.documents, document.id, processed_doc)
    updated_terms = update_term_index(index.terms, nil, processed_doc)
    
    %{
      documents: updated_documents,
      terms: updated_terms,
      document_count: map_size(updated_documents)
    }
  end

  def update_index(index, :remove, document_id) do
    case Map.get(index.documents, document_id) do
      nil ->
        index
      
      old_doc ->
        updated_documents = Map.delete(index.documents, document_id)
        updated_terms = update_term_index(index.terms, old_doc, nil)
        
        %{
          documents: updated_documents,
          terms: updated_terms,
          document_count: map_size(updated_documents)
        }
    end
  end

  def update_index(index, :update, document) do
    old_doc = Map.get(index.documents, document.id)
    processed_doc = process_document(document)
    
    updated_documents = Map.put(index.documents, document.id, processed_doc)
    updated_terms = update_term_index(index.terms, old_doc, processed_doc)
    
    %{
      documents: updated_documents,
      terms: updated_terms,
      document_count: map_size(updated_documents)
    }
  end

  # Private functions

  defp process_document(file) do
    content = Map.get(file, :content, "")
    
    Map.merge(file, %{
      content_terms: tokenize_with_frequency(content),
      title_terms: tokenize_with_frequency(file.title),
      tag_terms: Enum.flat_map(file.tags, &tokenize_with_frequency/1)
    })
  end

  defp tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, " ")  # Remove hyphens from the preserved chars
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp tokenize(_), do: []
  
  defp tokenize_with_frequency(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, " ")
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 == ""))
    # Don't use uniq - keep all occurrences for frequency counting
  end
  
  defp tokenize_with_frequency(_), do: []

  defp build_term_index(documents) do
    Enum.reduce(documents, %{}, fn {doc_id, doc}, term_index ->
      all_terms = doc.content_terms ++ doc.title_terms ++ doc.tag_terms
      unique_terms = Enum.uniq(all_terms)
      
      Enum.reduce(unique_terms, term_index, fn term, acc ->
        Map.update(acc, term, [doc_id], fn existing ->
          if doc_id in existing, do: existing, else: [doc_id | existing]
        end)
      end)
    end)
  end

  defp update_term_index(term_index, old_doc, new_doc) do
    # Remove old document terms
    term_index = if old_doc do
      old_terms = old_doc.content_terms ++ old_doc.title_terms ++ old_doc.tag_terms
      unique_old_terms = Enum.uniq(old_terms)
      
      Enum.reduce(unique_old_terms, term_index, fn term, acc ->
        case Map.get(acc, term) do
          nil -> acc
          doc_ids ->
            updated_ids = List.delete(doc_ids, old_doc.id)
            if Enum.empty?(updated_ids) do
              Map.delete(acc, term)
            else
              Map.put(acc, term, updated_ids)
            end
        end
      end)
    else
      term_index
    end
    
    # Add new document terms
    if new_doc do
      new_terms = new_doc.content_terms ++ new_doc.title_terms ++ new_doc.tag_terms
      unique_new_terms = Enum.uniq(new_terms)
      
      Enum.reduce(unique_new_terms, term_index, fn term, acc ->
        Map.update(acc, term, [new_doc.id], fn existing ->
          if new_doc.id in existing, do: existing, else: [new_doc.id | existing]
        end)
      end)
    else
      term_index
    end
  end

  defp find_matching_documents(documents, terms_index, query_terms, fuzzy \\ false) do
    # Find all document IDs that contain any query term
    matching_ids = 
      query_terms
      |> Enum.flat_map(fn term ->
        exact_matches = Map.get(terms_index, term, [])
        
        if fuzzy do
          # Add fuzzy matches
          fuzzy_matches = find_fuzzy_matches(terms_index, term)
          exact_matches ++ fuzzy_matches
        else
          exact_matches
        end
      end)
      |> Enum.uniq()
    
    # Return the actual documents
    matching_ids
    |> Enum.map(fn id -> Map.get(documents, id) end)
    |> Enum.reject(&is_nil/1)
  end

  defp apply_filters(documents, opts) do
    documents
    |> filter_by_category(opts[:category])
    |> filter_by_tags(opts[:tags])
  end

  defp filter_by_category(documents, nil), do: documents
  defp filter_by_category(documents, category) when is_binary(category) do
    Enum.filter(documents, &(&1.category == category))
  end
  defp filter_by_category(documents, categories) when is_list(categories) do
    Enum.filter(documents, &(&1.category in categories))
  end

  defp filter_by_tags(documents, nil), do: documents
  defp filter_by_tags(documents, tags) when is_list(tags) do
    Enum.filter(documents, fn doc ->
      Enum.any?(tags, &(&1 in doc.tags))
    end)
  end

  defp calculate_scores(documents, query_terms, index) do
    total_docs = index.document_count
    
    # Build document frequency map for query terms
    df_map = 
      query_terms
      |> Enum.map(fn term ->
        doc_count = length(Map.get(index.terms, term, []))
        {term, doc_count}
      end)
      |> Map.new()
    
    # Calculate score for each document
    Enum.map(documents, fn doc ->
      score = calculate_document_score(doc, query_terms, df_map, total_docs)
      Map.put(doc, :score, score)
    end)
  end

  defp calculate_document_score(doc, query_terms, df_map, total_docs) do
    Enum.reduce(query_terms, 0.0, fn term, acc ->
      # Term frequency in different fields
      tf_content = count_occurrences(doc.content_terms, term)
      tf_title = count_occurrences(doc.title_terms, term)
      tf_tags = count_occurrences(doc.tag_terms, term)
      
      # Weighted term frequency (title > tags > content)
      weighted_tf = (tf_content * 1.0) + (tf_title * 3.0) + (tf_tags * 2.0)
      
      if weighted_tf > 0 do
        # IDF calculation
        doc_freq = Map.get(df_map, term, 1)
        idf = :math.log(total_docs / doc_freq)
        
        acc + (weighted_tf * idf)
      else
        acc
      end
    end)
  end

  defp count_occurrences(terms, term) do
    Enum.count(terms, &(&1 == term))
  end

  defp find_fuzzy_matches(terms_index, target_term) do
    # Simple fuzzy matching using Levenshtein distance
    terms_index
    |> Map.keys()
    |> Enum.filter(fn term ->
      levenshtein_distance(term, target_term) <= max(1, div(String.length(target_term), 3))
    end)
    |> Enum.flat_map(fn term -> Map.get(terms_index, term, []) end)
  end

  defp levenshtein_distance(s1, s2) do
    s1_len = String.length(s1)
    s2_len = String.length(s2)
    
    # Simple case optimizations
    cond do
      s1_len == 0 -> s2_len
      s2_len == 0 -> s1_len
      s1 == s2 -> 0
      true ->
        # Create initial matrix
        matrix = 
          for i <- 0..s1_len, reduce: %{} do
            acc_i ->
              for j <- 0..s2_len, reduce: acc_i do
                acc_j ->
                  cond do
                    i == 0 -> Map.put(acc_j, {i, j}, j)
                    j == 0 -> Map.put(acc_j, {i, j}, i)
                    true -> Map.put(acc_j, {i, j}, 0)
                  end
              end
          end
        
        # Fill the matrix
        s1_chars = String.graphemes(s1)
        s2_chars = String.graphemes(s2)
        
        result = for i <- 1..s1_len, reduce: matrix do
          acc ->
            for j <- 1..s2_len, reduce: acc do
              matrix_acc ->
                cost = if Enum.at(s1_chars, i - 1) == Enum.at(s2_chars, j - 1), do: 0, else: 1
                
                deletion = matrix_acc[{i - 1, j}] + 1
                insertion = matrix_acc[{i, j - 1}] + 1
                substitution = matrix_acc[{i - 1, j - 1}] + cost
                
                Map.put(matrix_acc, {i, j}, min(min(deletion, insertion), substitution))
            end
        end
        
        result[{s1_len, s2_len}]
    end
  end
end