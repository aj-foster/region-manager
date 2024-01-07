defmodule RM.Repo.Migrations.AddStatsToRegions do
  use Ecto.Migration

  def change do
    alter table(:first_regions) do
      add :stats, :jsonb, null: false, default: fragment("'{}'::jsonb")
    end
  end
end
