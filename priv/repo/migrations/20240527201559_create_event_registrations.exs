defmodule RM.Repo.Migrations.CreateEventRegistrations do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:event_registrations, primary_key: false) do
      add :id, :uuid, primary_key: false
      add :waitlisted, :boolean, null: false

      add :creator_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :event_id, references(:first_events, type: :uuid, on_delete: :delete_all), null: false
      add :team_id, references(:teams, type: :uuid, on_delete: :delete_all), null: false

      timestamps type: :utc_datetime_usec
    end
  end
end
