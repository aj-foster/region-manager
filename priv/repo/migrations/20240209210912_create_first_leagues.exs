defmodule RM.Repo.Migrations.CreateFirstLeagues do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:first_leagues, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :code, :text, null: false
      add :location, :text
      add :name, :text, null: false
      add :remote, :boolean, null: false

      add :parent_league_id, references(:first_leagues, type: :uuid, on_delete: :delete_all)
      add :region_id, references(:first_regions, type: :uuid, on_delete: :delete_all), null: false

      timestamps type: :utc_datetime_usec
    end

    execute "ALTER TABLE first_leagues ALTER CONSTRAINT first_leagues_parent_league_id_fkey DEFERRABLE INITIALLY DEFERRED",
            "SELECT 1"

    create_if_not_exists unique_index(:first_leagues, [:code])
    create_if_not_exists index(:first_leagues, ["lower(code)"])
    create_if_not_exists index(:first_leagues, [:parent_league_id])
    create_if_not_exists index(:first_leagues, [:region_id])
  end
end
