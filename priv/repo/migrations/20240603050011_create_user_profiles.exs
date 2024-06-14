defmodule RM.Repo.Migrations.CreateUserProfiles do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_profiles, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :name, :text
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      timestamps type: :utc_datetime_usec

      add :metadata, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :settings, :jsonb, null: false, default: fragment("'{}'::jsonb")
    end
  end
end
