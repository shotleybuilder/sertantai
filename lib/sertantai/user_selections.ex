defmodule Sertantai.UserSelections do
  @moduledoc """
  Manages user record selections with persistence across sessions.
  Uses ETS for fast access and optional database persistence.
  """
  
  use GenServer
  
  @table_name :user_selections
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :public, :named_table])
    {:ok, %{table: table}}
  end
  
  @doc "Store selected record IDs for a user"
  def store_selections(user_id, selected_ids) when is_list(selected_ids) do
    :ets.insert(@table_name, {user_id, selected_ids, DateTime.utc_now()})
    :ok
  end
  
  @doc "Retrieve selected record IDs for a user"
  def get_selections(user_id) do
    case :ets.lookup(@table_name, user_id) do
      [{^user_id, selected_ids, _timestamp}] -> selected_ids
      [] -> []
    end
  end
  
  @doc "Clear selected record IDs for a user"
  def clear_selections(user_id) do
    :ets.delete(@table_name, user_id)
    :ok
  end
  
  @doc "Add a record ID to user's selections"
  def add_selection(user_id, record_id) do
    current_selections = get_selections(user_id)
    updated_selections = [record_id | current_selections] |> Enum.uniq()
    store_selections(user_id, updated_selections)
  end
  
  @doc "Remove a record ID from user's selections"
  def remove_selection(user_id, record_id) do
    current_selections = get_selections(user_id)
    updated_selections = List.delete(current_selections, record_id)
    store_selections(user_id, updated_selections)
  end
  
  @doc "Get count of selected records for a user"
  def selection_count(user_id) do
    get_selections(user_id) |> length()
  end
end