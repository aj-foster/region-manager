defmodule RM.Repo.Migrations.AddStatsToFirstLeagues do
  use Ecto.Migration

  def change do
    alter table(:first_leagues) do
      add :stats, :jsonb, null: false, default: fragment("'{}'::jsonb")
    end
  end
end
