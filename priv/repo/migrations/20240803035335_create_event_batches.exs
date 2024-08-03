defmodule RM.Repo.Migrations.CreateEventBatches do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:event_batches, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :file, :text
      add :generated_at, :utc_datetime_usec, null: false
      add :generated_by, references(:users, type: :uuid)
    end
  end
end
