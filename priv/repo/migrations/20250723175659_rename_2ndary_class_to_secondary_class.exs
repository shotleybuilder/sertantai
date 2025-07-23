defmodule Sertantai.Repo.Migrations.Rename2ndaryClassToSecondaryClass do
  use Ecto.Migration

  def change do
    rename table(:uk_lrt), :"2ndary_class", to: :secondary_class
  end
end
