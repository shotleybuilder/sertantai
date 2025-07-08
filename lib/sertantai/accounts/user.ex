defmodule Sertantai.Accounts.User do
  @moduledoc """
  User resource with authentication capabilities using Ash Authentication.
  """
  
  use Ash.Resource,
    domain: Sertantai.Accounts,
    extensions: [AshAuthentication],
    data_layer: AshPostgres.DataLayer

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
    defaults [:read]

    create :register_with_password do
      accept [:email, :first_name, :last_name, :timezone]
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
  end

  # Note: Relationships to sync resources will be added in Phase 2
  # relationships do
  #   has_many :sync_configurations, Sertantai.Sync.SyncConfiguration
  #   has_many :selected_records, Sertantai.Sync.SelectedRecord
  # end
end
