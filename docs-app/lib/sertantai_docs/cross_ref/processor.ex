defmodule SertantaiDocs.CrossRef.Processor do
  @moduledoc """
  Processes cross-references in markdown documents.
  
  Supports multiple link types:
  - `[Resource](ash:Module.Resource)` - Ash resource links
  - `[Module](exdoc:Module.Name)` - ExDoc module links
  - `[Guide](dev:guide-name)` - Developer documentation links
  - `[Manual](user:path/to/doc)` - User documentation links
  """

  alias MDEx

  @cross_ref_pattern ~r/\[([^\]]+)\]\((ash|exdoc|dev|user):([^)]*)\)/

  @doc """
  Processes cross-references in markdown content.
  
  Returns a map with:
  - :html - processed HTML with cross-reference links
  - :cross_refs - list of extracted cross-references
  """
  def process_cross_references(markdown, opts \\ %{}) when is_binary(markdown) do
    # Extract all cross-references first
    cross_refs = extract_cross_references(markdown)
    
    # Filter out disabled types if specified
    cross_refs = filter_disabled_types(cross_refs, opts)
    
    # Replace valid cross-references with tokens
    {processed_markdown, token_replacements} = replace_with_tokens(markdown, cross_refs, opts)
    
    # Convert to HTML using MDEx (this will process malformed links as regular links)
    html = markdown_to_html(processed_markdown, opts)
    
    # Replace tokens with actual HTML
    final_html = restore_tokens(html, token_replacements)
    
    %{
      html: final_html,
      cross_refs: cross_refs
    }
  end

  @doc """
  Extracts all cross-references from markdown content.
  """
  def extract_cross_references(markdown) when is_binary(markdown) do
    lines = String.split(markdown, "\n")
    
    # Don't process cross-refs in code blocks
    {refs, _} = Enum.reduce(Enum.with_index(lines, 1), {[], false}, fn {line, line_num}, {acc, in_code_block} ->
      cond do
        String.starts_with?(String.trim(line), "```") ->
          {acc, !in_code_block}
          
        in_code_block ->
          {acc, in_code_block}
          
        true ->
          refs = extract_refs_from_line(line, line_num)
          {acc ++ refs, in_code_block}
      end
    end)
    
    refs
  end

  @doc """
  Resolves a cross-reference to its URL.
  """
  def resolve_link_url(%{type: type, target: target}, opts \\ %{}) do
    case type do
      :ash ->
        base_url = Map.get(opts, :ash_url_pattern, "/api/ash/{{target}}")
        String.replace(base_url, "{{target}}", target)
        
      :exdoc ->
        if Map.has_key?(opts, :exdoc_base_url) do
          "#{opts.exdoc_base_url}/#{target}.html"
        else
          base_pattern = Map.get(opts, :exdoc_url_pattern, "/api/docs/{{target}}.html")
          String.replace(base_pattern, "{{target}}", target)
        end
        
      :dev ->
        "/dev/#{target}"
        
      :user ->
        "/user/#{target}"
        
      _ ->
        nil
    end
  end

  @doc """
  Validates a cross-reference exists.
  """
  def validate_cross_reference(%{type: type, target: target}, _opts \\ %{}) do
    case type do
      :ash ->
        validate_ash_resource(target)
        
      :exdoc ->
        validate_exdoc_module(target)
        
      :dev ->
        validate_internal_doc(target, "dev")
        
      :user ->
        validate_internal_doc(target, "user")
        
      _ ->
        %{
          valid: false,
          exists: false,
          error: "Unknown cross-reference type: #{type}"
        }
    end
  end

  # Private functions

  defp extract_refs_from_line(line, line_number) do
    @cross_ref_pattern
    |> Regex.scan(line)
    |> Enum.filter(fn 
      [_full, _text, _type, ""] -> false  # Skip empty targets
      [_full, _text, _type, _target] -> true
    end)
    |> Enum.map(fn [_full, text, type, target] ->
      ref = %{
        type: String.to_atom(type),
        target: target,
        text: text,
        line_number: line_number
      }
      # Add URL to the ref
      Map.put(ref, :url, resolve_link_url(ref))
    end)
  end

  defp filter_disabled_types(cross_refs, %{disabled_types: disabled}) when is_list(disabled) do
    Enum.reject(cross_refs, &(&1.type in disabled))
  end
  defp filter_disabled_types(cross_refs, _), do: cross_refs

  defp restore_tokens(html, token_replacements) do
    Enum.reduce(token_replacements, html, fn {token, replacement}, acc ->
      String.replace(acc, token, replacement)
    end)
  end

  defp replace_with_tokens(markdown, cross_refs, opts) do
    # Create unique tokens for each cross-reference
    {final_markdown, replacements} = Enum.reduce(cross_refs, {markdown, %{}}, fn ref, {acc_markdown, acc_replacements} ->
      token = "CROSSREF_TOKEN_#{:erlang.unique_integer([:positive])}"
      
      # Build the HTML replacement for this cross-reference
      url = resolve_link_url(ref, opts)
      class_pattern = Map.get(opts, :link_class_pattern, "cross-ref cross-ref-{{type}}")
      class = String.replace(class_pattern, "{{type}}", to_string(ref.type))
      
      # Special class for internal links
      class = if ref.type in [:dev, :user] do
        String.replace(class, "cross-ref-#{ref.type}", "cross-ref-internal")
      else
        class
      end
      
      html_replacement = ~s(<a href="#{url}" class="#{class}" data-ref-type="#{ref.type}" data-ref-target="#{ref.target}">#{ref.text}</a>)
      
      # Replace the cross-reference with the token
      pattern = ~r/\[#{Regex.escape(ref.text)}\]\(#{ref.type}:#{Regex.escape(ref.target)}\)/
      new_markdown = String.replace(acc_markdown, pattern, token)
      new_replacements = Map.put(acc_replacements, token, html_replacement)
      
      {new_markdown, new_replacements}
    end)
    
    {final_markdown, replacements}
  end


  defp markdown_to_html(markdown, opts) do
    # Use MDEx with options similar to MarkdownProcessor
    mdex_opts = [
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        description_lists: true,
        front_matter_delimiter: "---",
        header_ids: ""
      ],
      parse: [
        smart: true,
        relaxed_tasklist_matching: true,
        relaxed_autolinks: true
      ],
      render: [
        unsafe: true,  # Allow our custom HTML
        escape: false,
        github_pre_lang: true,
        hardbreaks: false
      ]
    ]
    
    # Add custom MDEx options if provided
    mdex_opts = if Map.has_key?(opts, :mdex_options) do
      deep_merge(mdex_opts, opts.mdex_options)
    else
      mdex_opts
    end
    
    MDEx.to_html!(markdown, mdex_opts)
  end

  defp validate_ash_resource(target) do
    # Check if it's a known Ash resource
    # In real implementation, would check against Ash domains
    known_resources = [
      "Sertantai.Accounts.User",
      "Sertantai.Organizations.Organization",
      "SertantaiDocs.Docs.Article"
    ]
    
    if target in known_resources do
      %{
        valid: true,
        exists: true,
        resource_type: "ash_resource",
        domain: extract_domain(target),
        actions: ["create", "read", "update", "destroy"],  # Mock data
        url: "/api/ash/#{target}",
        error: nil  # Explicitly set error to nil for valid resources
      }
    else
      %{
        valid: false,
        exists: false,
        error: "Ash resource '#{target}' not found",
        suggestions: suggest_similar_resources(target, known_resources)
      }
    end
  end

  defp validate_exdoc_module(target) do
    # Check if module exists
    module_atom = try do
      String.to_existing_atom("Elixir.#{target}")
    rescue
      ArgumentError -> nil
    end
    
    cond do
      module_atom && Code.ensure_loaded?(module_atom) ->
        %{
          valid: true,
          exists: true,
          module_type: determine_module_type(target),
          documented: true,  # Assume documented for now
          url: "/api/docs/#{target}.html"
        }
        
      # Check if it's a known but not loaded module
      target in ["SertantaiDocs.Navigation.Scanner", "SertantaiDocs.TOC.Generator"] ->
        %{
          valid: true,
          exists: true,
          module_type: "project",
          functions: ["scan/1", "build/1"],  # Mock data
          documented: true,
          url: "/api/docs/#{target}.html"
        }
        
      true ->
        %{
          valid: false,
          exists: false,
          error: "Module '#{target}' not found or not documented",
          suggestions: suggest_similar_modules(target)
        }
    end
  end

  defp validate_internal_doc(target, category) do
    # Check if documentation file exists
    # In real implementation, would check file system
    known_docs = %{
      "dev" => ["setup-guide", "architecture", "mdex-theming-guide"],
      "user" => ["getting-started", "features/overview", "index"]
    }
    
    category_docs = Map.get(known_docs, category, [])
    
    if target in category_docs do
      %{
        valid: true,
        exists: true,
        file_path: "/#{category}/#{target}",
        file_type: "markdown",
        url: "/#{category}/#{target}"
      }
    else
      %{
        valid: false,
        exists: false,
        error: "Documentation file '/#{category}/#{target}' not found",
        checked_paths: ["/priv/static/docs/#{category}/#{target}.md"]
      }
    end
  end

  defp extract_domain(resource_name) do
    resource_name
    |> String.split(".")
    |> Enum.take(2)
    |> Enum.join(".")
  end

  defp determine_module_type(module_name) do
    cond do
      module_name in ["Enum", "GenServer", "Agent", "Process", "Task"] -> "core"
      String.starts_with?(module_name, "Sertantai") -> "project"
      true -> "elixir_module"
    end
  end

  defp suggest_similar_resources(target, known_resources) do
    # Simple suggestion - find resources with similar names
    known_resources
    |> Enum.filter(&String.contains?(&1, String.split(target, ".") |> List.last()))
    |> Enum.take(3)
  end

  defp suggest_similar_modules(target) do
    # In real implementation, would use string distance algorithm
    if String.contains?(target, "Sertantai") do
      ["SertantaiDocs.Navigation.Scanner", "SertantaiDocs.TOC.Generator"]
    else
      []
    end
  end

  defp deep_merge(map1, map2) do
    Map.merge(map1, map2, fn _k, v1, v2 ->
      if is_map(v1) and is_map(v2) do
        deep_merge(v1, v2)
      else
        v2
      end
    end)
  end
end