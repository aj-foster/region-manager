defmodule RM.Repo.Migrations.CreateUserLeagues do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_leagues, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :league_id, references(:first_leagues, type: :uuid, on_delete: :delete_all), null: false
      add :permissions, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps type: :utc_datetime_usec
    end
  end
end
