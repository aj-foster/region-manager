defmodule RM.Repo.Migrations.CreateImportTeams do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", "SELECT 1"

    create table(:import_teams, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :data_updated_at, :utc_datetime_usec, null: false
      add :imported_at, :utc_datetime_usec, null: false
      add :region, :citext, null: false
      add :team_id, :integer, null: false

      add :data, :jsonb, null: false, default: fragment("'{}'::jsonb")
    end

    create index(:import_teams, [:team_id])
    create index(:import_teams, [:team_id, :imported_at])
  end
end
