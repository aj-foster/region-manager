defmodule RM.Repo.Migrations.ChangeUniqueIndexOnUserTeams do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:user_teams, [:email, :team_id])
    drop_if_exists unique_index(:user_teams, [:team_id, :user_id])
    create_if_not_exists unique_index(:user_teams, [:team_id, :relationship])
  end
end
