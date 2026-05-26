defmodule RM.Repo.Migrations.AddMetadataToLeagues do
  use Ecto.Migration

  def change do
    alter table(:leagues) do
      add :metadata, :jsonb, null: false, default: fragment("'{}'::jsonb")
    end
  end
end
