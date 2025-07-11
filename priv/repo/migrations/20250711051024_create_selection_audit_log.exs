defmodule Sertantai.Repo.Migrations.CreateSelectionAuditLog do
  use Ecto.Migration

  def change do
    create table(:selection_audit_log, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :record_id, references(:uk_lrt, on_delete: :delete_all, type: :uuid), null: false
      add :action, :string, null: false
      add :selection_group, :string, default: "default"
      add :session_id, :string
      add :ip_address, :inet
      add :user_agent, :text
      add :metadata, :map, default: %{}
      add :created_at, :naive_datetime, null: false, default: fragment("NOW()")
    end

    # Add check constraint for action values
    create constraint(:selection_audit_log, :valid_action, 
                     check: "action IN ('select', 'deselect', 'bulk_select', 'bulk_deselect', 'clear_all')")
    
    # Security audit indexes
    create index(:selection_audit_log, [:user_id, :created_at])
    create index(:selection_audit_log, [:action, :created_at])
    create index(:selection_audit_log, [:session_id])
    create index(:selection_audit_log, [:created_at])
  end
end
