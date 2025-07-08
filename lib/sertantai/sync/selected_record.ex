defmodule Sertantai.Sync.SelectedRecord do
  @moduledoc """
  Selected Record resource for tracking which records users have chosen for syncing.
  Links users' selected UK LRT records to their sync configurations.
  """
  
  use Ash.Resource,
    domain: Sertantai.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "selected_records"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :external_record_id, :string, allow_nil?: false
    attribute :record_type, :string, allow_nil?: false
    attribute :sync_status, :atom,
      constraints: [one_of: [:pending, :synced, :failed]],
      default: :pending
    attribute :last_synced_at, :utc_datetime
    attribute :sync_error, :string

    # Store original record data for comparison
    attribute :cached_data, :map

    timestamps()
  end

  relationships do
    belongs_to :user, Sertantai.Accounts.User, allow_nil?: false
    belongs_to :sync_configuration, Sertantai.Sync.SyncConfiguration, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:external_record_id, :record_type, :cached_data, :user_id, :sync_configuration_id]
    end

    update :update_sync_status do
      accept [:sync_status, :last_synced_at, :sync_error]
    end

    read :for_user do
      description "Get selected records for a specific user"
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end

    read :for_sync_config do
      description "Get selected records for a specific sync configuration"
      argument :sync_config_id, :uuid, allow_nil?: false
      filter expr(sync_configuration_id == ^arg(:sync_config_id))
    end

    read :pending_sync do
      description "Get records pending sync for a user"
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and sync_status == :pending)
    end

    read :by_record_type do
      description "Get selected records by type"
      argument :user_id, :uuid, allow_nil?: false
      argument :record_type, :string, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and record_type == ^arg(:record_type))
    end
  end

  identities do
    identity :unique_record_per_config, [:sync_configuration_id, :external_record_id]
  end

  # Helper functions for record management
  def bulk_create_from_uk_lrt_selection(user_id, sync_config_id, selected_record_ids) do
    # Create selected records from UK LRT record IDs
    selected_record_ids
    |> Enum.map(fn record_id ->
      %{
        user_id: user_id,
        sync_configuration_id: sync_config_id,
        external_record_id: record_id,
        record_type: "uk_lrt",
        sync_status: :pending
      }
    end)
    |> Enum.map(fn attrs ->
      Ash.create(__MODULE__, attrs, domain: Sertantai.Sync)
    end)
  end

  def get_sync_summary(user_id) do
    # Get summary of sync status for a user
    case Ash.read(__MODULE__ |> Ash.Query.for_read(:for_user, %{user_id: user_id}), domain: Sertantai.Sync) do
      {:ok, records} ->
        summary = records
        |> Enum.group_by(& &1.sync_status)
        |> Enum.map(fn {status, records} -> {status, length(records)} end)
        |> Enum.into(%{})

        {:ok, %{
          total: length(records),
          pending: Map.get(summary, :pending, 0),
          synced: Map.get(summary, :synced, 0),
          failed: Map.get(summary, :failed, 0)
        }}
      
      {:error, error} ->
        {:error, error}
    end
  end
end