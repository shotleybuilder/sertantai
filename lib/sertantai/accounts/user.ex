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
    attribute :hashed_password, :string, allow_nil?: true, sensitive?: true

    # Enhanced user profile fields for OAuth integration
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :timezone, :string, default: "UTC"
    
    # OAuth provider tracking
    attribute :primary_provider, :string do
      default "password"
      public? true
    end
    
    attribute :connected_providers, {:array, :string} do
      default []
      public? true
    end
    
    # Enhanced profile data from OAuth providers
    attribute :profile_image_url, :string
    attribute :company, :string
    attribute :job_title, :string
    attribute :github_username, :string
    attribute :linkedin_url, :string
    attribute :verified_email, :boolean, default: false
    
    # Enterprise context from OAuth providers
    attribute :enterprise_domain, :string
    attribute :okta_groups, {:array, :string}, default: []
    attribute :azure_tenant_id, :string
    
    # Data platform connections
    attribute :airtable_connected, :boolean, default: false
    attribute :airtable_workspace_id, :string
    
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
      # Existing password authentication (now optional for OAuth users)
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
        confirmation_required? false
      end
      
      # Core OAuth strategies for general users
      oauth2 :google do
        client_id fn _, _ -> {:ok, System.get_env("GOOGLE_CLIENT_ID", "")} end
        client_secret fn _, _ -> {:ok, System.get_env("GOOGLE_CLIENT_SECRET", "")} end
        redirect_uri fn _, _ -> {:ok, System.get_env("GOOGLE_REDIRECT_URI", "http://localhost:4001/auth/google/callback")} end
        base_url "https://accounts.google.com"
        authorize_url "/o/oauth2/auth"
        token_url "https://oauth2.googleapis.com/token"
        user_url "https://www.googleapis.com/oauth2/v1/userinfo"
        authorization_params [scope: "openid email profile"]
        identity_resource Sertantai.Accounts.UserIdentity
        # TODO: SECURITY - Implement email confirmation to prevent account hijacking
        # For production, add AshAuthentication.AddOn.Confirmation and remove prevent_hijacking? false
        # See: https://hexdocs.pm/ash_authentication/confirmation.html
        prevent_hijacking? false
      end
      
      oauth2 :github do
        client_id fn _, _ -> {:ok, System.get_env("GITHUB_CLIENT_ID", "")} end
        client_secret fn _, _ -> {:ok, System.get_env("GITHUB_CLIENT_SECRET", "")} end
        redirect_uri fn _, _ -> {:ok, System.get_env("GITHUB_REDIRECT_URI", "http://localhost:4001/auth/github/callback")} end
        base_url "https://github.com"
        authorize_url "/login/oauth/authorize"
        token_url "/login/oauth/access_token"
        user_url "https://api.github.com/user"
        authorization_params [scope: "user:email"]
        identity_resource Sertantai.Accounts.UserIdentity
        # TODO: SECURITY - Implement email confirmation to prevent account hijacking
        # For production, add AshAuthentication.AddOn.Confirmation and remove prevent_hijacking? false
        # See: https://hexdocs.pm/ash_authentication/confirmation.html
        prevent_hijacking? false
      end
      
      # Enterprise OAuth strategies
      oauth2 :azure do
        client_id fn _, _ -> {:ok, System.get_env("AZURE_CLIENT_ID", "")} end
        client_secret fn _, _ -> {:ok, System.get_env("AZURE_CLIENT_SECRET", "")} end
        redirect_uri fn _, _ -> {:ok, System.get_env("AZURE_REDIRECT_URI", "http://localhost:4001/auth/azure/callback")} end
        base_url "https://login.microsoftonline.com"
        authorize_url "/common/oauth2/v2.0/authorize"
        token_url "/common/oauth2/v2.0/token"
        user_url "https://graph.microsoft.com/v1.0/me"
        authorization_params [scope: "openid profile email"]
        identity_resource Sertantai.Accounts.UserIdentity
        prevent_hijacking? false
      end
      
      oauth2 :linkedin do
        client_id fn _, _ -> {:ok, System.get_env("LINKEDIN_CLIENT_ID", "")} end
        client_secret fn _, _ -> {:ok, System.get_env("LINKEDIN_CLIENT_SECRET", "")} end
        redirect_uri fn _, _ -> {:ok, System.get_env("LINKEDIN_REDIRECT_URI", "http://localhost:4001/auth/linkedin/callback")} end
        base_url "https://www.linkedin.com"
        authorize_url "/oauth/v2/authorization"
        token_url "/oauth/v2/accessToken"
        user_url "https://api.linkedin.com/v2/me"
        authorization_params [scope: "r_liteprofile r_emailaddress"]
        identity_resource Sertantai.Accounts.UserIdentity
        prevent_hijacking? false
      end
      
      # Data platform OAuth (dual purpose: auth + sync permissions)
      oauth2 :airtable do
        client_id fn _, _ -> {:ok, System.get_env("AIRTABLE_CLIENT_ID", "")} end
        client_secret fn _, _ -> {:ok, System.get_env("AIRTABLE_CLIENT_SECRET", "")} end
        redirect_uri fn _, _ -> {:ok, System.get_env("AIRTABLE_REDIRECT_URI", "http://localhost:4001/auth/airtable/callback")} end
        base_url "https://airtable.com"
        authorize_url "/oauth2/v1/authorize"
        token_url "/oauth2/v1/token"
        user_url "https://api.airtable.com/v0/meta/whoami"
        authorization_params [scope: "data.records:read data.records:write schema.bases:read"]
        identity_resource Sertantai.Accounts.UserIdentity
        prevent_hijacking? false
      end
      
      # Enterprise SSO via OKTA OIDC
      # Note: OKTA uses OIDC (OpenID Connect) protocol, not OAuth2
      # TODO: Implement OKTA OIDC strategy when AshAuthentication supports it
      # For now, we can use generic OAuth2 with OKTA's OAuth2 endpoints
      oauth2 :okta do
        client_id fn _, _ -> {:ok, System.get_env("OKTA_CLIENT_ID", "")} end
        client_secret fn _, _ -> {:ok, System.get_env("OKTA_CLIENT_SECRET", "")} end
        redirect_uri fn _, _ -> {:ok, System.get_env("OKTA_REDIRECT_URI", "http://localhost:4001/auth/okta/callback")} end
        base_url fn _, _ -> {:ok, System.get_env("OKTA_BASE_URL", "https://dev-example.okta.com")} end
        authorize_url "/oauth2/v1/authorize"
        token_url "/oauth2/v1/token"
        user_url "/oauth2/v1/userinfo"
        authorization_params [scope: "openid profile email groups"]
        identity_resource Sertantai.Accounts.UserIdentity
        prevent_hijacking? false
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
    defaults [:read]
    
    update :update do
      accept [:email, :first_name, :last_name, :timezone]
    end

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
    
    # OAuth registration action for new users
    create :register_with_oauth do
      accept [:email, :first_name, :last_name, :profile_image_url, :company, :job_title, 
              :github_username, :linkedin_url, :enterprise_domain, :okta_groups, 
              :azure_tenant_id, :airtable_connected, :airtable_workspace_id, :primary_provider]
      
      change fn changeset, context ->
        provider = Ash.Changeset.get_attribute(changeset, :primary_provider) || "unknown"
        
        changeset
        |> Ash.Changeset.change_attribute(:role, :member)  # OAuth users start as members
        |> Ash.Changeset.change_attribute(:verified_email, true)  # OAuth providers verify emails
        |> Ash.Changeset.change_attribute(:connected_providers, [provider])
        |> Ash.Changeset.change_attribute(:email, 
             case Ash.Changeset.get_attribute(changeset, :email) do
               nil -> nil
               email when is_binary(email) -> String.downcase(email)
               _other -> nil
             end)
      end
      
      change AshAuthentication.GenerateTokenChange
    end
    
    # Update user profile with OAuth data
    update :update_oauth_profile do
      accept [:first_name, :last_name, :profile_image_url, :company, :job_title, 
              :github_username, :linkedin_url, :enterprise_domain, :okta_groups, 
              :azure_tenant_id, :airtable_connected, :airtable_workspace_id, :connected_providers]
      require_atomic? false
      
      change fn changeset, _context ->
        # Update last updated timestamp
        changeset
      end
    end
    
    # Connect additional OAuth provider to existing user
    update :connect_oauth_provider do
      accept [:connected_providers]
      argument :provider_name, :string, allow_nil?: false
      require_atomic? false
      
      change fn changeset, _context ->
        provider = Ash.Changeset.get_argument(changeset, :provider_name)
        current_providers = Ash.Changeset.get_attribute(changeset, :connected_providers) || []
        
        updated_providers = 
          if provider in current_providers do
            current_providers
          else
            [provider | current_providers]
          end
        
        Ash.Changeset.change_attribute(changeset, :connected_providers, updated_providers)
      end
    end
    
    # OAuth provider-specific registration actions
    create :register_with_google do
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false
      
      upsert? true
      upsert_identity :unique_email
      upsert_fields [:first_name, :last_name, :profile_image_url, :verified_email, :primary_provider, :connected_providers]
      
      change AshAuthentication.Strategy.OAuth2.IdentityChange
      change AshAuthentication.GenerateTokenChange
      
      change fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        
        changeset
        |> Ash.Changeset.change_attribute(:email, String.downcase(user_info["email"] || ""))
        |> Ash.Changeset.change_attribute(:first_name, user_info["given_name"])
        |> Ash.Changeset.change_attribute(:last_name, user_info["family_name"])
        |> Ash.Changeset.change_attribute(:profile_image_url, user_info["picture"])
        |> Ash.Changeset.change_attribute(:role, :member)
        |> Ash.Changeset.change_attribute(:verified_email, true)
        |> Ash.Changeset.change_attribute(:primary_provider, "google")
        |> Ash.Changeset.change_attribute(:connected_providers, ["google"])
      end
    end
    
    create :register_with_github do
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false
      
      upsert? true
      upsert_identity :unique_email
      upsert_fields [:first_name, :last_name, :profile_image_url, :github_username, :verified_email, :primary_provider, :connected_providers]
      
      change AshAuthentication.Strategy.OAuth2.IdentityChange
      change AshAuthentication.GenerateTokenChange
      
      change fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        
        changeset
        |> Ash.Changeset.change_attribute(:email, String.downcase(user_info["email"] || ""))
        |> Ash.Changeset.change_attribute(:first_name, user_info["name"] |> extract_first_name())
        |> Ash.Changeset.change_attribute(:last_name, user_info["name"] |> extract_last_name())
        |> Ash.Changeset.change_attribute(:profile_image_url, user_info["avatar_url"])
        |> Ash.Changeset.change_attribute(:github_username, user_info["login"])
        |> Ash.Changeset.change_attribute(:role, :member)
        |> Ash.Changeset.change_attribute(:verified_email, true)
        |> Ash.Changeset.change_attribute(:primary_provider, "github")
        |> Ash.Changeset.change_attribute(:connected_providers, ["github"])
      end
    end
    
    create :register_with_azure do
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false
      
      upsert? true
      upsert_identity :unique_email
      upsert_fields [:first_name, :last_name, :profile_image_url, :company, :job_title, :verified_email, :primary_provider, :connected_providers, :enterprise_domain, :azure_tenant_id]
      
      change AshAuthentication.Strategy.OAuth2.IdentityChange
      change AshAuthentication.GenerateTokenChange
      
      change fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        
        changeset
        |> Ash.Changeset.change_attribute(:email, String.downcase(user_info["mail"] || user_info["userPrincipalName"] || ""))
        |> Ash.Changeset.change_attribute(:first_name, user_info["givenName"])
        |> Ash.Changeset.change_attribute(:last_name, user_info["surname"])
        |> Ash.Changeset.change_attribute(:company, user_info["companyName"])
        |> Ash.Changeset.change_attribute(:job_title, user_info["jobTitle"])
        |> Ash.Changeset.change_attribute(:enterprise_domain, extract_domain_from_email(user_info["mail"] || user_info["userPrincipalName"]))
        |> Ash.Changeset.change_attribute(:azure_tenant_id, user_info["@odata.context"])
        |> Ash.Changeset.change_attribute(:role, :member)
        |> Ash.Changeset.change_attribute(:verified_email, true)
        |> Ash.Changeset.change_attribute(:primary_provider, "azure")
        |> Ash.Changeset.change_attribute(:connected_providers, ["azure"])
      end
    end
    
    create :register_with_linkedin do
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false
      
      upsert? true
      upsert_identity :unique_email
      upsert_fields [:first_name, :last_name, :profile_image_url, :linkedin_url, :verified_email, :primary_provider, :connected_providers]
      
      change AshAuthentication.Strategy.OAuth2.IdentityChange
      change AshAuthentication.GenerateTokenChange
      
      change fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        
        changeset
        |> Ash.Changeset.change_attribute(:email, String.downcase(user_info["emailAddress"] || ""))
        |> Ash.Changeset.change_attribute(:first_name, get_in(user_info, ["localizedFirstName"]))
        |> Ash.Changeset.change_attribute(:last_name, get_in(user_info, ["localizedLastName"]))
        |> Ash.Changeset.change_attribute(:profile_image_url, get_in(user_info, ["profilePicture", "displayImage"]))
        |> Ash.Changeset.change_attribute(:linkedin_url, "https://linkedin.com/in/#{user_info["id"]}")
        |> Ash.Changeset.change_attribute(:role, :member)
        |> Ash.Changeset.change_attribute(:verified_email, true)
        |> Ash.Changeset.change_attribute(:primary_provider, "linkedin")
        |> Ash.Changeset.change_attribute(:connected_providers, ["linkedin"])
      end
    end
    
    create :register_with_airtable do
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false
      
      upsert? true
      upsert_identity :unique_email
      upsert_fields [:first_name, :last_name, :verified_email, :primary_provider, :connected_providers, :airtable_connected, :airtable_workspace_id]
      
      change AshAuthentication.Strategy.OAuth2.IdentityChange
      change AshAuthentication.GenerateTokenChange
      
      change fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        
        changeset
        |> Ash.Changeset.change_attribute(:email, String.downcase(user_info["email"] || ""))
        |> Ash.Changeset.change_attribute(:first_name, user_info["name"] |> extract_first_name())
        |> Ash.Changeset.change_attribute(:last_name, user_info["name"] |> extract_last_name())
        |> Ash.Changeset.change_attribute(:airtable_connected, true)
        |> Ash.Changeset.change_attribute(:airtable_workspace_id, user_info["id"])
        |> Ash.Changeset.change_attribute(:role, :member)
        |> Ash.Changeset.change_attribute(:verified_email, true)
        |> Ash.Changeset.change_attribute(:primary_provider, "airtable")
        |> Ash.Changeset.change_attribute(:connected_providers, ["airtable"])
      end
    end
    
    create :register_with_okta do
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false
      
      upsert? true
      upsert_identity :unique_email
      upsert_fields [:first_name, :last_name, :verified_email, :primary_provider, :connected_providers, :enterprise_domain, :okta_groups]
      
      change AshAuthentication.Strategy.OAuth2.IdentityChange
      change AshAuthentication.GenerateTokenChange
      
      change fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        
        changeset
        |> Ash.Changeset.change_attribute(:email, String.downcase(user_info["email"] || ""))
        |> Ash.Changeset.change_attribute(:first_name, user_info["given_name"])
        |> Ash.Changeset.change_attribute(:last_name, user_info["family_name"])
        |> Ash.Changeset.change_attribute(:enterprise_domain, extract_domain_from_email(user_info["email"]))
        |> Ash.Changeset.change_attribute(:okta_groups, user_info["groups"] || [])
        |> Ash.Changeset.change_attribute(:role, :member)
        |> Ash.Changeset.change_attribute(:verified_email, true)
        |> Ash.Changeset.change_attribute(:primary_provider, "okta")
        |> Ash.Changeset.change_attribute(:connected_providers, ["okta"])
      end
    end
  end

  # Relationships to sync resources and OAuth identities
  relationships do
    has_many :sync_configurations, Sertantai.Sync.SyncConfiguration
    has_many :selected_records, Sertantai.Sync.SelectedRecord
    has_many :user_identities, Sertantai.Accounts.UserIdentity
    has_one :customer, Sertantai.Billing.Customer
  end

  # Role-based authorization policies - FINAL WORKING CONFIGURATION
  policies do
    # Allow all read actions (including authentication reads) - KEEP SIMPLE
    policy action_type(:read) do
      authorize_if always()
    end
    
    # Allow registration for anyone (public user creation)
    policy action(:register_with_password) do
      authorize_if always()
    end
    
    # Allow OAuth registration for anyone (public user creation)
    policy action(:register_with_oauth) do
      authorize_if always()
    end
    
    # Allow OAuth provider registration for anyone (public user creation)
    policy action([:register_with_google, :register_with_github, :register_with_azure, :register_with_linkedin, :register_with_airtable, :register_with_okta]) do
      authorize_if always()
    end
    
    # Update policy: Either admin or user updating themselves
    policy action_type(:update) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if expr(id == ^actor(:id))
    end
    
    # Destroy policy: Only admins
    policy action_type(:destroy) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Only admins can update roles
    policy action(:update_role) do
      authorize_if actor_attribute_equals(:role, :admin)
    end

    # Business logic actions for subscription management
    policy action([:upgrade_to_professional, :downgrade_to_member]) do
      authorize_if always()  # These will be called by system processes
    end
    
    # OAuth profile update actions
    policy action([:update_oauth_profile, :connect_oauth_provider]) do
      authorize_if expr(id == ^actor(:id))
      authorize_if actor_attribute_equals(:role, :admin)
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
  
  # Helper functions for OAuth name extraction
  defp extract_first_name(nil), do: nil
  defp extract_first_name(full_name) when is_binary(full_name) do
    full_name
    |> String.split(" ", parts: 2)
    |> List.first()
  end
  
  defp extract_last_name(nil), do: nil
  defp extract_last_name(full_name) when is_binary(full_name) do
    case String.split(full_name, " ", parts: 2) do
      [_first] -> nil
      [_first, last] -> last
    end
  end
  
  defp extract_domain_from_email(nil), do: nil
  defp extract_domain_from_email(email) when is_binary(email) do
    case String.split(email, "@") do
      [_user, domain] -> domain
      _ -> nil
    end
  end
end
