defmodule RM.Repo.Migrations.CreateFirstTeams do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:first_teams, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :city, :text
      add :country, :text
      add :display_location, :text
      add :display_team_number, :text
      add :name_full, :text
      add :name_short, :text
      add :robot_name, :text
      add :rookie_year, :integer
      add :season, :integer, null: false
      add :school_name, :text
      add :state_province, :text
      add :team_number, :integer, null: false
      add :website, :text

      add :region_id, references(:first_regions, type: :uuid, on_delete: :delete_all), null: false

      timestamps type: :utc_datetime_usec
    end

    create unique_index(:first_teams, [:team_number, :season])
    create index(:first_teams, [:region_id])
  end
end
