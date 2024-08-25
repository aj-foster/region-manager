defmodule RM.Repo.Migrations.AddContactsToUserTeams do
  use Ecto.Migration

  def change do
    alter table(:user_teams) do
      add :name, :text
      add :email_alt, :citext
      add :phone, :citext
      add :phone_alt, :citext

      modify :email, :citext, null: true, from: {:citext, null: false}
    end

    create_if_not_exists index(:user_teams, [:email])
    create_if_not_exists index(:user_teams, [:email_alt])
  end
end
