defmodule RM.Repo.Migrations.CreateRmSettings do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:rm_settings, primary_key: false) do
      add :key, :citext, primary_key: true
      add :value, :binary, null: false
      add :description, :text
      timestamps type: :utc_datetime_usec
    end
  end
end
