defmodule RM.Repo.Migrations.CreateEventAttachments do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:event_attachments, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :file, :text, null: false
      add :name, :text, null: false

      add :proposal_id, references(:event_proposals, type: :uuid, on_delete: :nilify_all),
        null: false

      add :season, :integer, null: false
      add :type, :text, null: false
      add :uploaded_at, :utc_datetime_usec, null: false
      add :uploaded_by, :uuid, null: false
    end

    create_if_not_exists unique_index(:event_attachments, [:proposal_id, :name])
  end
end
