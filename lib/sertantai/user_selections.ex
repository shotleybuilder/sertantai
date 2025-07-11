defmodule Sertantai.UserSelections do
  @moduledoc """
  Manages user record selections with hybrid ETS + Database persistence.
  Provides fast access via ETS with persistent storage and audit logging.
  """
  
  use GenServer
  import Ecto.Query
  require Logger
  
  alias Sertantai.Repo
  
  @table_name :user_selections
  @sync_interval :timer.minutes(1) # Sync ETS to DB every minute
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :public, :named_table])
    
    # Schedule periodic sync to database
    Process.send_after(self(), :sync_to_database, @sync_interval)
    
    Logger.info("UserSelections started with ETS table: #{@table_name}")
    {:ok, %{table: table, pending_syncs: MapSet.new()}}
  end
  
  @doc "Store selected record IDs for a user"
  def store_selections(user_id, selected_ids, opts \\ []) when is_list(selected_ids) do
    timestamp = DateTime.utc_now()
    :ets.insert(@table_name, {user_id, selected_ids, timestamp})
    
    # Mark user for database sync if immediate sync not requested
    unless Keyword.get(opts, :skip_sync, false) do
      GenServer.cast(__MODULE__, {:mark_for_sync, user_id})
    end
    
    # Immediate database sync if requested
    if Keyword.get(opts, :immediate_sync, false) do
      sync_user_to_database(user_id)
    end
    
    :ok
  end
  
  @doc "Retrieve selected record IDs for a user"
  def get_selections(user_id) do
    case :ets.lookup(@table_name, user_id) do
      [{^user_id, selected_ids, _timestamp}] -> 
        selected_ids
      [] -> 
        # ETS miss - try loading from database
        load_from_database(user_id)
    end
  end
  
  @doc "Clear selected record IDs for a user"
  def clear_selections(user_id, opts \\ []) do
    :ets.delete(@table_name, user_id)
    
    # Clear from database as well
    clear_from_database(user_id)
    
    # Log audit trail
    audit_action(user_id, nil, "clear_all", opts)
    
    :ok
  end
  
  @doc "Add a record ID to user's selections"
  def add_selection(user_id, record_id, opts \\ []) do
    current_selections = get_selections(user_id)
    
    unless record_id in current_selections do
      updated_selections = [record_id | current_selections]
      store_selections(user_id, updated_selections, opts)
      
      # Log audit trail
      audit_action(user_id, record_id, "select", opts)
    end
    
    :ok
  end
  
  @doc "Remove a record ID from user's selections"
  def remove_selection(user_id, record_id, opts \\ []) do
    current_selections = get_selections(user_id)
    
    if record_id in current_selections do
      updated_selections = List.delete(current_selections, record_id)
      store_selections(user_id, updated_selections, opts)
      
      # Log audit trail
      audit_action(user_id, record_id, "deselect", opts)
    end
    
    :ok
  end
  
  @doc "Get count of selected records for a user"
  def selection_count(user_id) do
    get_selections(user_id) |> length()
  end
  
  @doc "Bulk update selections for a user"
  def bulk_update_selections(user_id, selected_ids, opts \\ []) when is_list(selected_ids) do
    current_selections = get_selections(user_id)
    
    # Find newly selected and deselected records
    newly_selected = selected_ids -- current_selections
    newly_deselected = current_selections -- selected_ids
    
    # Store the new selections
    store_selections(user_id, selected_ids, opts)
    
    # Log audit trails for bulk changes
    if length(newly_selected) > 0 do
      audit_bulk_action(user_id, newly_selected, "bulk_select", opts)
    end
    
    if length(newly_deselected) > 0 do
      audit_bulk_action(user_id, newly_deselected, "bulk_deselect", opts)
    end
    
    :ok
  end
  
  @doc "Force sync all pending users to database"
  def sync_all_to_database do
    GenServer.call(__MODULE__, :sync_all_to_database)
  end
  
  @doc "Force sync specific user to database"
  def sync_user_to_database(user_id) do
    GenServer.call(__MODULE__, {:sync_user_to_database, user_id})
  end
  
  # GenServer callbacks
  
  def handle_cast({:mark_for_sync, user_id}, %{pending_syncs: pending} = state) do
    {:noreply, %{state | pending_syncs: MapSet.put(pending, user_id)}}
  end
  
  def handle_call(:sync_all_to_database, _from, %{pending_syncs: pending} = state) do
    results = Enum.map(pending, &do_sync_user_to_database/1)
    {:reply, results, %{state | pending_syncs: MapSet.new()}}
  end
  
  def handle_call({:sync_user_to_database, user_id}, _from, %{pending_syncs: pending} = state) do
    result = do_sync_user_to_database(user_id)
    new_pending = MapSet.delete(pending, user_id)
    {:reply, result, %{state | pending_syncs: new_pending}}
  end
  
  def handle_info(:sync_to_database, %{pending_syncs: pending} = state) do
    # Sync pending users to database
    if MapSet.size(pending) > 0 do
      Logger.debug("Syncing #{MapSet.size(pending)} users to database")
      Enum.each(pending, &do_sync_user_to_database/1)
    end
    
    # Schedule next sync
    Process.send_after(self(), :sync_to_database, @sync_interval)
    
    {:noreply, %{state | pending_syncs: MapSet.new()}}
  end
  
  # Private functions
  
  defp load_from_database(user_id) do
    try do
      # Ensure user_id is in proper UUID binary format
      user_uuid = case user_id do
        id when is_binary(id) -> 
          case Ecto.UUID.cast(id) do
            {:ok, uuid} -> Ecto.UUID.dump!(uuid)
            :error -> id
          end
        id -> id
      end
      
      query = from s in "user_record_selections",
              where: s.user_id == ^user_uuid,
              select: s.record_id
      
      selected_ids = Repo.all(query)
      
      # Store in ETS for future fast access
      :ets.insert(@table_name, {user_id, selected_ids, DateTime.utc_now()})
      
      selected_ids
    rescue
      error ->
        Logger.error("Failed to load selections from database for user #{user_id}: #{inspect(error)}")
        []
    end
  end
  
  defp do_sync_user_to_database(user_id) do
    case :ets.lookup(@table_name, user_id) do
      [{^user_id, selected_ids, _timestamp}] ->
        sync_selections_to_database(user_id, selected_ids)
      [] ->
        {:ok, :no_data}
    end
  end
  
  defp sync_selections_to_database(user_id, selected_ids) do
    try do
      # Ensure UUIDs are in proper binary format
      user_uuid = case Ecto.UUID.cast(user_id) do
        {:ok, uuid} -> Ecto.UUID.dump!(uuid)
        :error -> user_id
      end
      
      Repo.transaction(fn ->
        # Delete existing selections for this user
        from(s in "user_record_selections", where: s.user_id == ^user_uuid)
        |> Repo.delete_all()
        
        # Insert new selections
        selections = Enum.map(selected_ids, fn record_id ->
          record_uuid = case Ecto.UUID.cast(record_id) do
            {:ok, uuid} -> Ecto.UUID.dump!(uuid)
            :error -> record_id
          end
          
          %{
            id: Ecto.UUID.dump!(Ecto.UUID.generate()),
            user_id: user_uuid,
            record_id: record_uuid,
            selection_group: "default",
            metadata: %{},
            inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
            updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
          }
        end)
        
        if length(selections) > 0 do
          Repo.insert_all("user_record_selections", selections)
        end
      end)
      
      {:ok, :synced}
    rescue
      error ->
        Logger.error("Failed to sync selections to database for user #{user_id}: #{inspect(error)}")
        {:error, error}
    end
  end
  
  defp clear_from_database(user_id) do
    try do
      user_uuid = case Ecto.UUID.cast(user_id) do
        {:ok, uuid} -> Ecto.UUID.dump!(uuid)
        :error -> user_id
      end
      
      from(s in "user_record_selections", where: s.user_id == ^user_uuid)
      |> Repo.delete_all()
    rescue
      error ->
        Logger.error("Failed to clear selections from database for user #{user_id}: #{inspect(error)}")
    end
  end
  
  defp audit_action(user_id, record_id, action, opts) do
    spawn(fn ->
      try do
        user_uuid = case Ecto.UUID.cast(user_id) do
          {:ok, uuid} -> Ecto.UUID.dump!(uuid)
          :error -> user_id
        end
        
        record_uuid = case record_id do
          nil -> nil
          id -> 
            case Ecto.UUID.cast(id) do
              {:ok, uuid} -> Ecto.UUID.dump!(uuid)
              :error -> id
            end
        end
        
        # Parse IP address if it's a string
        ip_address = case Keyword.get(opts, :ip_address) do
          ip when is_binary(ip) ->
            case :inet.parse_address(String.to_charlist(ip)) do
              {:ok, parsed_ip} -> parsed_ip
              {:error, _} -> nil
            end
          ip -> ip
        end
        
        audit_data = %{
          id: Ecto.UUID.dump!(Ecto.UUID.generate()),
          user_id: user_uuid,
          record_id: record_uuid,
          action: action,
          selection_group: Keyword.get(opts, :selection_group, "default"),
          session_id: Keyword.get(opts, :session_id),
          ip_address: ip_address,
          user_agent: Keyword.get(opts, :user_agent),
          metadata: Keyword.get(opts, :metadata, %{}),
          created_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
        
        Repo.insert_all("selection_audit_log", [audit_data])
      rescue
        error ->
          Logger.error("Failed to log audit action: #{inspect(error)}")
      end
    end)
  end
  
  defp audit_bulk_action(user_id, record_ids, action, opts) do
    spawn(fn ->
      try do
        user_uuid = case Ecto.UUID.cast(user_id) do
          {:ok, uuid} -> Ecto.UUID.dump!(uuid)
          :error -> user_id
        end
        
        # Parse IP address if it's a string
        ip_address = case Keyword.get(opts, :ip_address) do
          ip when is_binary(ip) ->
            case :inet.parse_address(String.to_charlist(ip)) do
              {:ok, parsed_ip} -> parsed_ip
              {:error, _} -> nil
            end
          ip -> ip
        end
        
        audit_entries = Enum.map(record_ids, fn record_id ->
          record_uuid = case Ecto.UUID.cast(record_id) do
            {:ok, uuid} -> Ecto.UUID.dump!(uuid)
            :error -> record_id
          end
          
          %{
            id: Ecto.UUID.dump!(Ecto.UUID.generate()),
            user_id: user_uuid,
            record_id: record_uuid,
            action: action,
            selection_group: Keyword.get(opts, :selection_group, "default"),
            session_id: Keyword.get(opts, :session_id),
            ip_address: ip_address,
            user_agent: Keyword.get(opts, :user_agent),
            metadata: Keyword.get(opts, :metadata, %{}),
            created_at: DateTime.utc_now() |> DateTime.truncate(:second)
          }
        end)
        
        Repo.insert_all("selection_audit_log", audit_entries)
      rescue
        error ->
          Logger.error("Failed to log bulk audit action: #{inspect(error)}")
      end
    end)
  end
end