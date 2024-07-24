defmodule RM.Repo.Migrations.ReorderEventsIndex do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:first_events, [:season, :code])
    create_if_not_exists unique_index(:first_events, [:code, :season])
  end
end
