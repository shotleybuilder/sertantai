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
        
        case process_markdown_with_toc(markdown, frontmatter) do
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
    
    case process_markdown_with_toc(markdown, frontmatter) do
      {:ok, html_content} ->
        {:ok, html_content, frontmatter}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Process markdown content with cross-reference support.
  
  This integrates with the CrossRef system to process cross-references
  while maintaining all MDEx features.
  """
  def process_with_cross_refs(markdown, options \\ %{}) when is_binary(markdown) do
    alias SertantaiDocs.CrossRef.Processor
    
    # Process cross-references first
    cross_ref_result = Processor.process_cross_references(markdown, options)
    
    # For now, TOC extraction is not implemented
    # In a real implementation, we would extract TOC from the HTML
    toc = nil
    
    %{
      html: cross_ref_result.html,
      toc: toc,
      cross_refs: cross_ref_result.cross_refs
    }
  end

  defp process_markdown(markdown, frontmatter) do
    try do
      # Extract code block languages before MDEx processing
      code_block_languages = extract_code_block_languages(markdown)
      
      # Process cross-references at the markdown level for rich functionality
      # Pass our MDEx options to maintain consistent formatting (especially syntax highlighting)
      cross_ref_opts = %{mdex_options: mdex_options()}
      cross_ref_result = SertantaiDocs.CrossRef.Processor.process_cross_references(markdown, cross_ref_opts)
      
      html_content = 
        cross_ref_result.html
        |> process_legacy_references()
        |> inject_metadata(frontmatter)
        |> enhance_code_blocks(code_block_languages)
      
      {:ok, html_content}
    rescue
      e -> {:error, {:markdown_processing_error, e}}
    end
  end

  defp process_markdown_with_toc(markdown, frontmatter) do
    try do
      # Check if TOC placeholder exists
      has_toc_placeholder = String.contains?(markdown, "<!-- TOC -->")
      
      if has_toc_placeholder do
        # Use a valid markdown placeholder that MDEx will convert to predictable HTML
        # We'll use a unique text marker that's unlikely to appear in normal content
        toc_marker = "[TOC-PLACEHOLDER-#{:erlang.unique_integer([:positive])}]"
        
        # Replace TOC placeholder with our marker
        markdown_with_marker = String.replace(markdown, "<!-- TOC -->", toc_marker, global: false)
        
        # Process markdown with the marker
        code_block_languages = extract_code_block_languages(markdown_with_marker)
        
        # Process cross-references at the markdown level for rich functionality
        # Pass our MDEx options to maintain consistent formatting (especially syntax highlighting)
        cross_ref_opts = %{mdex_options: mdex_options()}
        cross_ref_result = SertantaiDocs.CrossRef.Processor.process_cross_references(markdown_with_marker, cross_ref_opts)
        
        html_content = 
          cross_ref_result.html
          |> process_legacy_references()
          |> enhance_code_blocks(code_block_languages)
        
        # Extract headings from the original markdown (exclude H1)
        toc = SertantaiDocs.TOC.Extractor.extract_toc(markdown, [min_level: 2])
        
        # Generate TOC HTML
        toc_html = generate_toc_html_from_headings(toc.headings)
        
        # Replace the marker in the HTML output
        # MDEx will have converted [TOC-PLACEHOLDER-123] to something like <p>[TOC-PLACEHOLDER-123]</p>
        # We need to replace the entire paragraph containing our marker
        html_with_toc = Regex.replace(
          ~r/<p[^>]*>\s*\[TOC-PLACEHOLDER-\d+\]\s*<\/p>/,
          html_content,
          toc_html
        )
        
        # Apply metadata injection last
        final_html = inject_metadata(html_with_toc, frontmatter)
        
        {:ok, final_html}
      else
        # Use original processing when no TOC placeholder
        process_markdown(markdown, frontmatter)
      end
    rescue
      e -> {:error, {:markdown_processing_error, e}}
    end
  end

  @doc """
  Extract YAML frontmatter from markdown content.
  
  ## Examples
  
      iex> SertantaiDocs.MarkdownProcessor.extract_frontmatter("---\\ntitle: Test\\n---\\nContent")
      {%{"title" => "Test"}, "Content"}
  """  
  def extract_frontmatter(content) do
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

  def mdex_options do
    [
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        description_lists: true,
        front_matter_delimiter: "---",
        header_ids: ""  # Enable header IDs with empty prefix
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
      ],
      # Use github_light theme with custom styling
      syntax_highlight: [
        formatter: {:html_inline, 
          theme: "github_light",
          pre_class: "sertantai-code-block"
        }
      ]
    ]
  end



  # Process legacy references that aren't handled by the CrossRef system
  defp process_legacy_references(html) do
    # Handle legacy main app links that use main: scheme
    main_app_url = get_main_app_url()
    
    html
    |> String.replace("<!-- raw HTML omitted -->", "")
    |> (&Regex.replace(~r/href="main:([^"]+)"/, &1, fn _full, path ->
         ~s(href="#{main_app_url}/#{path}" class="main-app-link")
       end)).()
  end

  # Extract code block languages from original markdown before MDEx processing
  defp extract_code_block_languages(markdown) do
    Regex.scan(~r/```([a-zA-Z]*)\n(.*?)\n```/s, markdown)
    |> Enum.map(fn [_full, language, content] ->
      clean_language = case String.trim(language) do
        "" -> "text"
        lang -> lang
      end
      {clean_language, String.trim(content)}
    end)
  end

  # Enhanced code blocks with custom styling and copy functionality
  defp enhance_code_blocks(html, code_block_languages) do
    # Replace code blocks with our custom component
    replace_code_blocks_with_component(html, code_block_languages)
  end

  defp replace_code_blocks_with_component(html, code_block_languages) do
    # Convert languages list to a more usable format
    language_map = code_block_languages
    |> Enum.with_index()
    |> Map.new(fn {{language, _content}, index} -> {index, language} end)
    
    # Track which code block we're processing
    {:ok, agent_pid} = Agent.start_link(fn -> 0 end)
    
    try do
      # Match code blocks and wrap them with our component
      result = Regex.replace(
        ~r/<pre([^>]*class="[^"]*sertantai-code-block[^"]*"[^>]*)><code[^>]*>(.*?)<\/code><\/pre>/s,
        html,
        fn _full_match, pre_attributes, content ->
          # Get current block index and increment
          current_index = Agent.get_and_update(agent_pid, fn count -> 
            {count, count + 1} 
          end)
          
          # Generate unique ID for this code block
          block_id = "code-block-#{:crypto.hash(:md5, content) |> Base.encode16(case: :lower) |> String.slice(0, 8)}"
          
          # Get language from our pre-extracted list
          language_display = Map.get(language_map, current_index, "text")
          
          # Clean up the content but preserve syntax highlighting
          cleaned_content = content
            # Remove line wrapper spans but keep syntax highlighting spans
            |> String.replace(~r/<span class="line"[^>]*>/, "")
            |> String.replace(~r/<\/span>\n<\/span>/, "</span>\n")
            |> String.replace(~r/<\/span>$/, "")
            # Remove data-line attributes 
            |> String.replace(~r/data-line="[^"]*"\s*/, "")
            |> String.trim()
          
          # Wrap the MDEx output with our custom header and container
          render_enhanced_code_block(pre_attributes, cleaned_content, language_display, block_id)
        end
      )
      
      Agent.stop(agent_pid)
      result
    rescue
      e ->
        Agent.stop(agent_pid)
        reraise e, __STACKTRACE__
    end
  end


  defp render_enhanced_code_block(pre_attributes, content, language, block_id) do
    """
    <div class="relative group mb-4 rounded-lg border border-gray-200 bg-gray-50 overflow-hidden" id="#{block_id}">
      <div class="flex items-center justify-between px-4 py-2 bg-gray-100 border-b border-gray-200">
        <div class="flex items-center space-x-2">
          <svg class="h-4 w-4 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"></path>
          </svg>
          <span class="text-sm font-medium text-gray-700 capitalize">#{language}</span>
        </div>
        <button type="button" class="flex items-center space-x-1 px-2 py-1 text-xs font-medium text-gray-500 hover:text-gray-700 hover:bg-gray-200 rounded transition-colors" onclick="copyToClipboard('#{block_id}')" title="Copy to clipboard">
          <svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
          </svg>
          <span>Copy</span>
        </button>
      </div>
      <div class="relative">
        <pre#{pre_attributes}><code id="#{block_id}-content">#{content}</code></pre>
      </div>
    </div>
    """
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

  # Generate TOC HTML from headings list - matches SertantaiDocsWeb.Components.TOC structure
  defp generate_toc_html_from_headings(headings) when is_list(headings) do
    case headings do
      [] ->
        ""
        
      _ ->
        # Build tree structure for nested TOC using existing extractor
        tree = SertantaiDocs.TOC.Extractor.build_toc_tree(headings)
        
        """
        <nav class="table-of-contents" role="navigation" aria-label="Table of contents">
          <h2 class="toc-title text-lg font-semibold mb-3">Table of Contents</h2>
          <ul class="toc-list space-y-1">
            #{render_toc_tree_items(tree)}
          </ul>
        </nav>
        """
    end
  end

  defp render_toc_tree_items(nodes) when is_list(nodes) do
    Enum.map_join(nodes, "\n", fn node ->
      children_html = case node.children do
        [] -> ""
        children -> """
        <div class="ml-4">
          <ul class="toc-list space-y-1">#{render_toc_tree_items(children)}</ul>
        </div>
        """
      end
      
      ~s(<li class="toc-item" data-level="#{node.level}">
        <div class="flex items-center">
          <a href="##{node.id}" class="toc-link block py-1 text-sm transition-colors hover:text-indigo-600 text-gray-700">#{node.text}</a>
        </div>
        #{children_html}
      </li>)
    end)
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
  Generate navigation structure with grouping support from the file system.
  This version applies grouping to the build category.
  """
  def generate_navigation_with_grouping do
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
          |> convert_to_nav_items_with_grouping()
        
        {:ok, nav_structure}
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
          |> convert_to_nav_items_with_grouping()
        
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

  # Convert the tree structure to navigation items with grouping
  defp convert_to_nav_items_with_grouping(tree) do
    tree
    |> Enum.reduce([], fn
      {:root, pages}, acc when is_list(pages) ->
        acc ++ pages
        
      {category, category_map}, acc when is_map(category_map) and map_size(category_map) > 0 ->
        category_string = to_string(category)
        
        # Handle build category with special grouping logic
        if category_string == "build" and Map.has_key?(category_map, :children) do
          pages = Map.get(category_map, :children, [])
          grouped_children = apply_grouping_to_pages(pages, category_string)
          
          # Create nav item with grouped children
          nav_item = category_map 
          |> Map.put(:children, grouped_children)
          
          [nav_item | acc]
        else
          # This is a regular category index page or single item
          [category_map | acc]
        end
        
      {category, pages}, acc when is_list(pages) ->
        category_string = to_string(category)
        title = String.replace(category_string, "-", " ") |> String.capitalize()
        
        # Use grouping for build category, flat for others
        children = if category_string == "build" do
          apply_grouping_to_pages(pages, category_string)
        else
          sort_pages_default(pages)
        end
        
        nav_item = %{title: title, path: "/#{category_string}", children: children}
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


  # Apply grouping to pages for build category
  defp apply_grouping_to_pages(pages, category) do
    # Convert pages to {file_path, metadata} format
    files_with_metadata = pages
    |> Enum.map(fn page ->
      file_path = Map.get(page, :file_path, "")
      case get_metadata(file_path) do
        {:ok, metadata} -> {file_path, metadata}
        {:error, _reason} -> 
          # If metadata extraction fails, create basic metadata from page
          basic_metadata = %{
            "title" => Map.get(page, :title, ""),
            "group" => infer_group_from_filename(file_path)
          }
          {file_path, basic_metadata}
      end
    end)
    
    # Group files and convert to navigation structure
    grouped = group_files_by_metadata(files_with_metadata, category)
    convert_groups_to_nav_structure(grouped)
  end

  # Default sorting for non-build categories
  defp sort_pages_default(pages) when is_list(pages) and length(pages) > 0 do
    Enum.sort_by(pages, fn page -> 
      cond do
        is_map(page) and Map.has_key?(page, :title) -> page[:title]
        is_map(page) and Map.has_key?(page, "title") -> page["title"]
        true -> ""
      end
    end)
  end

  defp sort_pages_default(pages), do: pages

  # ===== GROUPING SYSTEM FUNCTIONS =====
  # Functions for the hybrid YAML frontmatter + filename fallback grouping system

  @doc """
  Infer group from filename prefix (before first underscore).
  
  ## Examples
  
      iex> SertantaiDocs.MarkdownProcessor.infer_group_from_filename("done_phase_1.md")
      "done"
      
      iex> SertantaiDocs.MarkdownProcessor.infer_group_from_filename("hello_jason.md")
      "hello"
      
      iex> SertantaiDocs.MarkdownProcessor.infer_group_from_filename("no_underscore.md")
      "other"
  """
  def infer_group_from_filename(file_path) do
    filename = Path.basename(file_path, ".md")
    
    case String.split(filename, "_", parts: 2) do
      [prefix, _rest] when prefix != filename and prefix != "" -> prefix
      _ -> "other"
    end
  end

  @doc """
  Determine group using hybrid approach: YAML frontmatter takes precedence, filename fallback.
  
  ## Examples
  
      iex> SertantaiDocs.MarkdownProcessor.determine_group({"test.md", %{"group" => "custom"}})
      "custom"
      
      iex> SertantaiDocs.MarkdownProcessor.determine_group({"done_test.md", %{}})
      "done"
  """
  def determine_group({file_path, metadata}) do
    case Map.get(metadata, "group") do
      nil -> infer_group_from_filename(file_path)
      group when is_binary(group) and group != "" -> group
      _ -> infer_group_from_filename(file_path)
    end
  end

  @doc """
  Infer metadata from filename patterns and content.
  
  ## Examples
  
      iex> SertantaiDocs.MarkdownProcessor.infer_metadata_from_filename("done_phase_1_security.md")
      %{"group" => "done", "sub_group" => "phases", "category" => "security", "title" => "Phase 1 Security", "tags" => ["done", "phases", "security"]}
  """
  def infer_metadata_from_filename(file_path) do
    filename = Path.basename(file_path, ".md")
    
    # Extract group from prefix  
    {group, rest} = case String.split(filename, "_", parts: 2) do
      [prefix, rest] when prefix != filename and prefix != "" -> {prefix, rest}
      _ -> {"other", filename}
    end
    
    # Generate title from the rest of filename
    title = rest
            |> String.replace("_", " ")
            |> String.split()
            |> Enum.map(&String.capitalize/1)
            |> Enum.join(" ")
    
    # Infer other metadata
    category = infer_category_from_filename(filename)
    sub_group = infer_sub_group_from_filename_string(filename)
    tags = infer_tags_from_filename(filename, group)
    
    %{
      "group" => group,
      "sub_group" => sub_group,
      "category" => category,
      "title" => title,
      "tags" => tags,
      "status" => "live", # default
      "priority" => "medium" # default
    }
  end

  defp infer_category_from_filename(filename) do
    cond do
      String.contains?(filename, ["security", "auth"]) -> "security"
      String.contains?(filename, ["admin", "custom_admin"]) -> "admin"
      String.contains?(filename, ["docs", "documentation"]) -> "docs"
      String.contains?(filename, ["phase", "implementation"]) -> "implementation"
      String.contains?(filename, ["strategy", "analysis", "appraisal"]) -> "analysis"
      String.contains?(filename, ["plan", "planning"]) -> "planning"
      String.contains?(filename, ["test", "execution"]) -> "testing"
      true -> "general"
    end
  end


  defp infer_tags_from_filename(filename, group) do
    base_tags = [group]
    
    additional_tags = []
    |> maybe_add_tag(String.contains?(filename, ["phase"]), "phases")
    |> maybe_add_tag(String.contains?(filename, ["admin"]), "admin")
    |> maybe_add_tag(String.contains?(filename, ["security", "auth"]), "security")
    |> maybe_add_tag(String.contains?(filename, ["docs", "documentation"]), "documentation")
    |> maybe_add_tag(String.contains?(filename, ["implementation"]), "implementation")
    |> maybe_add_tag(String.contains?(filename, ["plan"]), "planning")
    |> maybe_add_tag(String.contains?(filename, ["test"]), "testing")
    |> maybe_add_tag(String.contains?(filename, ["ash"]), "ash")
    |> maybe_add_tag(String.contains?(filename, ["lrt"]), "uk-lrt")
    
    (base_tags ++ additional_tags) |> Enum.uniq()
  end

  defp maybe_add_tag(tags, true, tag), do: [tag | tags]
  defp maybe_add_tag(tags, false, _tag), do: tags

  @doc """
  Validate and normalize metadata fields.
  
  ## Examples
  
      iex> SertantaiDocs.MarkdownProcessor.validate_metadata(%{"priority" => "HIGH"})
      %{"priority" => "high"}
  """
  def validate_metadata(metadata) when is_map(metadata) do
    metadata
    |> normalize_priority()
    |> normalize_status()
    |> normalize_tags()
    |> normalize_group()
    |> normalize_sub_group()
  end

  defp normalize_priority(metadata) do
    case Map.get(metadata, "priority") do
      priority when is_binary(priority) ->
        normalized = case String.downcase(priority) do
          p when p in ["high", "critical", "urgent"] -> "high"
          p when p in ["medium", "med", "normal"] -> "medium"
          p when p in ["low", "minor"] -> "low"
          _ -> "medium" # default fallback
        end
        Map.put(metadata, "priority", normalized)
      _ -> 
        Map.put(metadata, "priority", "medium") # default fallback
    end
  end

  defp normalize_status(metadata) do
    case Map.get(metadata, "status") do
      status when is_binary(status) ->
        normalized = case String.downcase(status) do
          s when s in ["live", "active", "published", "current"] -> "live"
          s when s in ["archived", "archive", "inactive", "deprecated", "old"] -> "archived"
          _ -> "live" # default fallback
        end
        Map.put(metadata, "status", normalized)
      _ ->
        Map.put(metadata, "status", "live") # default fallback
    end
  end

  defp normalize_tags(metadata) do
    case Map.get(metadata, "tags") do
      tags when is_list(tags) ->
        normalized = tags 
        |> Enum.filter(&is_binary/1)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.uniq()
        Map.put(metadata, "tags", normalized)
      tag when is_binary(tag) and tag != "" ->
        Map.put(metadata, "tags", [String.trim(tag)])
      _ ->
        Map.put(metadata, "tags", [])
    end
  end

  defp normalize_group(metadata) do
    case Map.get(metadata, "group") do
      group when is_binary(group) and group != "" ->
        metadata
      _ ->
        Map.put(metadata, "group", nil)
    end
  end

  defp normalize_sub_group(metadata) do
    case Map.get(metadata, "sub_group") do
      sub_group when is_binary(sub_group) and sub_group != "" ->
        metadata
      _ ->
        Map.put(metadata, "sub_group", nil)
    end
  end

  @doc """
  Hybrid group determination using YAML metadata with filename fallback.
  
  ## Examples
  
      iex> SertantaiDocs.MarkdownProcessor.hybrid_group_determination(%{"group" => "custom"}, "done_test.md")
      "custom"
      
      iex> SertantaiDocs.MarkdownProcessor.hybrid_group_determination(%{}, "done_test.md")
      "done"
  """
  def hybrid_group_determination(yaml_metadata, file_path) do
    case Map.get(yaml_metadata, "group") do
      group when is_binary(group) and group != "" -> group
      _ -> infer_group_from_filename(file_path)
    end
  end

  @doc """
  Hybrid metadata resolution: merge YAML frontmatter with filename inferences.
  YAML takes precedence where valid, filename inference fills gaps.
  
  ## Examples
  
      iex> yaml = %{"title" => "YAML Title", "group" => nil}
      iex> SertantaiDocs.MarkdownProcessor.hybrid_metadata_resolution(yaml, "done_test.md")
      # Returns merged metadata with YAML title preserved and group inferred from filename
  """
  def hybrid_metadata_resolution(yaml_metadata, file_path) do
    # Get inferred metadata from filename
    inferred = infer_metadata_from_filename(file_path)
    
    # Merge with YAML taking precedence for valid values
    merged = merge_metadata(yaml_metadata, inferred)
    
    # Validate and normalize the result
    validate_metadata(merged)
  end

  @doc """
  Merge YAML frontmatter with inferred metadata, prioritizing valid YAML values.
  """
  def merge_metadata(yaml_metadata, inferred_metadata) do
    # Start with inferred metadata as base
    base = inferred_metadata || %{}
    
    # Override with valid YAML values
    Enum.reduce(yaml_metadata, base, fn {key, yaml_value}, acc ->
      case {key, yaml_value} do
        # Valid YAML values override inferred
        {k, v} when is_binary(v) and v != "" -> Map.put(acc, k, v)
        {"tags", v} when is_list(v) -> Map.put(acc, key, v)
        {"priority", v} when v in ["high", "medium", "low"] -> Map.put(acc, key, v)
        {"status", v} when v in ["live", "archived"] -> Map.put(acc, key, v)
        
        # Invalid YAML values keep inferred
        _ -> acc
      end
    end)
  end

  # ===== SUB-GROUP FUNCTIONALITY =====

  @doc """
  Create sub-groups from files with sub_group metadata.
  
  ## Examples
  
      iex> files = [{"done_phase1.md", %{"title" => "Phase 1", "sub_group" => "phases"}}]
      iex> SertantaiDocs.MarkdownProcessor.create_sub_groups_from_metadata(files)
      %{"phases" => [{"done_phase1.md", %{"title" => "Phase 1", "sub_group" => "phases"}}]}
  """
  def create_sub_groups_from_metadata(files) do
    files
    |> Enum.filter(fn {_path, metadata} -> 
      sub_group = Map.get(metadata, "sub_group")
      is_binary(sub_group) and sub_group != ""
    end)
    |> Enum.group_by(fn {_path, metadata} -> 
      Map.get(metadata, "sub_group")
    end)
  end

  @doc """
  Separate files into sub-grouped and ungrouped lists.
  
  ## Examples
  
      iex> files = [
      ...>   {"file1.md", %{"title" => "File 1", "sub_group" => "phases"}},
      ...>   {"file2.md", %{"title" => "File 2"}}
      ...> ]
      iex> SertantaiDocs.MarkdownProcessor.separate_sub_grouped_files(files)
      {%{"phases" => [{"file1.md", %{"title" => "File 1", "sub_group" => "phases"}}]}, 
       [{"file2.md", %{"title" => "File 2"}}]}
  """
  def separate_sub_grouped_files(files) do
    {sub_grouped, ungrouped} = Enum.split_with(files, fn {_path, metadata} ->
      sub_group = Map.get(metadata, "sub_group")
      is_binary(sub_group) and sub_group != ""
    end)
    
    sub_groups = Enum.group_by(sub_grouped, fn {_path, metadata} ->
      Map.get(metadata, "sub_group")
    end)
    
    {sub_groups, ungrouped}
  end

  @doc """
  Build sub-group navigation structure from grouped files.
  
  Returns a list of sub-group navigation items with collapsible children.
  """
  def build_sub_group_navigation_structure(sub_groups) do
    sub_groups
    |> Enum.map(fn {sub_group_name, files} ->
      # Sort files by priority, then by title
      sorted_files = sort_files_by_priority_and_title(files)
      
      # Convert files to navigation items
      children = Enum.map(sorted_files, fn {file_path, metadata} ->
        build_page_nav_item(file_path, metadata)
      end)
      
      %{
        title: format_sub_group_title(sub_group_name),
        type: :sub_group,
        collapsible: true,
        default_expanded: false,
        children: children
      }
    end)
    |> Enum.sort_by(& &1.title) # Sort sub-groups alphabetically
  end

  @doc """
  Infer sub-group from filename patterns.
  
  ## Examples
  
      iex> SertantaiDocs.MarkdownProcessor.infer_sub_group_from_filename("done_phase_1_summary.md")
      "phases"
  """
  def infer_sub_group_from_filename(file_path) do
    filename = Path.basename(file_path, ".md")
    infer_sub_group_from_filename_string(filename)
  end

  @doc """
  Merge sub-groups with ungrouped files into unified navigation structure.
  
  Sub-groups come first, then direct page items.
  """
  def merge_sub_groups_with_ungrouped(sub_group_nav, ungrouped_files) do
    # Convert ungrouped files to page navigation items
    ungrouped_nav_items = Enum.map(ungrouped_files, fn {file_path, metadata} ->
      build_page_nav_item(file_path, metadata)
    end)
    |> Enum.sort_by(& &1.title)
    
    # Combine: sub-groups first, then ungrouped items
    sorted_sub_groups = Enum.sort_by(sub_group_nav, & &1.title)
    sorted_sub_groups ++ ungrouped_nav_items
  end

  defp infer_sub_group_from_filename_string(filename) do
    cond do
      String.contains?(filename, ["phase"]) -> "phases"
      String.contains?(filename, ["admin", "custom_admin"]) -> "admin"
      String.contains?(filename, ["security", "auth"]) -> "security"
      String.contains?(filename, ["docs", "documentation"]) -> "docs"
      String.contains?(filename, ["architecture", "arch"]) -> "architecture"
      String.contains?(filename, ["action_plan"]) -> "planning"
      String.contains?(filename, ["test"]) -> "testing"
      String.contains?(filename, ["applicability"]) -> "applicability"
      true -> "general"
    end
  end

  # Helper functions for sub-group processing

  defp sort_files_by_priority_and_title(files) do
    files
    |> Enum.sort_by(fn {_path, metadata} ->
      priority = Map.get(metadata, "priority", "medium")
      title = Map.get(metadata, "title", "")
      
      # Priority order: high=1, medium=2, low=3, then alphabetical by title
      priority_value = case priority do
        "high" -> 1
        "medium" -> 2
        "low" -> 3
        _ -> 2 # default to medium
      end
      
      {priority_value, title}
    end)
  end

  defp build_page_nav_item(file_path, metadata) do
    title = Map.get(metadata, "title", Path.basename(file_path, ".md") |> format_title())
    path = build_page_path(file_path)
    
    %{
      title: title,
      type: :page,
      path: path,
      metadata: metadata
    }
  end

  defp build_page_path(file_path) do
    # Convert file path to URL path
    case Path.split(file_path) do
      ["build", filename] ->
        page_name = Path.basename(filename, ".md")
        "/build/#{page_name}"
      [category, filename] ->
        page_name = Path.basename(filename, ".md")  
        "/#{category}/#{page_name}"
      _ ->
        # For single filenames, assume they are from build category
        # This handles cases where tests pass just "strategy_analysis.md"
        page_name = Path.basename(file_path, ".md")
        "/build/#{page_name}"
    end
  end

  defp format_sub_group_title(sub_group_name) do
    sub_group_name
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_title(filename) do
    filename
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  # Navigation structure generation functions

  def group_files_by_metadata(files, category) when category == "build" do
    files
    |> Enum.map(fn {file_path, metadata} -> {file_path, metadata} end)
    |> Enum.group_by(fn {file_path, metadata} -> 
      determine_group({file_path, metadata})
    end)
  end

  def group_files_by_metadata(files, _category) do
    # Non-build categories remain flat (ungrouped)
    files
  end

  def convert_groups_to_nav_structure(grouped_data) when is_map(grouped_data) do
    grouped_data
    |> Enum.map(fn {group_name, files} ->
      # Separate files with and without sub-groups
      {sub_groups, ungrouped} = separate_sub_grouped_files(files)
      
      # Build sub-group navigation structure
      sub_group_nav = build_sub_group_navigation_structure(sub_groups)
      
      # Merge sub-groups with ungrouped files
      children = merge_sub_groups_with_ungrouped(sub_group_nav, ungrouped)
      
      # Create group navigation item
      %{
        title: format_group_title(group_name),
        group: group_name,
        type: :group,
        collapsible: true,
        children: children,
        default_expanded: default_expanded?(group_name),
        state_key: "build_group_#{group_name}",
        icon: group_icon(group_name),
        icon_color: group_icon_color(group_name),
        css_class: "nav-group nav-group-#{group_name}",
        header_class: "nav-group-header nav-group-header-#{group_name}",
        aria_label: "#{format_group_title(group_name)} group, collapsible section with #{length(children)} item#{if length(children) == 1, do: "", else: "s"}",
        aria_expanded: default_expanded?(group_name),
        item_count: length(children),
        keyboard_shortcuts: %{
          toggle: "Enter",
          focus_first: "ArrowDown", 
          focus_parent: "ArrowUp"
        },
        mobile_behavior: %{
          collapse_on_mobile: true,
          show_item_count: true
        }
      }
    end)
    |> Enum.sort_by(& &1.title)
  end

  def convert_groups_to_nav_structure([]), do: []

  def normalize_similar_sub_groups(files) do
    # Group files by normalized sub-group names
    files
    |> Enum.group_by(fn {_path, metadata} ->
      sub_group = Map.get(metadata, "sub_group", "")
      normalize_sub_group_name(sub_group)
    end)
    |> Enum.into(%{}, fn {normalized_name, group_files} ->
      {normalized_name, group_files}
    end)
  end

  # Helper functions for navigation structure

  defp format_group_title(group_name) do
    case group_name do
      "done" -> "Done"
      "strategy" -> "Strategy" 
      "todo" -> "Todo"
      other -> 
        other
        |> String.replace("_", " ")
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
    end
  end

  defp default_expanded?(group_name) do
    # Todo group defaults to expanded (active work)
    group_name == "todo"
  end

  defp group_icon(group_name) do
    case group_name do
      "done" -> "hero-check-circle"
      "strategy" -> "hero-document-magnifying-glass"
      "todo" -> "hero-clipboard-document-list"
      _ -> "hero-document"
    end
  end

  defp group_icon_color(group_name) do
    case group_name do
      "done" -> "text-green-600"
      "strategy" -> "text-blue-600" 
      "todo" -> "text-orange-600"
      _ -> "text-gray-600"
    end
  end

  defp normalize_sub_group_name(sub_group) when is_binary(sub_group) do
    cond do
      String.contains?(sub_group, "admin") -> "admin"
      String.contains?(sub_group, "security") -> "security"
      true -> sub_group
    end
  end

  defp normalize_sub_group_name(_), do: "general"

  # ===== SORTING AND FILTERING FUNCTIONS =====
  # Functions for sorting and filtering files by various criteria

  @doc """
  Sort files by priority (high > medium > low), then alphabetically by title.
  
  ## Examples
  
      iex> files = [{"low.md", %{"priority" => "low", "title" => "Z"}}, {"high.md", %{"priority" => "high", "title" => "A"}}]
      iex> SertantaiDocs.MarkdownProcessor.sort_files_by_priority(files)
      [{"high.md", %{"priority" => "high", "title" => "A"}}, {"low.md", %{"priority" => "low", "title" => "Z"}}]
  """
  def sort_files_by_priority(files) do
    files
    |> Enum.sort_by(fn {_path, metadata} ->
      priority = Map.get(metadata, "priority", "medium")
      title = Map.get(metadata, "title", "")
      
      # Priority order: high=1, medium=2, low=3, then alphabetical by title
      priority_value = case priority do
        "high" -> 1
        "medium" -> 2
        "low" -> 3
        _ -> 2 # default to medium
      end
      
      {priority_value, title}
    end)
  end

  @doc """
  Group files by category for filtering and organization.
  
  ## Examples
  
      iex> files = [{"sec.md", %{"category" => "security"}}, {"admin.md", %{"category" => "admin"}}]
      iex> SertantaiDocs.MarkdownProcessor.group_by_category(files)
      %{"security" => [{"sec.md", %{"category" => "security"}}], "admin" => [{"admin.md", %{"category" => "admin"}}]}
  """
  def group_by_category(files) do
    files
    |> Enum.group_by(fn {_path, metadata} ->
      Map.get(metadata, "category", "general")
    end)
  end

  @doc """
  Filter files by status (live, archived).
  
  ## Examples
  
      iex> files = [{"live.md", %{"status" => "live"}}, {"old.md", %{"status" => "archived"}}]
      iex> SertantaiDocs.MarkdownProcessor.filter_by_status(files, "live")
      [{"live.md", %{"status" => "live"}}]
  """
  def filter_by_status(items, status) when status == "" or status == nil, do: items
  def filter_by_status(items, status) when is_binary(status) do
    Enum.filter(items, fn
      {_path, metadata} when is_map(metadata) ->
        Map.get(metadata, "status") == status
      item when is_map(item) ->
        case get_item_metadata(item) do
          %{"status" => ^status} -> true
          _ -> false
        end
      _ -> false
    end)
  end

  @doc """
  Filter files by tag (files must contain the specified tag).
  
  ## Examples
  
      iex> files = [{"impl.md", %{"tags" => ["implementation", "ash"]}}, {"sec.md", %{"tags" => ["security"]}}]
      iex> SertantaiDocs.MarkdownProcessor.filter_by_tag(files, "implementation")
      [{"impl.md", %{"tags" => ["implementation", "ash"]}}]
  """
  def filter_by_tag(files, tag) do
    files
    |> Enum.filter(fn {_path, metadata} ->
      tags = Map.get(metadata, "tags", [])
      is_list(tags) and tag in tags
    end)
  end

  # ===== CACHING FUNCTIONS =====
  # Simple caching functions for metadata (basic implementation)

  @doc """
  Get cached metadata for a file. For now, just delegates to get_metadata/1.
  In a real implementation, this would use ETS or another caching mechanism.
  
  ## Examples
  
      iex> SertantaiDocs.MarkdownProcessor.get_cached_metadata("dev/index.md")
      {:ok, %{"title" => "Development Guide"}}
  """
  def get_cached_metadata(file_path) do
    # Basic implementation without actual caching
    get_metadata(file_path)
  end

  @doc """
  Invalidate cached metadata for a file. 
  In a real implementation, this would clear the cache entry.
  
  ## Examples
  
      iex> SertantaiDocs.MarkdownProcessor.invalidate_cache("dev/index.md") 
      :ok
  """
  def invalidate_cache(_file_path) do
    # Basic implementation without actual caching
    :ok
  end

  # ===== ADVANCED FILTERING AND SORTING FUNCTIONS =====

  @doc """
  Filter navigation items by category metadata.
  """
  def filter_by_category(nav_items, category) when category == "" or category == nil, do: nav_items
  def filter_by_category(nav_items, category) when is_binary(category) do
    Enum.filter(nav_items, fn item ->
      case get_item_metadata(item) do
        %{"category" => ^category} -> true
        _ -> false
      end
    end)
  end

  @doc """
  Filter navigation items by priority metadata.
  """
  def filter_by_priority(nav_items, priority) when priority == "" or priority == nil, do: nav_items
  def filter_by_priority(nav_items, priority) when is_binary(priority) do
    Enum.filter(nav_items, fn item ->
      case get_item_metadata(item) do
        %{"priority" => ^priority} -> true
        _ -> false
      end
    end)
  end

  @doc """
  Filter navigation items by author metadata.
  """
  def filter_by_author(nav_items, author) when author == "" or author == nil, do: nav_items
  def filter_by_author(nav_items, author) when is_binary(author) do
    Enum.filter(nav_items, fn item ->
      case get_item_metadata(item) do
        %{"author" => ^author} -> true
        _ -> false
      end
    end)
  end

  @doc """
  Filter navigation items by tags metadata (OR logic - item matches if it has any of the filter tags).
  """
  def filter_by_tags(nav_items, tags) when tags == [] or tags == nil, do: nav_items
  def filter_by_tags(nav_items, filter_tags) when is_list(filter_tags) do
    Enum.filter(nav_items, fn item ->
      case get_item_metadata(item) do
        %{"tags" => item_tags} when is_list(item_tags) ->
          Enum.any?(filter_tags, fn filter_tag -> filter_tag in item_tags end)
        _ -> false
      end
    end)
  end

  @doc """
  Apply multiple filters simultaneously to navigation items.
  """
  def apply_filters(nav_items, filter_options) do
    nav_items
    |> filter_by_status(Map.get(filter_options, :status, ""))
    |> filter_by_category(Map.get(filter_options, :category, ""))
    |> filter_by_priority(Map.get(filter_options, :priority, ""))
    |> filter_by_author(Map.get(filter_options, :author, ""))
    |> filter_by_tags(Map.get(filter_options, :tags, []))
  end

  @doc """
  Case-insensitive category filtering.
  """
  def filter_by_category_case_insensitive(nav_items, category) when category == "" or category == nil, do: nav_items
  def filter_by_category_case_insensitive(nav_items, category) when is_binary(category) do
    target_category = String.downcase(category)
    Enum.filter(nav_items, fn item ->
      case get_item_metadata(item) do
        %{"category" => item_category} when is_binary(item_category) ->
          String.downcase(item_category) == target_category
        _ -> false
      end
    end)
  end

  # ===== SORTING FUNCTIONS =====

  @doc """
  Sort navigation items by priority (high -> medium -> low).
  """
  def sort_by_priority(nav_items, sort_order \\ :asc) do
    priority_order = %{"high" => 1, "medium" => 2, "low" => 3}
    
    sorted = Enum.sort_by(nav_items, fn item ->
      case get_item_metadata(item) do
        %{"priority" => priority} -> Map.get(priority_order, priority, 4)
        _ -> 4  # Items without priority go last
      end
    end)
    
    case sort_order do
      :desc -> Enum.reverse(sorted)
      _ -> sorted
    end
  end

  @doc """
  Sort navigation items by title alphabetically.
  """
  def sort_by_title(nav_items, sort_order \\ :asc) do
    sorted = Enum.sort_by(nav_items, fn item ->
      get_item_title(item)
    end)
    
    case sort_order do
      :desc -> Enum.reverse(sorted)
      _ -> sorted
    end
  end

  @doc """
  Sort navigation items by last_modified date.
  """
  def sort_by_date(nav_items, sort_order \\ :desc) do
    sorted = Enum.sort_by(nav_items, fn item ->
      case get_item_metadata(item) do
        %{"last_modified" => date_str} when is_binary(date_str) ->
          case Date.from_iso8601(date_str) do
            {:ok, date} -> date
            {:error, _} -> ~D[1900-01-01]  # Default for invalid dates
          end
        _ -> ~D[1900-01-01]  # Items without date go to beginning
      end
    end)
    
    case sort_order do
      :asc -> sorted
      _ -> Enum.reverse(sorted)
    end
  end

  @doc """
  Sort navigation items by category alphabetically.
  """
  def sort_by_category(nav_items, sort_order \\ :asc) do
    sorted = Enum.sort_by(nav_items, fn item ->
      case get_item_metadata(item) do
        %{"category" => category} when is_binary(category) -> category
        _ -> "zzz"  # Items without category go last
      end
    end)
    
    case sort_order do
      :desc -> Enum.reverse(sorted)
      _ -> sorted
    end
  end

  @doc """
  Extract available filter options from navigation items for UI dropdowns.
  """
  def extract_filter_options(nav_items) do
    metadata_list = Enum.map(nav_items, &get_item_metadata/1)
    
    %{
      statuses: extract_unique_values(metadata_list, "status"),
      categories: extract_unique_values(metadata_list, "category"),
      priorities: extract_unique_values(metadata_list, "priority"),
      authors: extract_unique_values(metadata_list, "author"),
      tags: extract_unique_tags(metadata_list)
    }
  end

  # Helper function to get metadata from navigation item
  defp get_item_metadata(item) when is_map(item) do
    cond do
      Map.has_key?(item, :metadata) and is_map(item.metadata) -> item.metadata
      Map.has_key?(item, "metadata") and is_map(item["metadata"]) -> item["metadata"]
      true -> %{}
    end
  end

  defp get_item_metadata(_), do: %{}

  # Helper function to get title from navigation item
  defp get_item_title(item) when is_map(item) do
    cond do
      Map.has_key?(item, :title) and is_binary(item.title) -> item.title
      Map.has_key?(item, "title") and is_binary(item["title"]) -> item["title"]
      true -> ""
    end
  end

  defp get_item_title(_), do: ""

  # Extract unique values for a metadata field
  defp extract_unique_values(metadata_list, field) do
    metadata_list
    |> Enum.map(&Map.get(&1, field))
    |> Enum.filter(&(&1 != nil and &1 != ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Extract unique tags from all metadata
  defp extract_unique_tags(metadata_list) do
    metadata_list
    |> Enum.map(&Map.get(&1, "tags", []))
    |> Enum.filter(&is_list/1)
    |> List.flatten()
    |> Enum.filter(&(&1 != nil and &1 != ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

end