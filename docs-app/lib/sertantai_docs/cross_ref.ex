defmodule SertantaiDocs.CrossRef do
  @moduledoc """
  Main API for the cross-reference system.
  
  Provides high-level functions for processing documents with cross-references,
  including extraction, validation, and preview generation.
  """
  
  alias SertantaiDocs.CrossRef.{Processor, Validator}
  
  @doc """
  Processes a document with cross-references.
  
  Options:
  - :validate_cross_refs - Whether to validate cross-references (default: false)
  - :fail_on_broken_links - Whether to fail processing on broken links (default: false)
  - :generate_previews - Whether to generate preview data (default: false)
  - :generate_error_reports - Whether to generate detailed error reports (default: false)
  - :export_data - Whether to export structured data (default: false)
  - :concurrent - Whether to use concurrent processing (default: false)
  - :cache - Whether to use caching (default: false)
  - :cache_key - Key for caching results
  - :enable_hover_tooltips - Whether to enable hover tooltips (default: false)
  
  Returns a map with:
  - :success - Whether processing was successful
  - :html - Processed HTML with cross-references
  - :cross_refs - List of extracted cross-references
  - :validation_report - Validation report (if validate_cross_refs is true)
  - :error_report - Error report (if generate_error_reports is true)
  - :export_data - Exported data (if export_data is true)
  - :cache_hit - Whether result was served from cache (if cache is true)
  """
  def process_document(markdown, opts \\ %{}) when is_binary(markdown) do
    cache_key = Map.get(opts, :cache_key)
    use_cache = Map.get(opts, :cache, false)
    
    # Check cache if enabled
    cached_result = if use_cache && cache_key, do: get_from_cache(cache_key), else: nil
    
    if cached_result do
      Map.put(cached_result, :cache_hit, true)
    else
      # Process the document
      result = do_process_document(markdown, opts)
      
      # Cache if enabled
      if use_cache && cache_key do
        put_in_cache(cache_key, result)
      end
      
      Map.put(result, :cache_hit, false)
    end
  end
  
  @doc """
  Processes multiple documents concurrently.
  """
  def process_documents(documents, opts \\ %{}) when is_list(documents) do
    max_workers = Map.get(opts, :max_workers, 4)
    timeout = Map.get(opts, :timeout, 30_000)
    
    # Use Task.async_stream for concurrent processing
    documents
    |> Task.async_stream(
      fn doc -> process_document(doc, Map.put(opts, :concurrent, true)) end,
      max_concurrency: max_workers,
      timeout: timeout,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, :timeout} -> %{success: false, error: "Processing timeout"}
    end)
  end
  
  @doc """
  Configures the cross-reference system globally.
  """
  def configure(config) do
    # Store configuration in application environment
    Application.put_env(:sertantai_docs, :cross_ref_config, config)
    :ok
  end
  
  @doc """
  Validates configuration options.
  """
  def validate_configuration(config) do
    errors = []
    warnings = []
    
    # Validate URLs
    errors = if config[:ash_base_url] && !valid_url?(config[:ash_base_url]) do
      ["Invalid ash_base_url" | errors]
    else
      errors
    end
    
    # Validate cache TTL
    errors = if config[:cache_ttl] && config[:cache_ttl] < 0 do
      ["Invalid cache_ttl" | errors]
    else
      errors
    end
    
    # Check for unknown options
    known_options = [:ash_base_url, :exdoc_base_url, :internal_base_url, 
                     :enable_validation, :enable_previews, :cache_ttl]
    unknown = Map.keys(config) -- known_options
    
    warnings = if length(unknown) > 0 do
      Enum.map(unknown, &"Unknown option: #{&1}") ++ warnings
    else
      warnings
    end
    
    %{
      valid: length(errors) == 0,
      errors: errors,
      warnings: warnings
    }
  end
  
  @doc """
  Invalidates cached results for a given key.
  """
  def invalidate_cache(cache_key) do
    # Simple in-memory cache for now
    Process.delete({:cross_ref_cache, cache_key})
    :ok
  end
  
  # Private functions
  
  defp do_process_document(markdown, opts) do
    try do
      # Extract title from markdown
      title = extract_title(markdown)
      
      # Process cross-references
      processor_result = Processor.process_cross_references(markdown, opts)
      
      # Validate if requested
      validation_report = if Map.get(opts, :validate_cross_refs, false) do
        Validator.validate_document(markdown, Map.put(opts, :file_path, title))
      end
      
      # Generate preview data if requested
      cross_refs_with_preview = if Map.get(opts, :generate_previews, false) do
        Enum.map(processor_result.cross_refs, &add_preview_data(&1, opts))
      else
        processor_result.cross_refs
      end
      
      # Generate error report if requested
      error_report = if Map.get(opts, :generate_error_reports, false) && validation_report do
        generate_error_report(validation_report)
      end
      
      # Handle failure on broken links
      if Map.get(opts, :fail_on_broken_links, false) && 
         validation_report && validation_report.has_errors do
        raise Validator.BrokenLinksError, broken_links: validation_report.cross_refs
      end
      
      # Build export data if requested
      export_data = if Map.get(opts, :export_data, false) do
        build_export_data(title, cross_refs_with_preview, validation_report)
      end
      
      # Build performance metrics
      performance_metrics = if Map.get(opts, :concurrent, false) do
        %{
          processing_time: 0,  # Would be tracked in real implementation
          cross_refs_per_second: length(processor_result.cross_refs) / 1.0
        }
      end
      
      %{
        success: true,
        html: processor_result.html,
        cross_refs: cross_refs_with_preview,
        validation_report: validation_report,
        error_report: error_report,
        export_data: export_data,
        toc: nil,  # Would be extracted if MDEx TOC integration exists
        performance_metrics: performance_metrics,
        processing_info: %{concurrent: Map.get(opts, :concurrent, false)}
      }
    rescue
      e in Validator.BrokenLinksError ->
        %{
          success: false,
          error: e.message,
          broken_links: e.broken_links,
          html: "",
          cross_refs: []
        }
      e ->
        %{
          success: false,
          error: inspect(e),
          html: "",
          cross_refs: []
        }
    end
  end
  
  defp extract_title(markdown) do
    case Regex.run(~r/^#\s+(.+)$/m, markdown) do
      [_, title] -> String.trim(title)
      _ -> "Untitled"
    end
  end
  
  defp add_preview_data(cross_ref, _opts) do
    # In a real implementation, this would fetch actual preview data
    # For now, we'll add mock data based on type
    preview_data = case cross_ref.type do
      :ash ->
        %{
          resource_type: "ash_resource",
          domain: extract_domain(cross_ref.target),
          actions: ["create", "read", "update", "destroy"],
          description: "Resource for #{cross_ref.target}"
        }
        
      :exdoc ->
        %{
          module_type: "elixir_module",
          functions: ["function1/1", "function2/2"],
          description: "Module documentation for #{cross_ref.target}"
        }
        
      type when type in [:dev, :user] ->
        %{
          title: humanize_target(cross_ref.target),
          category: String.capitalize(to_string(type)),
          description: "Documentation for #{cross_ref.target}"
        }
        
      _ ->
        nil
    end
    
    if preview_data do
      Map.put(cross_ref, :preview_data, preview_data)
    else
      cross_ref
    end
  end
  
  defp generate_error_report(validation_report) do
    broken_count = validation_report.invalid_count
    
    %{
      broken_links: broken_count,
      total_links: validation_report.total_count,
      success_rate: if(validation_report.total_count > 0,
        do: (validation_report.valid_count / validation_report.total_count) * 100,
        else: 100.0
      ),
      errors: Enum.filter(validation_report.cross_refs, &(&1[:valid] == false))
    }
  end
  
  defp build_export_data(title, cross_refs, validation_report) do
    data = %{
      document_title: title,
      cross_references: cross_refs,
      cross_reference_types: cross_refs |> Enum.map(& &1.type) |> Enum.uniq() |> Enum.sort(),
      validation_summary: if(validation_report, do: validation_report.summary, else: nil)
    }
    
    # Generate multiple export formats
    %{
      document_title: title,
      cross_references: cross_refs,
      cross_reference_types: data.cross_reference_types,
      validation_summary: data.validation_summary,
      formats: %{
        json: Jason.encode!(data),
        yaml: "# YAML export not implemented",
        csv: "# CSV export not implemented"
      }
    }
  end
  
  defp get_from_cache(cache_key) do
    Process.get({:cross_ref_cache, cache_key})
  end
  
  defp put_in_cache(cache_key, result) do
    Process.put({:cross_ref_cache, cache_key}, result)
  end
  
  defp valid_url?(url) do
    String.starts_with?(url, "/") || String.starts_with?(url, "http")
  end
  
  defp extract_domain(resource) do
    resource
    |> String.split(".")
    |> Enum.take(2)
    |> Enum.join(".")
  end
  
  defp humanize_target(target) do
    target
    |> String.split("/")
    |> List.last()
    |> String.replace("-", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end