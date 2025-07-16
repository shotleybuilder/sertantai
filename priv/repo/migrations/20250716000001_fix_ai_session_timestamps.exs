defmodule Sertantai.Repo.Migrations.FixAiSessionTimestamps do
  use Ecto.Migration

  def up do
    alter table(:ai_conversation_sessions) do
      modify :inserted_at, :utc_datetime_usec, null: false
      modify :updated_at, :utc_datetime_usec, null: false
      modify :last_activity_at, :utc_datetime_usec
    end
  end

  def down do
    alter table(:ai_conversation_sessions) do
      modify :inserted_at, :naive_datetime, null: false
      modify :updated_at, :naive_datetime, null: false
      modify :last_activity_at, :naive_datetime
    end
  end
end