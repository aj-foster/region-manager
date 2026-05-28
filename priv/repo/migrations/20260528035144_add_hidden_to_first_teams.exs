defmodule RM.Repo.Migrations.AddHiddenToFirstTeams do
  use Ecto.Migration

  def change do
    alter table(:first_teams) do
      add :_hidden, :boolean, default: false, null: false
    end

    create_if_not_exists index(:first_teams, [:_hidden])
  end
end
