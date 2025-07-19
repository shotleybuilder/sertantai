defmodule SertantaiDocs.Integration do
  @moduledoc """
  Integration module for connecting the documentation app with the main Sertantai application.
  
  This module handles:
  - Content synchronization between docs-app and main app
  - File system monitoring for automatic updates
  - Cross-reference resolution
  - Development workflow integration
  """

  use GenServer
  require Logger

  alias SertantaiDocs.MarkdownProcessor

  @content_path Path.join([Application.app_dir(:sertantai_docs), "priv", "static", "docs"])

  # Client API

  @doc """
  Start the integration GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Manually trigger content synchronization.
  """
  def sync_content do
    GenServer.call(__MODULE__, :sync_content)
  end

  @doc """
  Get the status of the integration system.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Refresh navigation cache.
  """
  def refresh_navigation do
    GenServer.cast(__MODULE__, :refresh_navigation)
  end

  # Server Implementation

  @impl true
  def init(opts) do
    # Set up file system watcher if available
    watcher_pid = setup_file_watcher()
    
    state = %{
      watcher_pid: watcher_pid,
      last_sync: DateTime.utc_now(),
      content_cache: %{},
      navigation_cache: nil,
      sync_enabled: Keyword.get(opts, :sync_enabled, true)
    }
    
    # Perform initial sync
    if state.sync_enabled do
      send(self(), :initial_sync)
    end
    
    {:ok, state}
  end

  @impl true
  def handle_call(:sync_content, _from, state) do
    case perform_content_sync() do
      {:ok, stats} ->
        new_state = %{state | 
          last_sync: DateTime.utc_now(),
          content_cache: build_content_cache()
        }
        {:reply, {:ok, stats}, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      last_sync: state.last_sync,
      watcher_active: is_pid(state.watcher_pid) and Process.alive?(state.watcher_pid),
      content_files: count_content_files(),
      cache_size: map_size(state.content_cache)
    }
    {:reply, status, state}
  end

  @impl true
  def handle_cast(:refresh_navigation, state) do
    case MarkdownProcessor.generate_navigation() do
      {:ok, navigation} ->
        Logger.info("Navigation cache refreshed")
        {:noreply, %{state | navigation_cache: navigation}}
        
      {:error, reason} ->
        Logger.warning("Failed to refresh navigation: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:initial_sync, state) do
    Logger.info("Performing initial content synchronization...")
    
    case perform_content_sync() do
      {:ok, stats} ->
        Logger.info("Initial sync completed: #{inspect(stats)}")
        
      {:error, reason} ->
        Logger.error("Initial sync failed: #{inspect(reason)}")
    end
    
    {:noreply, %{state | last_sync: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:file_event, path, events}, state) do
    if String.ends_with?(path, ".md") and :modified in events do
      Logger.debug("Markdown file changed: #{path}")
      
      # Invalidate relevant caches
      relative_path = Path.relative_to(path, @content_path)
      new_cache = Map.delete(state.content_cache, relative_path)
      
      # Refresh navigation if needed
      send(self(), :refresh_navigation_async)
      
      {:noreply, %{state | content_cache: new_cache}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:refresh_navigation_async, state) do
    GenServer.cast(self(), :refresh_navigation)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private Functions

  defp setup_file_watcher do
    if Code.ensure_loaded?(FileSystem) do
      case FileSystem.start_link(dirs: [@content_path]) do
        {:ok, pid} ->
          FileSystem.subscribe(pid)
          pid
          
        {:error, reason} ->
          Logger.warning("Could not start file system watcher: #{inspect(reason)}")
          nil
      end
    else
      Logger.info("FileSystem not available, file watching disabled")
      nil
    end
  end

  defp perform_content_sync do
    try do
      # Scan all markdown files
      files = MarkdownProcessor.list_content_files()
      
      stats = %{
        files_scanned: length(files),
        articles_updated: 0,
        errors: []
      }
      
      # For now, just validate that files are readable
      # In the future, this could sync with Ash resources
      validated_files = 
        Enum.map(files, fn file_path ->
          case MarkdownProcessor.get_metadata(file_path) do
            {:ok, metadata} -> {:ok, file_path, metadata}
            {:error, reason} -> {:error, file_path, reason}
          end
        end)
      
      errors = 
        validated_files
        |> Enum.filter(&match?({:error, _, _}, &1))
        |> Enum.map(fn {:error, path, reason} -> {path, reason} end)
      
      updated_stats = %{stats | 
        articles_updated: length(validated_files) - length(errors),
        errors: errors
      }
      
      {:ok, updated_stats}
      
    rescue
      e -> {:error, {:sync_exception, e}}
    end
  end

  defp build_content_cache do
    case MarkdownProcessor.list_content_files() do
      {:error, _} -> %{}
      files ->
        Enum.reduce(files, %{}, fn file_path, acc ->
          case MarkdownProcessor.get_metadata(file_path) do
            {:ok, metadata} -> Map.put(acc, file_path, metadata)
            {:error, _} -> acc
          end
        end)
    end
  end

  defp count_content_files do
    case MarkdownProcessor.list_content_files() do
      {:error, _} -> 0
      files -> length(files)
    end
  end
end