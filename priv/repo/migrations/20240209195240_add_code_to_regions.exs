defmodule RM.Repo.Migrations.AddCodeToRegions do
  use Ecto.Migration

  def change do
    alter table(:first_regions) do
      add :code, :text
    end

    # Assumes no regions have been created with duplicate abbreviations
    execute "UPDATE first_regions SET code = abbreviation", "SELECT 1"
    create_if_not_exists unique_index(:first_regions, [:code])

    alter table(:first_regions) do
      modify :code, :text, null: false, from: {:text, null: true}
    end
  end
end
