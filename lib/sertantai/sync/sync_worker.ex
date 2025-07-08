defmodule Sertantai.Sync.SyncWorker do
  @moduledoc """
  Worker for handling background sync operations.
  Can be extended with Oban for more advanced job processing.
  """

  use GenServer
  require Logger
  require Ash.Query
  import Ash.Expr
  alias Sertantai.Sync.SyncService

  # Client API

  @doc """
  Start the sync worker.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Schedule a sync operation for a configuration.
  """
  def schedule_sync(sync_config_id) do
    GenServer.cast(__MODULE__, {:sync, sync_config_id})
  end

  @doc """
  Schedule a sync operation for all active configurations.
  """
  def schedule_all_active_syncs do
    GenServer.cast(__MODULE__, :sync_all_active)
  end

  @doc """
  Get the current sync queue status.
  """
  def queue_status do
    GenServer.call(__MODULE__, :queue_status)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    # Set up a periodic sync check (every hour by default)
    sync_interval = Keyword.get(opts, :sync_interval, :timer.hours(1))
    
    if sync_interval > 0 do
      Process.send_after(self(), :periodic_sync, sync_interval)
    end

    {:ok, %{
      queue: [],
      processing: false,
      sync_interval: sync_interval,
      last_sync: nil
    }}
  end

  @impl true
  def handle_cast({:sync, sync_config_id}, state) do
    new_queue = if sync_config_id in state.queue do
      state.queue  # Already queued
    else
      state.queue ++ [sync_config_id]
    end
    
    new_state = %{state | queue: new_queue}
    
    # Start processing if not already processing
    if not state.processing and length(new_queue) > 0 do
      send(self(), :process_queue)
    end
    
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:sync_all_active, state) do
    case load_active_sync_configurations() do
      {:ok, configs} ->
        config_ids = Enum.map(configs, & &1.id)
        new_queue = Enum.reduce(config_ids, state.queue, fn id, acc ->
          if id in acc, do: acc, else: acc ++ [id]
        end)
        
        new_state = %{state | queue: new_queue}
        
        # Start processing if not already processing
        if not state.processing and length(new_queue) > 0 do
          send(self(), :process_queue)
        end
        
        {:noreply, new_state}
      
      {:error, reason} ->
        Logger.error("Failed to load active sync configurations: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:queue_status, _from, state) do
    status = %{
      queue_length: length(state.queue),
      processing: state.processing,
      last_sync: state.last_sync
    }
    {:reply, status, state}
  end

  @impl true
  def handle_info(:process_queue, %{queue: []} = state) do
    {:noreply, %{state | processing: false}}
  end

  @impl true
  def handle_info(:process_queue, %{queue: [sync_config_id | rest]} = state) do
    Logger.info("Processing sync for configuration: #{sync_config_id}")
    
    # Process the sync in a separate task to avoid blocking
    Task.start(fn ->
      case SyncService.sync_configuration(sync_config_id) do
        {:ok, _} -> 
          Logger.info("Sync completed for configuration: #{sync_config_id}")
        {:error, reason} -> 
          Logger.error("Sync failed for configuration: #{sync_config_id}, reason: #{inspect(reason)}")
      end
      
      # Continue processing the queue
      send(__MODULE__, :process_queue)
    end)
    
    new_state = %{state | 
      queue: rest, 
      processing: true,
      last_sync: DateTime.utc_now()
    }
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:periodic_sync, state) do
    Logger.info("Running periodic sync check")
    
    # Schedule syncs for configurations that need automatic syncing
    case load_configurations_for_periodic_sync() do
      {:ok, configs} ->
        Enum.each(configs, fn config ->
          if should_sync_now?(config) do
            schedule_sync(config.id)
          end
        end)
      
      {:error, reason} ->
        Logger.error("Failed to load configurations for periodic sync: #{inspect(reason)}")
    end
    
    # Schedule next periodic sync
    if state.sync_interval > 0 do
      Process.send_after(self(), :periodic_sync, state.sync_interval)
    end
    
    {:noreply, state}
  end

  # Helper functions

  defp load_active_sync_configurations do
    Ash.read(
      Sertantai.Sync.SyncConfiguration
      |> Ash.Query.filter(expr(is_active == true)),
      domain: Sertantai.Sync
    )
  end

  defp load_configurations_for_periodic_sync do
    Ash.read(
      Sertantai.Sync.SyncConfiguration
      |> Ash.Query.filter(expr(is_active == true and sync_frequency != :manual)),
      domain: Sertantai.Sync
    )
  end

  defp should_sync_now?(config) do
    case config.sync_frequency do
      :manual -> false
      :hourly -> sync_due?(config.last_synced_at, :timer.hours(1))
      :daily -> sync_due?(config.last_synced_at, :timer.hours(24))
      :weekly -> sync_due?(config.last_synced_at, :timer.hours(24 * 7))
      _ -> false
    end
  end

  defp sync_due?(nil, _interval), do: true
  defp sync_due?(last_synced_at, interval) do
    time_since_last_sync = DateTime.diff(DateTime.utc_now(), last_synced_at, :millisecond)
    time_since_last_sync >= interval
  end
end