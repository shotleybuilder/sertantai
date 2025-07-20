defmodule SertantaiDocs.Search.Engine do
  @moduledoc """
  GenServer that manages the search index and handles search queries.
  
  Provides real-time search functionality with support for
  document updates, batch operations, and statistics.
  """
  
  use GenServer
  
  alias SertantaiDocs.Search.{Index, Ranking}
  alias SertantaiDocs.Navigation.Builder

  # Client API

  @doc """
  Starts the search engine with an initial scan result.
  
  Options:
  - :scan_result - initial navigation scan result
  - :name - optional process name
  """
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Performs a search query against the index.
  
  Options are passed to Index.search/3
  """
  def search(engine, query, opts \\ []) do
    GenServer.call(engine, {:search, query, opts})
  end

  @doc """
  Updates a document in the index.
  """
  def update_document(engine, document) do
    GenServer.cast(engine, {:update_document, document})
  end

  @doc """
  Removes a document from the index by ID.
  """
  def remove_document(engine, document_id) do
    GenServer.cast(engine, {:remove_document, document_id})
  end

  @doc """
  Updates multiple documents in a single operation.
  """
  def batch_update(engine, documents) do
    GenServer.cast(engine, {:batch_update, documents})
  end

  @doc """
  Gets statistics about the search index.
  """
  def get_stats(engine) do
    GenServer.call(engine, :get_stats)
  end

  @doc """
  Rebuilds the entire index with a new scan result.
  """
  def rebuild_index(engine, scan_result) do
    GenServer.cast(engine, {:rebuild_index, scan_result})
  end

  @doc """
  Builds a search index from a navigation scan result.
  """
  def index_from_scan_result(scan_result) do
    files = prepare_files_for_indexing(scan_result)
    Index.build_index(files)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    scan_result = Keyword.fetch!(opts, :scan_result)
    
    state = %{
      index: index_from_scan_result(scan_result),
      scan_result: scan_result,
      last_updated: DateTime.utc_now()
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:search, query, opts}, _from, state) do
    results = 
      state.index
      |> Index.search(query, opts)
      |> enrich_search_results(state.scan_result)
    
    {:reply, results, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      document_count: state.index.document_count,
      total_terms: map_size(state.index.terms),
      index_size: estimate_index_size(state.index),
      last_updated: state.last_updated
    }
    
    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:update_document, document}, state) do
    prepared_doc = prepare_document_for_indexing(document)
    updated_index = Index.update_index(state.index, :update, prepared_doc)
    
    new_state = %{state | 
      index: updated_index,
      last_updated: DateTime.utc_now()
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_document, document_id}, state) do
    updated_index = Index.update_index(state.index, :remove, document_id)
    
    new_state = %{state | 
      index: updated_index,
      last_updated: DateTime.utc_now()
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:batch_update, documents}, state) do
    updated_index = 
      Enum.reduce(documents, state.index, fn doc, index ->
        prepared_doc = case doc do
          # If it's a string (file path), create a document from it
          path when is_binary(path) ->
            path_to_document(path)
            |> prepare_document_for_indexing()
          
          # If it's already a map/document, use it as is
          _ ->
            prepare_document_for_indexing(doc)
        end
        
        Index.update_index(index, :update, prepared_doc)
      end)
    
    new_state = %{state | 
      index: updated_index,
      last_updated: DateTime.utc_now()
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:rebuild_index, scan_result}, state) do
    new_state = %{
      index: index_from_scan_result(scan_result),
      scan_result: scan_result,
      last_updated: DateTime.utc_now()
    }
    
    {:noreply, new_state}
  end

  # Private functions

  defp prepare_files_for_indexing(scan_result) do
    scan_result.files
    |> Enum.map(&prepare_document_for_indexing/1)
  end

  defp prepare_document_for_indexing(file) do
    # Handle case where file is just a path string
    file = case file do
      path when is_binary(path) ->
        path_to_document(path)
      _ ->
        file
    end
    
    # Extract content from file if needed
    content = case file do
      %{content: content} when is_binary(content) -> 
        content
      %{file_path: path} when is_binary(path) ->
        read_file_content(path)
      _ ->
        ""
    end
    
    %{
      id: file[:id] || generate_doc_id(file),
      title: file[:title] || file["title"] || "",
      content: content,
      path: file[:path] || file["path"] || "",
      file_path: file[:file_path] || file["file_path"] || "",
      category: file[:category] || file["category"] || "uncategorized",
      tags: file[:tags] || file["tags"] || [],
      last_modified: file[:last_modified] || file["last_modified"]
    }
  end

  defp generate_doc_id(file) do
    # Generate ID from file path or title
    source = file[:file_path] || file[:path] || file[:title] || ""
    source
    |> Path.basename(".md")
    |> String.replace("-", "_")
  end

  defp read_file_content(file_path) do
    # Read actual file content for proper indexing
    if File.exists?(file_path) do
      content = File.read!(file_path)
      # Extract just the markdown content, removing frontmatter
      {_frontmatter, body} = extract_frontmatter(content)
      body
    else
      ""
    end
  end
  
  defp path_to_document(file_path) do
    # Create a document map from file path
    content = if File.exists?(file_path) do
      File.read!(file_path)
    else
      ""
    end
    
    # Extract frontmatter if present
    {frontmatter, body} = extract_frontmatter(content)
    
    %{
      id: generate_doc_id(%{file_path: file_path}),
      title: frontmatter["title"] || Path.basename(file_path, ".md"),
      content: body,
      path: "/" <> String.replace(Path.basename(file_path, ".md"), "-", "/"),
      file_path: file_path,
      category: frontmatter["category"] || "uncategorized",
      tags: frontmatter["tags"] || []
    }
  end
  
  defp extract_frontmatter(content) do
    case Regex.run(~r/\A---\n(.*?)\n---\n?(.*)/s, content) do
      [_, yaml_content, markdown] ->
        case YamlElixir.read_from_string(yaml_content) do
          {:ok, frontmatter} -> {frontmatter, String.trim(markdown)}
          {:error, _} -> {%{}, content}
        end
      
      _ ->
        {%{}, content}
    end
  end

  defp enrich_search_results(results, _scan_result) do
    Enum.map(results, fn result ->
      breadcrumbs = Builder.build_breadcrumbs(result)
      
      result
      |> Map.put(:breadcrumbs, breadcrumbs)
      |> Map.put(:snippet, generate_snippet(result))
    end)
  end

  defp generate_snippet(result) do
    # Generate a snippet from content
    content = Map.get(result, :content, "")
    
    if String.length(content) > 200 do
      String.slice(content, 0, 197) <> "..."
    else
      content
    end
  end

  defp estimate_index_size(index) do
    # Rough estimation of index size in bytes
    doc_size = :erlang.external_size(index.documents)
    term_size = :erlang.external_size(index.terms)
    doc_size + term_size
  end
end