defmodule RM.Repo.Migrations.AddEmailToUserLeagues do
  use Ecto.Migration

  def change do
    alter table(:user_leagues) do
      add :email, :citext, null: false

      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all),
        null: true,
        from: {references(:users, type: :uuid, on_delete: :delete_all), null: false}
    end
  end
end
