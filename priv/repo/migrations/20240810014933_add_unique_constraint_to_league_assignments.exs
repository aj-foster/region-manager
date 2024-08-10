defmodule RM.Repo.Migrations.AddUniqueConstraintToLeagueAssignments do
  use Ecto.Migration

  def change do
    create_if_not_exists unique_index(:league_assignments, [:league_id, :team_id])
  end
end
