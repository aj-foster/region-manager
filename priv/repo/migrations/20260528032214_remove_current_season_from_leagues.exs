defmodule RM.Repo.Migrations.RemoveCurrentSeasonFromLeagues do
  use Ecto.Migration

  def change do
    alter table(:leagues) do
      remove :current_season
    end
  end
end
