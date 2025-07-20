defmodule SertantaiDocs.TOC.Generator do
  @moduledoc """
  Generates table of contents for markdown documents.
  
  Processes markdown to add anchor IDs, inject TOC at specified
  locations, and provide complete document processing.
  """

  alias MDEx
  alias SertantaiDocs.TOC.Extractor

  @doc """
  Adds anchor IDs to heading elements in HTML.
  
  Options:
  - :add_links - whether to add anchor links to headings (default: false)
  """
  def generate_anchors(html, opts \\ []) do
    add_links = Keyword.get(opts, :add_links, false)
    
    {result_html, _seen_ids} = 
      html
      |> String.split(~r/(<h[1-6][^>]*>.*?<\/h[1-6]>)/i, include_captures: true)
      |> Enum.reduce({"", %{}}, fn part, {acc_html, seen_ids} ->
        case Regex.match?(~r/^<h[1-6]/i, part) do
          true ->
            {updated_part, new_seen_ids} = process_heading(part, seen_ids, add_links)
            {acc_html <> updated_part, new_seen_ids}
          
          false ->
            {acc_html <> part, seen_ids}
        end
      end)
    
    result_html
  end

  @doc """
  Injects TOC into HTML at placeholder or specified location.
  
  Options:
  - :auto_inject - inject after first heading if no placeholder (default: false)
  - :max_level - maximum heading level to include
  - :title - TOC title (default: "Table of Contents")
  - :collapsible - make TOC collapsible (default: false)
  """
  def inject_toc(html, opts \\ []) do
    # Extract headings from HTML
    headings = extract_headings_from_html(html, opts)
    
    case headings do
      [] -> 
        html
      
      _ ->
        toc_html = generate_toc_html(headings, opts)
        
        cond do
          String.contains?(html, "<!-- TOC -->") ->
            # Replace only the first occurrence
            String.replace(html, "<!-- TOC -->", toc_html, global: false)
          
          Keyword.get(opts, :auto_inject, false) ->
            # Inject after first heading
            inject_after_first_heading(html, toc_html)
          
          true ->
            html
        end
    end
  end

  @doc """
  Processes a complete markdown document with TOC generation.
  
  Returns a map with:
  - :html - processed HTML with anchors and TOC
  - :toc - extracted TOC structure
  - :metadata - document metadata
  - :assets - any required JS/CSS assets
  """
  def process_document(markdown, opts \\ []) do
    # Extract frontmatter if present
    {metadata, content} = extract_frontmatter(markdown)
    
    # Merge metadata options with provided options
    opts = merge_metadata_options(metadata, opts)
    
    # Convert markdown to HTML (simplified - would use MDEx in real impl)
    html = markdown_to_html(content)
    
    # Add anchors to headings
    html_with_anchors = generate_anchors(html, add_links: true)
    
    # Extract TOC structure
    toc = Extractor.extract_toc(content, opts)
    
    # Process TOC injection based on options
    html_with_toc = process_toc_injection(html_with_anchors, toc, metadata, opts)
    
    # Add smooth scroll attributes if enabled
    final_html = add_smooth_scroll_attributes(html_with_toc, opts)
    
    # Generate required assets
    assets = generate_assets(opts)
    
    %{
      html: final_html,
      toc: toc,
      metadata: metadata,
      assets: assets
    }
  end

  # Private functions

  defp process_heading(heading_html, seen_ids, add_links) do
    case Regex.run(~r/<h([1-6])([^>]*)>(.*?)<\/h[1-6]>/i, heading_html) do
      [_full_match, level, attrs, content] ->
        # Check if ID already exists
        existing_id = extract_existing_id(attrs)
        
        # Get clean text for ID generation
        text = strip_html(content)
        base_id = existing_id || slugify(text)
        
        # Make ID unique
        {unique_id, new_seen_ids} = make_unique_id(base_id, seen_ids)
        
        # Build new heading
        new_attrs = case existing_id do
          nil -> add_id_to_attrs(attrs, unique_id)
          _ -> attrs
        end
        
        new_heading = "<h#{level}#{new_attrs}>#{content}"
        
        # Add anchor link if requested
        new_heading = case add_links do
          true -> new_heading <> build_anchor_link(unique_id, text)
          false -> new_heading
        end
        
        new_heading = new_heading <> "</h#{level}>"
        
        {new_heading, new_seen_ids}
      
      _ ->
        {heading_html, seen_ids}
    end
  end

  defp extract_existing_id(attrs) do
    case Regex.run(~r/id="([^"]+)"/, attrs) do
      [_, id] -> id
      _ -> nil
    end
  end

  defp strip_html(html) do
    html
    |> String.replace(~r/<[^>]+>/, "")
    |> String.trim()
  end

  defp slugify(text) do
    Extractor.slugify(text)
  end

  defp make_unique_id(base_id, seen_ids) do
    case Map.has_key?(seen_ids, base_id) do
      true ->
        count = seen_ids[base_id]
        unique_id = "#{base_id}-#{count}"
        new_seen_ids = Map.put(seen_ids, base_id, count + 1)
        {unique_id, new_seen_ids}
      
      false ->
        {base_id, Map.put(seen_ids, base_id, 1)}
    end
  end

  defp add_id_to_attrs("", id), do: " id=\"#{id}\""
  defp add_id_to_attrs(attrs, id), do: attrs <> " id=\"#{id}\""

  defp build_anchor_link(id, text) do
    ~s(<a href="##{id}" class="anchor-link" aria-label="Link to #{text}">
      <svg class="anchor-icon" viewBox="0 0 16 16" width="16" height="16">
        <path d="M4 9h1v1H4c-1.5 0-3-1.69-3-3.5S2.55 3 4 3h4c1.45 0 3 1.69 3 3.5 0 1.41-.91 2.72-2 3.25V8.59c.58-.45 1-1.27 1-2.09C10 5.22 8.98 4 8 4H4c-.98 0-2 1.22-2 2.5S3 9 4 9zm9-3h-1v1h1c1 0 2 1.22 2 2.5S13.98 12 13 12H9c-.98 0-2-1.22-2-2.5 0-.83.42-1.64 1-2.09V6.25c-1.09.53-2 1.84-2 3.25C6 11.31 7.55 13 9 13h4c1.45 0 3-1.69 3-3.5S14.5 6 13 6z"></path>
      </svg>
    </a>)
  end

  defp extract_headings_from_html(html, opts) do
    # Extract text content from headings
    ~r/<h([1-6])[^>]*>(.*?)<\/h[1-6]>/i
    |> Regex.scan(html)
    |> Enum.with_index(1)
    |> Enum.map(fn {[_, level, content], idx} ->
      level_int = String.to_integer(level)
      text = strip_html(content)
      id = extract_id_from_heading(content) || slugify(text)
      
      %{
        level: level_int,
        text: text,
        id: id,
        line: idx
      }
    end)
    |> Enum.filter(fn h ->
      max_level = Keyword.get(opts, :max_level, 6)
      h.level <= max_level
    end)
  end

  defp extract_id_from_heading(content) do
    case Regex.run(~r/id="([^"]+)"/, content) do
      [_, id] -> id
      _ -> nil
    end
  end

  defp generate_toc_html(headings, opts) do
    # Check for custom template function
    case Keyword.get(opts, :toc_template) do
      template_fn when is_function(template_fn) ->
        toc_data = %{
          headings: headings,
          tree: Extractor.build_toc_tree(headings),
          title: Keyword.get(opts, :title, "Table of Contents")
        }
        template_fn.(toc_data)
      
      _ ->
        # Default template
        tree = Extractor.build_toc_tree(headings)
        title = Keyword.get(opts, :title, "Table of Contents")
        collapsible = Keyword.get(opts, :collapsible, false)
        
        collapsible_attr = case collapsible do
          true -> ~s( data-collapsible="true")
          false -> ""
        end
        
        toggle_button = case collapsible do
          true -> ~s(<button class="toc-toggle">Toggle</button>)
          false -> ""
        end
        
        ~s(<nav class="table-of-contents"#{collapsible_attr}>
          <h2 class="toc-title">#{title}</h2>
          #{toggle_button}
          <ul class="toc-list">
            #{render_toc_tree(tree)}
          </ul>
        </nav>)
    end
  end

  defp render_toc_tree(nodes) do
    Enum.map_join(nodes, "\n", fn node ->
      children_html = case node.children do
        [] -> ""
        children -> "<ul>" <> render_toc_tree(children) <> "</ul>"
      end
      
      ~s(<li class="toc-item" data-level="#{node.level}">
        <a href="##{node.id}">#{node.text}</a>
        #{children_html}
      </li>)
    end)
  end

  defp inject_after_first_heading(html, toc_html) do
    case Regex.run(~r/(<h1[^>]*>.*?<\/h1>)/i, html, return: :index) do
      [{start_idx, length} | _] ->
        {before, after_with_heading} = String.split_at(html, start_idx)
        {heading, after_heading} = String.split_at(after_with_heading, length)
        before <> heading <> "\n" <> toc_html <> after_heading
      
      _ ->
        # No H1 found, prepend TOC
        toc_html <> "\n" <> html
    end
  end

  defp extract_frontmatter(markdown) do
    case Regex.run(~r/\A---\n(.*?)\n---\n?(.*)/s, markdown) do
      [_, yaml_content, content] ->
        # Parse YAML (simplified - would use YamlElixir in real impl)
        metadata = parse_yaml_simple(yaml_content)
        {metadata, content}
      
      _ ->
        {%{}, markdown}
    end
  end

  defp parse_yaml_simple(yaml) do
    yaml
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [key, value] ->
          key = String.trim(key)
          value = String.trim(value) |> String.trim("\"")
          
          # Handle simple type conversion
          parsed_value = cond do
            value == "true" -> true
            value == "false" -> false
            Regex.match?(~r/^\d+$/, value) -> String.to_integer(value)
            true -> value
          end
          
          Map.put(acc, String.to_atom(key), parsed_value)
        
        _ ->
          acc
      end
    end)
  end

  defp merge_metadata_options(metadata, opts) do
    # Apply metadata settings to options
    opts
    |> Keyword.put(:max_level, metadata[:toc_max_level] || Keyword.get(opts, :max_level))
    |> Keyword.put(:title, metadata[:toc_title] || Keyword.get(opts, :title))
  end

  defp markdown_to_html(markdown) do
    # Use MDEx for markdown to HTML conversion with proper configuration
    MDEx.to_html!(markdown, mdex_options_with_toc())
  end
  
  defp mdex_options_with_toc do
    # Use MarkdownProcessor options which now include header_ids
    if Code.ensure_loaded?(SertantaiDocs.MarkdownProcessor) do
      apply(SertantaiDocs.MarkdownProcessor, :mdex_options, [])
    else
      default_mdex_options()
    end
  end
  
  defp default_mdex_options do
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
        unsafe: false,
        escape: false,
        github_pre_lang: true,
        hardbreaks: false
      ]
    ]
  end

  defp process_toc_injection(html, toc, _metadata, opts) do
    html
    # Process all types of TOC placeholders in sequence
    |> process_basic_toc_placeholder(toc, opts)
    |> process_inline_toc_placeholder(toc, opts) 
    |> process_sidebar_toc_placeholder(toc, opts)
    |> process_custom_toc_tags(toc, opts)
    |> maybe_auto_inject_toc(toc, opts)
  end
  
  defp process_basic_toc_placeholder(html, toc, opts) do
    if String.contains?(html, "<!-- TOC -->") do
      toc_html = generate_toc_html(toc.headings, opts)
      String.replace(html, "<!-- TOC -->", toc_html, global: false)
    else
      html
    end
  end
  
  defp process_inline_toc_placeholder(html, toc, opts) do
    if String.contains?(html, "<!-- TOC inline -->") do
      inline_toc = generate_inline_toc_html(toc, opts)
      String.replace(html, "<!-- TOC inline -->", inline_toc)
    else
      html
    end
  end
  
  defp process_sidebar_toc_placeholder(html, toc, opts) do
    if String.contains?(html, "<!-- TOC sidebar -->") do
      sidebar_toc = generate_sidebar_toc_html(toc, opts)
      String.replace(html, "<!-- TOC sidebar -->", sidebar_toc)
    else
      html
    end
  end
  
  defp maybe_auto_inject_toc(html, toc, opts) do
    # Only auto-inject if no placeholders were found and auto_inject is enabled OR custom template is provided
    has_placeholders = String.contains?(html, "<!-- TOC") or String.contains?(html, "[TOC")
    auto_inject = Keyword.get(opts, :auto_inject, false)
    has_custom_template = Keyword.has_key?(opts, :toc_template)
    
    if not has_placeholders and (auto_inject or has_custom_template) do
      inject_after_first_heading(html, generate_toc_html(toc.headings, opts))
    else
      html
    end
  end

  defp generate_inline_toc_html(toc, _opts) do
    ~s(<div class="inline-toc">
      <details>
        <summary>Table of Contents</summary>
        <ul>
          #{render_toc_tree(toc.tree)}
        </ul>
      </details>
    </div>)
  end

  defp generate_sidebar_toc_html(toc, _opts) do
    ~s(<aside class="sidebar-toc">
      <nav>
        <h3>On This Page</h3>
        <ul>
          #{render_toc_tree(toc.tree)}
        </ul>
      </nav>
    </aside>)
  end

  defp process_custom_toc_tags(html, toc, opts) do
    Regex.replace(~r/\[TOC([^\]]*)\]/, html, fn _, attrs ->
      attrs_map = parse_toc_attrs(attrs)
      
      position = attrs_map["position"] || "inline"
      sticky = attrs_map["sticky"] == "true"
      
      sticky_attr = case sticky do
        true -> ~s( data-toc-sticky="true")
        false -> ""
      end
      
      ~s(<div class="toc-container" data-toc-position="#{position}"#{sticky_attr}>
        #{generate_toc_html(toc.headings, opts)}
      </div>)
    end)
  end

  defp parse_toc_attrs(attrs_str) do
    ~r/(\w+)="([^"]+)"/
    |> Regex.scan(attrs_str)
    |> Enum.map(fn [_, key, value] -> {key, value} end)
    |> Map.new()
  end

  defp add_smooth_scroll_attributes(html, opts) do
    if Keyword.get(opts, :smooth_scroll, false) do
      # Wrap the content with smooth scroll attributes
      ~s(<div data-smooth-scroll="true">#{html}</div>)
    else
      html
    end
  end

  defp generate_assets(opts) do
    js = case Keyword.get(opts, :smooth_scroll, false) do
      true ->
        """
        function smoothScrollToSection(sectionId) {
          const element = document.getElementById(sectionId);
          if (element) {
            element.scrollIntoView({ behavior: 'smooth', block: 'start' });
          }
        }
        """
      
      false ->
        ""
    end
    
    %{js: js, css: ""}
  end
end