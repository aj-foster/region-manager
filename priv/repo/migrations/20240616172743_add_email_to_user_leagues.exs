defmodule RM.Repo.Migrations.AddEmailToUserLeagues do
  use Ecto.Migration

  def change do
    alter table(:user_leagues) do
      add :email, :citext, null: false
    end
  end
end
