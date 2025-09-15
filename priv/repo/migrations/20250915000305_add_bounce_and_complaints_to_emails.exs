defmodule RM.Repo.Migrations.AddBounceAndComplaintsToEmails do
  use Ecto.Migration

  def change do
    alter table(:rm_emails) do
      add :complained_at, :utc_datetime_usec
      add :permanently_bounced_at, :utc_datetime_usec
      add :unsubscribed_at, :utc_datetime_usec
    end

    execute """
            ALTER TABLE rm_emails
            ADD COLUMN sendable BOOLEAN GENERATED ALWAYS AS (
              (
                bounce_count < 2
                AND complained_at IS NULL
                AND permanently_bounced_at IS NULL
                AND unsubscribed_at IS NULL
              )
            ) STORED;
            """,
            """
            ALTER TABLE rm_emails
            DROP COLUMN sendable
            """
  end
end
