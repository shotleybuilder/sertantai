defmodule SertantaiDocs.MarkdownProcessor do
  @moduledoc """
  High-performance markdown processing using MDEx with GitHub Flavored Markdown,
  syntax highlighting, and cross-references to main application ExDoc.
  """

  alias MDEx

  @doc """
  Process a markdown file and return HTML with metadata.
  
  ## Examples
  
      iex> SertantaiDocs.MarkdownProcessor.process_file("dev/index.md")
      {:ok, html_content, frontmatter}
      
      iex> SertantaiDocs.MarkdownProcessor.process_file("nonexistent.md")
      {:error, :file_not_found}
  """
  def process_file(file_path) do
    full_path = Path.join([Application.app_dir(:sertantai_docs), "priv", "static", "docs", file_path])
    
    case File.read(full_path) do
      {:ok, content} ->
        {frontmatter, markdown} = extract_frontmatter(content)
        
        case process_markdown(markdown, frontmatter) do
          {:ok, html_content} ->
            {:ok, html_content, frontmatter}
          {:error, reason} ->
            {:error, reason}
        end
        
      {:error, :enoent} ->
        {:error, :file_not_found}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Process markdown content string and return HTML.
  """
  def process_content(content) when is_binary(content) do
    {frontmatter, markdown} = extract_frontmatter(content)
    
    case process_markdown(markdown, frontmatter) do
      {:ok, html_content} ->
        {:ok, html_content, frontmatter}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_markdown(markdown, frontmatter) do
    try do
      html_content = 
        markdown
        |> MDEx.to_html!(mdex_options())
        |> process_html_cross_references()
        |> inject_metadata(frontmatter)
        |> enhance_code_blocks()
      
      {:ok, html_content}
    rescue
      e -> {:error, {:markdown_processing_error, e}}
    end
  end

  defp extract_frontmatter(content) do
    case String.split(content, ~r/^---\s*$/m, parts: 3) do
      ["", yaml, markdown] ->
        case YamlElixir.read_from_string(yaml) do
          {:ok, frontmatter} -> {frontmatter, String.trim(markdown)}
          {:error, _} -> {%{}, content}
        end
      _ ->
        {%{}, content}
    end
  end

  defp mdex_options do
    [
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        description_lists: true,
        front_matter_delimiter: "---"
      ],
      parse: [
        smart: true,
        relaxed_tasklist_matching: true,
        relaxed_autolinks: true
      ],
      render: [
        unsafe: false,  # Safe HTML rendering for security
        escape: false,
        github_pre_lang: true,
        hardbreaks: false,
        sourcepos: true
      ]
    ]
  end


  # Process cross-references that might have been escaped or processed by MDEx
  defp process_html_cross_references(html) do
    main_app_url = get_main_app_url()
    
    html
    |> String.replace("<!-- raw HTML omitted -->", "")
    # Process HTML attributes with custom schemes (handles MDEx output with sourcepos attributes)
    |> (&Regex.replace(~r/href="ash:([^"]+)"/, &1, ~s(href="/api/\\1.html" class="ash-resource-link"))).()
    |> (&Regex.replace(~r/href="exdoc:([^"]+)"/, &1, ~s(href="/api/\\1.html" class="exdoc-link"))).()
    |> (&Regex.replace(~r/href="main:([^"]+)"/, &1, fn _full, path ->
         ~s(href="#{main_app_url}/#{path}" class="main-app-link")
       end)).()
  end

  # Enhanced syntax highlighting for Elixir code blocks
  defp enhance_code_blocks(html) do
    # Add custom classes for better styling with Petal Components
    html
    |> String.replace(~r/<pre><code class="language-elixir">/, ~s(<pre class="language-elixir"><code class="language-elixir">))
    |> String.replace(~r/<pre><code class="language-([^"]+)">/, ~s(<pre class="language-\\1"><code class="language-\\1">))
  end

  defp inject_metadata(html, frontmatter) do
    # Add metadata as data attributes to the content wrapper
    metadata_attrs = build_metadata_attributes(frontmatter)
    ~s(<div class="markdown-content" #{metadata_attrs}>#{html}</div>)
  end

  defp build_metadata_attributes(frontmatter) do
    Enum.map_join(frontmatter, " ", fn {key, value} ->
      safe_value = value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
      ~s(data-#{key}="#{safe_value}")
    end)
  end

  defp get_main_app_url do
    Application.get_env(:sertantai_docs, :main_app_url, "http://localhost:4001")
  end

  @doc """
  Get metadata from a markdown file without processing the content.
  """
  def get_metadata(file_path) do
    full_path = Path.join([Application.app_dir(:sertantai_docs), "priv", "static", "docs", file_path])
    
    case File.read(full_path) do
      {:ok, content} ->
        {frontmatter, _markdown} = extract_frontmatter(content)
        
        # Add file system metadata
        file_stat = File.stat!(full_path)
        
        # Convert mtime to DateTime - it's already in the right format from File.stat
        last_modified = case NaiveDateTime.from_erl(file_stat.mtime) do
          {:ok, naive_dt} -> DateTime.from_naive!(naive_dt, "Etc/UTC")
          {:error, _} -> DateTime.utc_now()
        end
        
        metadata = Map.merge(frontmatter, %{
          "file_path" => file_path,
          "last_modified" => last_modified,
          "size" => file_stat.size
        })
        
        {:ok, metadata}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  List all markdown files in the documentation directory.
  """
  def list_content_files do
    docs_path = Path.join([Application.app_dir(:sertantai_docs), "priv", "static", "docs"])
    
    case File.ls(docs_path) do
      {:ok, _files} ->
        docs_path
        |> Path.join("**/*.md")
        |> Path.wildcard()
        |> Enum.map(fn path ->
          Path.relative_to(path, docs_path)
        end)
        |> Enum.sort()
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generate navigation structure from the file system.
  """
  def generate_navigation do
    case list_content_files() do
      {:error, reason} ->
        {:error, reason}
        
      files ->
        nav_structure = 
          files
          |> Enum.reduce(%{}, fn file_path, acc ->
            parts = Path.split(file_path)
            build_nav_tree(acc, parts, file_path)
          end)
          |> convert_to_nav_items()
        
        {:ok, nav_structure}
    end
  end

  # Build a nested tree structure from file paths
  defp build_nav_tree(tree, [category, file], file_path) when file != "index.md" do
    page_name = Path.basename(file, ".md")
    
    case get_metadata(file_path) do
      {:ok, metadata} ->
        title = Map.get(metadata, "title", String.replace(page_name, "-", " ") |> String.capitalize())
        path = "/#{category}/#{page_name}"
        
        Map.update(tree, category, [%{title: title, path: path, file_path: file_path}], fn existing ->
          case existing do
            pages when is_list(pages) ->
              # Add to existing list of pages
              [%{title: title, path: path, file_path: file_path} | pages]
            %{children: children} = category_map when is_list(children) ->
              # Update category map with new page in children
              Map.put(category_map, :children, [%{title: title, path: path, file_path: file_path} | children])
            %{} = category_map ->
              # Convert old category map to include children
              Map.put(category_map, :children, [%{title: title, path: path, file_path: file_path}])
            _ ->
              # Fallback - create list
              [%{title: title, path: path, file_path: file_path}]
          end
        end)
        
      {:error, _} ->
        tree
    end
  end

  defp build_nav_tree(tree, [category, "index.md"], file_path) do
    case get_metadata(file_path) do
      {:ok, metadata} ->
        title = Map.get(metadata, "title", String.capitalize(category))
        
        Map.update(tree, category, %{title: title, path: "/#{category}", children: []}, fn existing ->
          case existing do
            pages when is_list(pages) ->
              # Convert list of pages to proper category structure with children
              %{title: title, path: "/#{category}", children: pages}
            %{} = category_map ->
              # Update existing category map
              Map.put(category_map, :title, title)
              |> Map.put(:path, "/#{category}")
            _ ->
              # Fallback for any other case
              %{title: title, path: "/#{category}", children: []}
          end
        end)
        
      {:error, _} ->
        Map.put_new(tree, category, %{title: String.capitalize(category), path: "/#{category}", children: []})
    end
  end

  defp build_nav_tree(tree, [file], file_path) when file != "index.md" do
    page_name = Path.basename(file, ".md")
    
    case get_metadata(file_path) do
      {:ok, metadata} ->
        title = Map.get(metadata, "title", String.replace(page_name, "-", " ") |> String.capitalize())
        
        Map.update(tree, :root, [%{title: title, path: "/#{page_name}", file_path: file_path}], fn pages ->
          [%{title: title, path: "/#{page_name}", file_path: file_path} | pages]
        end)
        
      {:error, _} ->
        tree
    end
  end

  defp build_nav_tree(tree, ["index.md"], _file_path) do
    # Root index is handled by the home route
    tree
  end

  defp build_nav_tree(tree, _parts, _file_path) do
    # Skip deeply nested files for now
    tree
  end

  # Convert the tree structure to navigation items
  defp convert_to_nav_items(tree) do
    tree
    |> Enum.reduce([], fn
      {:root, pages}, acc when is_list(pages) ->
        acc ++ pages
        
      {category, pages}, acc when is_list(pages) ->
        category_string = to_string(category)
        title = String.replace(category_string, "-", " ") |> String.capitalize()
        
        sorted_pages = 
          if is_list(pages) and length(pages) > 0 do
            Enum.sort_by(pages, fn page -> 
              cond do
                is_map(page) and Map.has_key?(page, :title) -> page[:title]
                is_map(page) and Map.has_key?(page, "title") -> page["title"]
                true -> ""
              end
            end)
          else
            []
          end
        
        nav_item = %{title: title, path: "/#{category_string}", children: sorted_pages}
        [nav_item | acc]
        
      {_category, item}, acc when is_map(item) ->
        # This is a category index page or single item
        [item | acc]
        
      _other, acc ->
        # Skip any unmatched patterns
        acc
    end)
    |> Enum.reverse()
    |> Enum.sort_by(fn item -> 
      cond do
        is_map(item) and Map.has_key?(item, :title) -> item[:title]
        is_map(item) and Map.has_key?(item, "title") -> item["title"]
        true -> ""
      end
    end)
  end
end