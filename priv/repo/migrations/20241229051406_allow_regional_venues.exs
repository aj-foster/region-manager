defmodule RM.Repo.Migrations.AllowRegionalVenues do
  use Ecto.Migration

  def change do
    alter table(:event_venues) do
      modify :league_id, references(:leagues, type: :uuid, on_delete: :delete_all),
        null: true,
        from: {references(:leagues, type: :uuid, on_delete: :delete_all), null: false}

      add :region_id, references(:first_regions, type: :uuid, on_delete: :delete_all)
    end

    execute """
            UPDATE event_venues
            SET region_id = l.region_id
            FROM leagues l
            WHERE l.id = league_id
            """,
            "SELECT 1"
  end
end
