defmodule RM.Repo.Migrations.AddIndicesToEventRegistrations do
  use Ecto.Migration

  def change do
    create_if_not_exists index(:event_registrations, [:event_id])
    create_if_not_exists index(:event_registrations, [:rescinded])
    create_if_not_exists index(:event_registrations, [:team_id])
    create_if_not_exists index(:event_registrations, [:waitlisted])
  end
end
