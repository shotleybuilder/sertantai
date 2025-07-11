defmodule Sertantai.Repo.Migrations.CreateUserSelectionGroups do
  use Ecto.Migration

  def change do
    create table(:user_selection_groups, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, on_delete: :delete_all, type: :uuid), null: false
      add :name, :string, null: false
      add :description, :text
      add :is_default, :boolean, default: false
      add :metadata, :map, default: %{}
      
      timestamps()
    end

    # Ensure unique group names per user
    create unique_index(:user_selection_groups, [:user_id, :name], 
                       name: :unique_user_group_name)
    
    # Ensure only one default group per user
    create unique_index(:user_selection_groups, [:user_id], 
                       where: "is_default = true",
                       name: :unique_default_group_per_user)
    
    # Performance indexes
    create index(:user_selection_groups, [:user_id])
  end
end
