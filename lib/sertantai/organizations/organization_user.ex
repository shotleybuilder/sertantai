defmodule Sertantai.Organizations.OrganizationUser do
  @moduledoc """
  Join table for Organization and User relationships.
  Manages user roles and permissions within organizations.
  """

  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: Sertantai.Organizations

  postgres do
    table "organization_users"
    repo Sertantai.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :role, :atom do
      constraints one_of: [:owner, :admin, :member, :viewer]
      default :member
      allow_nil? false
    end
    
    attribute :joined_at, :utc_datetime do
      default &DateTime.utc_now/0
      allow_nil? false
    end
    
    attribute :permissions, :map do
      default %{}
      allow_nil? false
    end
    
    timestamps()
  end

  relationships do
    belongs_to :organization, Sertantai.Organizations.Organization do
      allow_nil? false
    end
    
    belongs_to :user, Sertantai.Accounts.User do
      allow_nil? false
    end
  end

  actions do
    defaults [:read]
    
    create :create do
      accept [:organization_id, :user_id, :role, :permissions]
    end
    
    update :update do
      accept [:role, :permissions]
    end
    
    destroy :destroy
  end

  validations do
    validate present(:organization_id), message: "Organization is required"
    validate present(:user_id), message: "User is required"
    validate present(:role), message: "Role is required"
  end

  identities do
    identity :unique_user_organization, [:organization_id, :user_id] do
      message "User is already associated with this organization"
    end
  end

  code_interface do
    domain Sertantai.Organizations
    define :create, args: [:organization_id, :user_id]
    define :read
    define :update
    define :destroy
  end
end