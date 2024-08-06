defmodule RM.Repo.Migrations.AddRegionIdToEventBatches do
  use Ecto.Migration

  def change do
    alter table(:event_batches) do
      add :region_id, references(:first_regions, type: :uuid, on_delete: :delete_all), null: false
      add :event_count, :integer, null: false
    end
  end
end
