defmodule Sertantai.SyncConfig do
  @moduledoc """
  Sync configuration management for UK LRT data exports.
  Prepares for future ElectricSQL integration and external service sync.
  """

  use Ash.Resource,
    domain: Sertantai.Domain,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "sync_configs"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "Human-readable name for this sync configuration"
    end

    attribute :target_service, :string do
      allow_nil? false
      description "Target service (baserow, airtable, etc.)"
    end

    attribute :config_data, :map do
      allow_nil? false
      description "Service-specific configuration data"
      default %{}
    end

    attribute :field_mapping, :map do
      allow_nil? false
      description "Mapping of UK LRT fields to target service fields"
      default %{}
    end

    attribute :filters, :map do
      allow_nil? true
      description "Default filters for records to sync"
      default %{}
    end

    attribute :schedule, :string do
      allow_nil? true
      description "Cron-style schedule for automatic sync (future Oban integration)"
    end

    attribute :is_active, :boolean do
      allow_nil? false
      default true
      description "Whether this configuration is active"
    end

    attribute :last_sync_at, :utc_datetime do
      allow_nil? true
      description "Timestamp of last successful sync"
    end

    attribute :sync_count, :integer do
      allow_nil? false
      default 0
      description "Number of successful syncs performed"
    end

    timestamps()
  end

  actions do
    defaults [:read, :update, :destroy]
    
    create :create do
      accept [:name, :target_service, :config_data, :field_mapping, :filters, :schedule, :is_active]
    end

    create :create_baserow_config do
      description "Create a new Baserow sync configuration"
      
      argument :name, :string, allow_nil?: false
      argument :baserow_url, :string, allow_nil?: false
      argument :baserow_token, :string, allow_nil?: false
      argument :table_id, :string, allow_nil?: false
      
      change set_attribute(:target_service, "baserow")
      change fn changeset, _context ->
        name = Ash.Changeset.get_argument(changeset, :name)
        baserow_url = Ash.Changeset.get_argument(changeset, :baserow_url)
        baserow_token = Ash.Changeset.get_argument(changeset, :baserow_token)
        table_id = Ash.Changeset.get_argument(changeset, :table_id)
        
        config_data = %{
          baserow_url: baserow_url,
          baserow_token: baserow_token,
          table_id: table_id
        }
        
        field_mapping = default_baserow_field_mapping()
        
        changeset
        |> Ash.Changeset.change_attribute(:name, name)
        |> Ash.Changeset.change_attribute(:config_data, config_data)
        |> Ash.Changeset.change_attribute(:field_mapping, field_mapping)
      end
    end

    create :create_airtable_config do
      description "Create a new Airtable sync configuration"
      
      argument :name, :string, allow_nil?: false
      argument :base_id, :string, allow_nil?: false
      argument :table_id, :string, allow_nil?: false
      argument :api_key, :string, allow_nil?: false
      
      change set_attribute(:target_service, "airtable")
      change fn changeset, _context ->
        name = Ash.Changeset.get_argument(changeset, :name)
        base_id = Ash.Changeset.get_argument(changeset, :base_id)
        table_id = Ash.Changeset.get_argument(changeset, :table_id)
        api_key = Ash.Changeset.get_argument(changeset, :api_key)
        
        config_data = %{
          base_id: base_id,
          table_id: table_id,
          api_key: api_key
        }
        
        field_mapping = default_airtable_field_mapping()
        
        changeset
        |> Ash.Changeset.change_attribute(:name, name)
        |> Ash.Changeset.change_attribute(:config_data, config_data)
        |> Ash.Changeset.change_attribute(:field_mapping, field_mapping)
      end
    end

    update :mark_synced do
      description "Mark configuration as successfully synced"
      require_atomic? false
      
      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:last_sync_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:sync_count, 
            (Ash.Changeset.get_attribute(changeset, :sync_count) || 0) + 1)
      end
    end

    read :active_configs do
      description "Get all active sync configurations"
      filter expr(is_active == true)
    end

    read :by_service do
      description "Get configurations by target service"
      argument :service, :string, allow_nil?: false
      filter expr(target_service == ^arg(:service) and is_active == true)
    end
  end

  # Default field mappings for different services
  
  defp default_baserow_field_mapping do
    %{
      "id" => "UK LRT ID",
      "name" => "Name", 
      "family" => "Family",
      "family_ii" => "Family II",
      "year" => "Year",
      "number" => "Number",
      "live" => "Status",
      "type_desc" => "Type Description",
      "md_description" => "Description",
      "tags" => "Tags",
      "role" => "Roles",
      "created_at" => "Created At"
    }
  end

  defp default_airtable_field_mapping do
    %{
      "id" => "UK LRT ID",
      "name" => "Name",
      "family" => "Family", 
      "family_ii" => "Family II",
      "year" => "Year",
      "number" => "Number",
      "live" => "Status",
      "type_desc" => "Type Description", 
      "md_description" => "Description",
      "tags" => "Tags",
      "role" => "Roles",
      "created_at" => "Created At"
    }
  end
end