defmodule Sertantai.Repo.Migrations.CreateUserRecordSelections do
  use Ecto.Migration

  def change do
    create table(:user_record_selections, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :record_id, references(:uk_lrt, on_delete: :delete_all, type: :uuid), null: false
      add :selection_group, :string, default: "default"
      add :metadata, :map, default: %{}
      
      timestamps()
    end

    # Ensure one selection per user per record per group
    create unique_index(:user_record_selections, [:user_id, :record_id, :selection_group], 
                       name: :unique_user_record_group)
    
    # Performance indexes
    create index(:user_record_selections, [:user_id])
    create index(:user_record_selections, [:record_id])
    create index(:user_record_selections, [:user_id, :selection_group])
    create index(:user_record_selections, [:inserted_at])
  end
end
