defmodule RM.Repo.Migrations.AddPrimaryKeyToUserTeams do
  use Ecto.Migration

  def change do
    alter table(:user_teams) do
      modify :id, :uuid, primary_key: true
    end
  end
end
