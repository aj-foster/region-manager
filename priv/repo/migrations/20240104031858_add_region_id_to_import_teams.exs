defmodule RM.Repo.Migrations.AddRegionIdToImportTeams do
  use Ecto.Migration

  def change do
    alter table(:import_teams) do
      add :region_id, :uuid
    end

    execute "ALTER TABLE import_teams DROP CONSTRAINT import_teams_upload_id_fkey",
            "ALTER TABLE import_teams ADD CONSTRAINT import_teams_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES import_uploads(id)"

    create_if_not_exists index(:import_teams, [:upload_id])
  end
end
