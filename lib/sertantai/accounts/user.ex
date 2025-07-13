defmodule Sertantai.Accounts.User do
  @moduledoc """
  User resource with authentication capabilities using Ash Authentication.
  """
  
  use Ash.Resource,
    domain: Sertantai.Accounts,
    extensions: [AshAuthentication, AshAdmin.Resource],
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "users"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true

    # Additional user profile fields
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :timezone, :string, default: "UTC"
    
    # Role-based access control
    attribute :role, :atom do
      constraints one_of: [:guest, :member, :professional, :admin, :support]
      default :guest
      allow_nil? false
      public? true
    end

    timestamps()
  end

  authentication do
    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
      end
    end

    tokens do
      enabled? true
      token_resource Sertantai.Accounts.Token
      signing_secret fn _, _ ->
        Application.fetch_env(:sertantai, :token_signing_secret)
      end
    end

    session_identifier :jti
  end

  identities do
    identity :unique_email, [:email]
  end

  actions do
    defaults [:read, :update]

    create :register_with_password do
      accept [:email, :first_name, :last_name, :timezone, :role]
      argument :password, :string, allow_nil?: false, sensitive?: true
      argument :password_confirmation, :string, allow_nil?: false, sensitive?: true

      validate confirm(:password, :password_confirmation)
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      change AshAuthentication.Strategy.Password.HashPasswordChange
      change AshAuthentication.GenerateTokenChange
      change fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :email) do
          nil -> changeset
          email when is_binary(email) -> Ash.Changeset.change_attribute(changeset, :email, String.downcase(email))
          _other -> changeset
        end
      end
    end

    # Role management action - only admins can change roles
    update :update_role do
      accept [:role]
      require_atomic? false
      argument :target_user_id, :uuid, allow_nil?: false
      
      change fn changeset, context ->
        case context.actor do
          %{role: :admin} -> changeset
          _ -> 
            changeset
            |> Ash.Changeset.add_error(:role, "Only administrators can modify user roles")
        end
      end
    end

    # Business logic action for role upgrades (member -> professional via subscription)
    update :upgrade_to_professional do
      accept []
      require_atomic? false
      
      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :role, :professional)
      end
    end

    # Business logic action for role downgrades (professional -> member on subscription end)
    update :downgrade_to_member do
      accept []
      require_atomic? false
      
      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :role, :member)
      end
    end
  end

  # Relationships to sync resources (Phase 2)
  relationships do
    has_many :sync_configurations, Sertantai.Sync.SyncConfiguration
    has_many :selected_records, Sertantai.Sync.SelectedRecord
  end

  # Role-based authorization policies
  policies do
    # Admins can do anything
    policy action_type([:read, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Support can read all users but not modify roles
    policy action_type(:read) do
      authorize_if actor_attribute_equals(:role, :support)
    end

    # Users can read and update their own records (but not role)
    policy action_type([:read, :update]) do
      authorize_if expr(id == ^actor(:id))
    end

    # Only admins can update roles
    policy action(:update_role) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Business logic actions for subscription management
    policy action([:upgrade_to_professional, :downgrade_to_member]) do
      authorize_if always()  # These will be called by system processes
    end

    # Registration is open to all
    policy action(:register_with_password) do
      authorize_if always()
    end
  end

  # Role hierarchy helper functions
  def role_hierarchy do
    %{
      admin: 5,
      support: 4, 
      professional: 3,
      member: 2,
      guest: 1
    }
  end

  def role_level(role) do
    Map.get(role_hierarchy(), role, 0)
  end

  def can_access_role?(actor_role, required_role) do
    role_level(actor_role) >= role_level(required_role)
  end

  # Admin configuration
  admin do
    actor? true
  end
end
