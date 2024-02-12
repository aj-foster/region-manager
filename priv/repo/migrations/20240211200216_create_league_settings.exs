defmodule RM.Repo.Migrations.CreateLeagueSettings do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:league_settings, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :league_id, references(:first_leagues, type: :uuid, on_delete: :delete_all), null: false
      add :registration, :jsonb, null: false, default: fragment("'{}'::jsonb")
    end

    create_if_not_exists unique_index(:league_settings, [:league_id])
  end
end
