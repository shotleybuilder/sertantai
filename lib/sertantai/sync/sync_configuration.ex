defmodule Sertantai.Sync.SyncConfiguration do
  @moduledoc """
  Sync Configuration resource for managing external no-code database connections.
  Handles encrypted credentials and sync settings for Airtable, Notion, Zapier integrations.
  """
  
  use Ash.Resource,
    domain: Sertantai.Sync,
    extensions: [AshAdmin.Resource],
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "sync_configurations"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :provider, :atom, constraints: [one_of: [:airtable, :notion, :zapier]]
    attribute :is_active, :boolean, default: true

    # Encrypted credentials storage
    attribute :encrypted_credentials, :string, sensitive?: true
    attribute :credentials_iv, :string, sensitive?: true

    # Sync settings
    attribute :sync_frequency, :atom,
      constraints: [one_of: [:manual, :hourly, :daily, :weekly]],
      default: :manual
    attribute :last_synced_at, :utc_datetime
    attribute :sync_status, :atom,
      constraints: [one_of: [:pending, :syncing, :completed, :failed]],
      default: :pending

    timestamps()
  end

  relationships do
    belongs_to :user, Sertantai.Accounts.User, allow_nil?: false
    has_many :selected_records, Sertantai.Sync.SelectedRecord
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:name, :provider, :sync_frequency, :user_id]
      argument :credentials, :map, allow_nil?: false

      change before_action(fn changeset, _context ->
        case changeset.arguments[:credentials] do
          nil -> changeset
          creds -> 
            # Generate a random IV for encryption
            iv = :crypto.strong_rand_bytes(16)
            # Get encryption key from application config
            encryption_key = get_encryption_key()
            # Encrypt the credentials JSON
            credentials_json = Jason.encode!(creds)
            encrypted_data = :crypto.crypto_one_time(:aes_256_cbc, encryption_key, iv, credentials_json, true)
            
            changeset
            |> Ash.Changeset.force_change_attribute(:encrypted_credentials, Base.encode64(encrypted_data))
            |> Ash.Changeset.force_change_attribute(:credentials_iv, Base.encode64(iv))
        end
      end)
    end

    update :update do
      accept [:name, :is_active, :sync_frequency]
      argument :credentials, :map
      require_atomic? false

      change before_action(fn changeset, _context ->
        case changeset.arguments[:credentials] do
          nil -> changeset
          creds -> 
            # Generate a random IV for encryption
            iv = :crypto.strong_rand_bytes(16)
            # Get encryption key from application config
            encryption_key = get_encryption_key()
            # Encrypt the credentials JSON
            credentials_json = Jason.encode!(creds)
            encrypted_data = :crypto.crypto_one_time(:aes_256_cbc, encryption_key, iv, credentials_json, true)
            
            changeset
            |> Ash.Changeset.force_change_attribute(:encrypted_credentials, Base.encode64(encrypted_data))
            |> Ash.Changeset.force_change_attribute(:credentials_iv, Base.encode64(iv))
        end
      end)
    end

    update :update_sync_status do
      accept [:sync_status, :last_synced_at]
    end

    read :for_user do
      description "Get sync configurations for a specific user"
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
    end

    read :active_for_user do
      description "Get active sync configurations for a specific user"
      argument :user_id, :uuid, allow_nil?: false
      filter expr(user_id == ^arg(:user_id) and is_active == true)
    end
  end


  # Helper function to get encryption key
  defp get_encryption_key do
    # Use the token signing secret as base for encryption key
    secret = Application.fetch_env!(:sertantai, :token_signing_secret)
    # Derive a 32-byte key from the secret
    :crypto.hash(:sha256, secret)
  end

  # Role-based authorization policies
  policies do
    # Allow all read actions for authenticated users (simplify like User resource)
    policy action_type(:read) do
      authorize_if always()
    end

    # Specific policies for user-scoped actions
    policy action([:for_user, :active_for_user]) do
      authorize_if always()
    end

    # Create access: Members, professionals, and admins can create
    policy action_type(:create) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :professional)
      authorize_if actor_attribute_equals(:role, :member)
    end

    # Update/Destroy access: Admins can modify all, users can modify their own
    policy action_type([:update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  # Admin configuration
  admin do
    actor? false
  end

  # Public function to decrypt credentials
  def decrypt_credentials(%{encrypted_credentials: nil}), do: {:error, :no_credentials}
  def decrypt_credentials(%{encrypted_credentials: encrypted, credentials_iv: iv}) do
    try do
      encryption_key = get_encryption_key()
      encrypted_data = Base.decode64!(encrypted)
      iv_bytes = Base.decode64!(iv)
      
      decrypted_json = :crypto.crypto_one_time(:aes_256_cbc, encryption_key, iv_bytes, encrypted_data, false)
      credentials = Jason.decode!(decrypted_json)
      
      {:ok, credentials}
    rescue
      _ -> {:error, :decryption_failed}
    end
  end

end