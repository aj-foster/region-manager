defmodule RM.Repo.Migrations.CreateRmEmails do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", "SELECT 1"

    create_if_not_exists table(:rm_emails, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :email, :citext, null: false

      add :bounce_count, :integer, null: false, default: 0
      add :first_bounced_at, :utc_datetime_usec
      add :last_bounced_at, :utc_datetime_usec

      timestamps type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:rm_emails, [:email])
    create_if_not_exists index(:rm_emails, [:bounce_count])

    execute """
            INSERT INTO rm_emails (id, email, inserted_at, updated_at)
            SELECT uuid_generate_v4(), email, NOW(), NOW()
            FROM user_teams
            WHERE email IS NOT NULL
            ON CONFLICT DO NOTHING
            """,
            "SELECT 1"

    execute """
            INSERT INTO rm_emails (id, email, inserted_at, updated_at)
            SELECT uuid_generate_v4(), email, NOW(), NOW()
            FROM user_leagues
            WHERE email IS NOT NULL
            ON CONFLICT DO NOTHING
            """,
            "SELECT 1"
  end
end
