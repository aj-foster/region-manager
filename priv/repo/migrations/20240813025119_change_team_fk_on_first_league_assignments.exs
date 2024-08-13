defmodule RM.Repo.Migrations.ChangeTeamFkOnFirstLeagueAssignments do
  use Ecto.Migration

  def change do
    execute "TRUNCATE first_league_assignments", "TRUNCATE first_league_assignments"

    alter table(:first_league_assignments) do
      modify :team_id, references(:first_teams, type: :uuid, on_delete: :delete_all),
        null: false,
        from: {references(:teams, type: :uuid, on_delete: :delete_all), null: false}
    end
  end
end
