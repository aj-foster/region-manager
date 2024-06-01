defmodule RM.Repo.Migrations.AddRescindedToRegistrations do
  use Ecto.Migration

  def change do
    alter table(:event_registrations) do
      add :rescinded, :boolean, null: false, default: false

      add :log, :jsonb, null: false, default: fragment("'[]'::jsonb")
      remove :creator_id, references(:users, type: :uuid, on_delete: :nilify_all), null: false
    end
  end
end
