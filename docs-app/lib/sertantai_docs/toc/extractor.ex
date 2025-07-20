defmodule SertantaiDocs.TOC.Extractor do
  @moduledoc """
  Extracts table of contents from markdown content.
  
  Parses markdown to find headings and builds a hierarchical
  structure suitable for rendering navigation.
  """

  alias MDEx

  @default_max_level 4
  @default_min_level 1

  @doc """
  Extracts headings from markdown content.
  
  Options:
  - :min_level - minimum heading level to include (default: 1)
  - :max_level - maximum heading level to include (default: 4)
  - :use_ast - use MDEx AST parsing instead of regex (default: true)
  """
  def extract_headings(content, opts \\ []) when is_binary(content) or is_nil(content) do
    content = content || ""
    
    min_level = Keyword.get(opts, :min_level, @default_min_level)
    max_level = Keyword.get(opts, :max_level, @default_max_level)
    use_ast = Keyword.get(opts, :use_ast, true)
    
    headings = if use_ast and mdex_available?() do
      extract_headings_from_ast(content, opts)
    else
      extract_headings_from_text(content, opts)
    end
    
    headings
    |> Enum.filter(fn heading ->
      heading.level >= min_level && heading.level <= max_level
    end)
    |> assign_unique_ids()
  end
  
  @doc """
  Extracts headings using MDEx AST parsing for better accuracy.
  """
  def extract_headings_from_ast(content, _opts) do
    # Parse markdown to AST
    case MDEx.parse_document(content) do
      {:ok, %MDEx.Document{nodes: nodes}} ->
        extract_headings_from_ast_nodes(nodes)
      
      {:error, _reason} ->
        # Fallback to text-based extraction
        extract_headings_from_text(content, [])
    end
  end
  
  defp extract_headings_from_ast_nodes(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, &extract_headings_from_ast_node/1)
  end
  
  defp extract_headings_from_ast_node(%MDEx.Heading{level: level, nodes: children}) do
    text = extract_text_from_ast(children)
    
    # Extract custom ID if present in the heading text
    {clean_text, custom_id, metadata} = extract_heading_metadata(text)
    
    base_heading = %{
      level: level,
      text: clean_text,
      id: custom_id || slugify(clean_text),
      line: 1  # MDEx doesn't expose line numbers easily, so we'll use a default
    }
    
    # Add display_text if metadata contains it
    heading = case metadata["data-toc"] do
      nil -> base_heading
      display_text -> Map.put(base_heading, :display_text, display_text)
    end
    
    [heading]
  end
  
  defp extract_headings_from_ast_node(%{nodes: children}) when is_list(children) do
    extract_headings_from_ast_nodes(children)
  end
  
  defp extract_headings_from_ast_node(_), do: []
  
  defp extract_text_from_ast(nodes) when is_list(nodes) do
    Enum.map_join(nodes, "", &extract_text_from_ast_node/1)
  end
  
  defp extract_text_from_ast_node(%MDEx.Text{literal: text}), do: text
  defp extract_text_from_ast_node(%MDEx.Code{literal: text}), do: text
  defp extract_text_from_ast_node(%MDEx.Emph{nodes: children}), do: extract_text_from_ast(children)
  defp extract_text_from_ast_node(%MDEx.Strong{nodes: children}), do: extract_text_from_ast(children)
  defp extract_text_from_ast_node(%MDEx.Link{nodes: children}), do: extract_text_from_ast(children)
  defp extract_text_from_ast_node(%{nodes: children}) when is_list(children), do: extract_text_from_ast(children)
  defp extract_text_from_ast_node(_), do: ""
  
  # Legacy text-based extraction for fallback
  defp extract_headings_from_text(content, _opts) do
    content
    |> remove_code_blocks()
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(&parse_heading_line/1)
  end
  
  defp mdex_available? do
    Code.ensure_loaded?(MDEx)
  end

  @doc """
  Builds a hierarchical tree structure from flat heading list.
  """
  def build_toc_tree(headings) when is_list(headings) do
    build_tree(headings)
  end

  @doc """
  Extracts complete TOC with headings, tree, and flat list.
  """
  def extract_toc(content, opts \\ []) do
    headings = extract_headings(content, opts)
    tree = build_toc_tree(headings)
    
    %{
      headings: headings,
      tree: tree,
      flat: flatten_tree(tree)
    }
  end

  # Private functions

  defp remove_code_blocks(content) do
    # Remove fenced code blocks but preserve inline code for heading processing
    content
    |> String.replace(~r/```[\s\S]*?```/m, "")
  end

  defp parse_heading_line({line, line_number}) do
    case Regex.run(~r/^(#+)\s+(.+)$/, line) do
      [_, hashes, text] ->
        level = String.length(hashes)
        
        # Extract custom ID and metadata if present
        {text, id, metadata} = extract_heading_metadata(text)
        
        # Clean inline formatting from heading text
        clean_text = clean_heading_text(text)
        
        base_heading = %{
          level: level,
          text: clean_text,
          id: id || slugify(clean_text),
          line: line_number
        }
        
        # Add display_text only if it exists in metadata
        heading = case metadata["data-toc"] do
          nil -> base_heading
          display_text -> Map.put(base_heading, :display_text, display_text)
        end
        
        [heading]
      
      _ ->
        []
    end
  end

  defp extract_heading_metadata(text) do
    # Check for {#custom-id} or {.class #id data-attr="value"} syntax
    case Regex.run(~r/^(.+?)\s*\{([^}]+)\}\s*$/, text) do
      [_, heading_text, metadata_str] ->
        {id, metadata} = parse_metadata(metadata_str)
        {heading_text, id, metadata}
      
      _ ->
        {text, nil, %{}}
    end
  end

  defp parse_metadata(metadata_str) do
    parts = String.split(metadata_str, ~r/\s+/)
    
    {id, attrs} = Enum.reduce(parts, {nil, %{}}, fn part, {id_acc, attrs_acc} ->
      cond do
        String.starts_with?(part, "#") ->
          {String.slice(part, 1..-1//1), attrs_acc}
        
        String.contains?(part, "=") ->
          [key, value] = String.split(part, "=", parts: 2)
          value = String.trim_leading(value, "\"") |> String.trim_trailing("\"")
          {id_acc, Map.put(attrs_acc, key, value)}
        
        true ->
          {id_acc, attrs_acc}
      end
    end)
    
    {id, attrs}
  end

  defp clean_heading_text(text) do
    text
    |> String.replace(~r/\*\*(.*?)\*\*/, "\\1")  # Remove bold
    |> String.replace(~r/\*(.*?)\*/, "\\1")      # Remove italic
    |> String.replace(~r/_(.*?)_/, "\\1")        # Remove italic
    |> String.replace(~r/`([^`]+)`/, "\\1")      # Remove code backticks
    |> String.replace(~r/<(?!\.)([^>]+)>/, "\\1") # Extract content from HTML tags, but preserve Phoenix components (<.form>)
    |> String.trim()
  end

  @doc """
  Converts text to a URL-safe slug for heading IDs.
  """
  def slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s.-]/, "")  # Keep dots temporarily for proper conversion
    |> String.replace(".", "-")           # Convert dots to hyphens explicitly
    |> String.replace(~r/\s+/, "-")       # Convert spaces to hyphens
    |> String.replace(~r/-+/, "-")        # Collapse multiple hyphens
    |> String.trim("-")                   # Remove leading/trailing hyphens
  end

  defp assign_unique_ids(headings) do
    {result, _} = Enum.reduce(headings, {[], %{}}, fn heading, {acc, seen} ->
      id = heading.id
      
      {unique_id, new_seen} = if Map.has_key?(seen, id) do
        count = seen[id]
        {"#{id}-#{count}", Map.put(seen, id, count + 1)}
      else
        {id, Map.put(seen, id, 1)}
      end
      
      updated_heading = %{heading | id: unique_id}
      {acc ++ [updated_heading], new_seen}
    end)
    
    result
  end

  defp build_tree(headings) do
    build_tree_recursive(headings, 0)
  end
  
  defp build_tree_recursive([], _min_level), do: []
  
  defp build_tree_recursive([heading | rest], min_level) do
    if heading.level <= min_level do
      []
    else
      node = Map.put(heading, :children, [])
      
      # Find children (all headings at deeper levels until we hit same or shallower level)
      {children_headings, remaining} = take_children(rest, heading.level)
      children = build_tree_recursive(children_headings, heading.level)
      
      node_with_children = Map.put(node, :children, children)
      
      # Continue with remaining headings at same level
      siblings = build_tree_recursive(remaining, min_level)
      
      [node_with_children | siblings]
    end
  end
  
  defp take_children(headings, parent_level) do
    Enum.split_while(headings, fn heading ->
      heading.level > parent_level
    end)
  end

  defp flatten_tree(tree) do
    Enum.flat_map(tree, fn node ->
      [Map.delete(node, :children)] ++ flatten_tree(node.children)
    end)
  end
end