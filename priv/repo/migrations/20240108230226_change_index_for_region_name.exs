defmodule RM.Repo.Migrations.ChangeIndexForRegionName do
  use Ecto.Migration

  def change do
    drop_if_exists index(:first_regions, [:name])
    create_if_not_exists unique_index(:first_regions, ["lower(name)"])
  end
end
