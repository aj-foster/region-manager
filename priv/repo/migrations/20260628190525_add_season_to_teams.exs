defmodule RM.Repo.Migrations.AddSeasonToTeams do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :season, :integer
    end

    execute "UPDATE teams SET season = 2025", "SELECT 1"

    alter table(:teams) do
      modify :season, :integer, null: false, from: {:integer, null: true}
    end

    drop_if_exists index(:teams, [:team_id], unique: true)
    create_if_not_exists index(:teams, [:team_id, :season], unique: true)

    drop_if_exists index(:teams, [:number], unique: true)
    create_if_not_exists index(:teams, [:number, :season], unique: true)

    alter table(:import_teams) do
      add :season, :integer
    end

    execute "UPDATE import_teams SET season = 2025", "SELECT 1"

    alter table(:import_teams) do
      modify :season, :integer, null: false, from: {:integer, null: true}
    end
  end
end
