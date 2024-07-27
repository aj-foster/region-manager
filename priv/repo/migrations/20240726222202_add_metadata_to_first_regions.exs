defmodule RM.Repo.Migrations.AddMetadataToFirstRegions do
  use Ecto.Migration

  def change do
    alter table(:first_regions) do
      add :metadata, :jsonb, null: false, default: fragment("'{}'::jsonb")
    end
  end
end
