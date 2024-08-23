defmodule RM.Repo.Migrations.AddTeamIndexToLeagueAssignments do
  use Ecto.Migration

  def change do
    create_if_not_exists unique_index(:league_assignments, [:team_id])
  end
end
