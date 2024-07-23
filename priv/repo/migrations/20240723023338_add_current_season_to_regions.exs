defmodule RM.Repo.Migrations.AddCurrentSeasonToRegions do
  use Ecto.Migration

  def change do
    alter table(:first_regions) do
      add :current_season, :integer
    end

    execute "UPDATE first_regions SET current_season = 2023", "SELECT 1"

    alter table(:first_regions) do
      modify :current_season, :integer, null: false, from: {:integer, null: true}
    end
  end
end
