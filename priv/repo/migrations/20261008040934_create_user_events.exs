defmodule RM.Repo.Migrations.CreateUserEvents do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_events, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :email, :citext, null: false
      add :permissions, :jsonb, null: false, default: fragment("'{}'::jsonb")

      add :proposal_id, references(:event_proposals, type: :uuid, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps type: :utc_datetime_usec
    end
  end
end
