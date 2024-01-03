defmodule RM.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:teams, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :event_ready, :boolean, null: false
      add :location, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :name, :text, null: false
      add :notices, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :number, :integer, null: false
      add :region_id, references(:first_regions, type: :uuid, on_delete: :delete_all), null: false
      add :rookie_year, :integer, null: false
      add :team_id, :integer, null: false
      add :temporary_number, :integer
      add :website, :text

      timestamps type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:teams, [:number])
    create_if_not_exists unique_index(:teams, [:team_id])

    create_if_not_exists table(:user_teams, primary_key: false) do
      add :id, :uuid, primary_key: false

      add :email, :citext, null: false
      add :notices, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :relationship, :text, null: false
      add :team_id, references(:teams, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid, on_delete: :nilify_all)

      timestamps type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:user_teams, [:email, :team_id])
    create_if_not_exists unique_index(:user_teams, [:team_id, :user_id])
  end
end
