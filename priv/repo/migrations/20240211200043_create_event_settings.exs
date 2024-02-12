defmodule RM.Repo.Migrations.CreateEventSettings do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:event_settings, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :event_id, references(:first_events, type: :uuid, on_delete: :delete_all), null: false
      add :registration, :jsonb, null: false, default: fragment("'{}'::jsonb")
    end

    create_if_not_exists unique_index(:event_settings, [:event_id])
  end
end
