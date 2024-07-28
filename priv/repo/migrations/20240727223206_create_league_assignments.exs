defmodule RM.Repo.Migrations.CreateLeagueAssignments do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:league_assignments, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :league_id, references(:leagues, type: :uuid, on_delete: :delete_all), null: false
      add :team_id, references(:teams, type: :uuid, on_delete: :delete_all), null: false

      timestamps type: :utc_datetime_usec
    end
  end
end
