defmodule RM.Repo.Migrations.CreateFirstLeagueAssignments do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:first_league_assignments, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :league_id, references(:first_leagues, type: :uuid, on_delete: :delete_all), null: false
      add :team_id, references(:teams, type: :uuid, on_delete: :delete_all), null: false

      timestamps type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:first_league_assignments, [:league_id, :team_id])
  end
end
