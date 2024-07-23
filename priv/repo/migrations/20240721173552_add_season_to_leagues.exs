defmodule RM.Repo.Migrations.AddSeasonToLeagues do
  use Ecto.Migration

  def change do
    alter table(:first_leagues) do
      add :season, :integer, null: false, default: 2023
    end

    drop_if_exists unique_index(:first_leagues, [:code])
    drop_if_exists index(:first_leagues, ["lower(code)"])

    create_if_not_exists index(:first_leagues, [:season])
    create_if_not_exists unique_index(:first_leagues, [:code, :season])
  end
end
