defmodule RM.Repo.Migrations.CreateImportUploads do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:import_uploads, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :file, :text
      add :imported_at, :utc_datetime_usec, null: false
      add :imported_by, references(:users, type: :uuid)
    end

    alter table(:import_teams) do
      add :upload_id, references(:import_uploads, type: :uuid)
    end
  end
end
