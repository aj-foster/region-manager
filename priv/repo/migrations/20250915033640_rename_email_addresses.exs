defmodule RM.Repo.Migrations.RenameEmailAddresses do
  use Ecto.Migration

  def change do
    rename table(:rm_emails), to: table(:email_addresses)
  end
end
