defmodule RM.Repo.Migrations.AddHashedIdToEmailAddress do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto", "SELECT 1"

    execute """
            ALTER TABLE email_addresses
            ADD COLUMN hashed_id citext
            GENERATED ALWAYS AS (
              encode(digest(id::text, 'sha256'), 'hex')
            ) STORED
            """,
            "ALTER TABLE email_addresses DROP COLUMN hashed_id"

    create_if_not_exists index(:email_addresses, [:hashed_id], unique: true)
  end
end
