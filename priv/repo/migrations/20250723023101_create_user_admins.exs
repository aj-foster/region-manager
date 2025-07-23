defmodule RM.Repo.Migrations.CreateUserAdmins do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_admins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :permissions, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end
  end
end
