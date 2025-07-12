defmodule Sertantai.Repo.Migrations.CreateOrganizations do
  @moduledoc """
  Creates organizations and organization_users tables for Phase 1 implementation.
  """
  
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email_domain, :string, null: false
      add :organization_name, :string, null: false
      add :verified, :boolean, default: false, null: false
      add :core_profile, :map, null: false, default: %{}
      add :created_by_user_id, references(:users, type: :binary_id), null: false
      add :profile_completeness_score, :decimal, default: 0.0, null: false
      
      timestamps()
    end

    create table(:organization_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "member"
      add :joined_at, :utc_datetime, null: false
      add :permissions, :map, null: false, default: %{}
      
      timestamps()
    end

    # Indexes for organizations
    create index(:organizations, [:email_domain])
    create index(:organizations, [:organization_name])
    create index(:organizations, [:created_by_user_id])
    create index(:organizations, [:core_profile], using: :gin)

    # Indexes for organization_users  
    create index(:organization_users, [:organization_id])
    create index(:organization_users, [:user_id])
    create index(:organization_users, [:role])
    
    # Unique constraint for user-organization pairs
    create unique_index(:organization_users, [:organization_id, :user_id], 
           name: :unique_user_organization)
           
    # Check constraint for valid roles
    create constraint(:organization_users, :valid_role, 
           check: "role IN ('owner', 'admin', 'member', 'viewer')")
  end
end
