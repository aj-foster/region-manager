defmodule RM.Repo.Migrations.CreateLocalLeagues do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:leagues, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :code, :citext, null: false
      add :current_season, :integer, null: false
      add :location, :text, null: false
      add :name, :text, null: false
      add :remote, :boolean, null: false
      add :removed_at, :utc_datetime_usec

      add :parent_league_id, references(:leagues, type: :uuid, on_delete: :nilify_all)
      add :region_id, references(:first_regions, type: :uuid, on_delete: :delete_all)

      add :settings, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :stats, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :log, :jsonb, null: false, default: fragment("'[]'::jsonb")

      timestamps type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:leagues, [:code, :region_id])
    create_if_not_exists index(:leagues, [:parent_league_id])
    create_if_not_exists index(:leagues, [:region_id])

    drop_if_exists unique_index(:first_leagues, [:code, :season])
    create_if_not_exists unique_index(:first_leagues, [:code, :region_id, :season])
  end
end
