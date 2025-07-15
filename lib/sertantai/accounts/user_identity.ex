defmodule Sertantai.Accounts.UserIdentity do
  @moduledoc """
  UserIdentity resource for tracking multiple OAuth provider connections per user.
  
  This resource stores OAuth provider-specific information and tokens for each
  authentication method a user has connected to their account.
  """
  
  use Ash.Resource,
    domain: Sertantai.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "user_identities"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id
    
    # Provider information
    attribute :provider, :string do
      allow_nil? false
      public? true
    end
    
    attribute :uid, :string do
      allow_nil? false
      public? true
    end
    
    # OAuth tokens and metadata
    attribute :access_token, :string, sensitive?: true
    attribute :refresh_token, :string, sensitive?: true
    attribute :expires_at, :utc_datetime
    attribute :token_type, :string, default: "Bearer"
    
    # Provider-specific user information
    attribute :provider_data, :map do
      default %{}
      public? true
    end
    
    # Connection status
    attribute :active, :boolean do
      default true
      public? true
    end
    
    attribute :last_sign_in_at, :utc_datetime
    attribute :sign_in_count, :integer, default: 0

    timestamps()
  end

  relationships do
    belongs_to :user, Sertantai.Accounts.User do
      allow_nil? false
    end
  end

  identities do
    identity :unique_user_provider, [:user_id, :provider]
    identity :unique_provider_uid, [:provider, :uid]
  end

  actions do
    defaults [:read]
    
    create :create do
      accept [:provider, :uid, :access_token, :refresh_token, :expires_at, :token_type, :provider_data, :user_id]
      
      validate present([:provider, :uid, :user_id])
      validate one_of(:provider, ["google", "github", "azure", "linkedin", "okta", "airtable"])
      
      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:sign_in_count, 1)
        |> Ash.Changeset.change_attribute(:last_sign_in_at, DateTime.utc_now())
      end
    end
    
    update :update do
      accept [:access_token, :refresh_token, :expires_at, :provider_data, :active]
    end
    
    update :record_sign_in do
      accept []
      require_atomic? false
      
      change fn changeset, _context ->
        current_count = Ash.Changeset.get_attribute(changeset, :sign_in_count) || 0
        
        changeset
        |> Ash.Changeset.change_attribute(:sign_in_count, current_count + 1)
        |> Ash.Changeset.change_attribute(:last_sign_in_at, DateTime.utc_now())
      end
    end
    
    update :refresh_token do
      accept [:access_token, :refresh_token, :expires_at]
      require_atomic? false
      
      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :last_sign_in_at, DateTime.utc_now())
      end
    end
    
    update :deactivate do
      accept []
      require_atomic? false
      
      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :active, false)
      end
    end
  end

  policies do
    # Users can read their own identities
    policy action_type(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :support)
    end
    
    # Users can create identities for themselves
    policy action_type(:create) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :admin)
    end
    
    # Users can update their own identities
    policy action_type(:update) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :admin)
    end
    
    # Only admins can destroy identities
    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end
  end

  # Helper functions for OAuth integration
  def for_user_and_provider(user_id, provider) do
    case Ash.read(__MODULE__, filter: [user_id: user_id, provider: provider, active: true]) do
      {:ok, [identity | _]} -> {:ok, identity}
      {:ok, []} -> {:error, :not_found}
      error -> error
    end
  end

  def active_providers_for_user(user_id) do
    case Ash.read(__MODULE__, filter: [user_id: user_id, active: true], select: [:provider]) do
      {:ok, identities} -> Enum.map(identities, & &1.provider)
      {:error, _} -> []
    end
  end

  def token_valid?(identity) do
    case identity.expires_at do
      nil -> true
      expires_at -> DateTime.compare(DateTime.utc_now(), expires_at) == :lt
    end
  end

  def needs_refresh?(identity) do
    case identity.expires_at do
      nil -> false
      expires_at -> 
        # Check if token expires within the next 5 minutes
        buffer_time = DateTime.add(DateTime.utc_now(), 5 * 60, :second)
        DateTime.compare(buffer_time, expires_at) == :gt
    end
  end
end