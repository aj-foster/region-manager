defmodule RM.Repo.Migrations.CreateFirstEvents do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:first_events, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :code, :text, null: false
      add :date_end, :date, null: false
      add :date_start, :date, null: false
      add :date_timezone, :text, null: false
      add :division_code, :text
      add :field_count, :integer, null: false
      add :hybrid, :boolean, null: false
      add :live_stream_url, :text
      add :league_id, references(:first_leagues, type: :uuid, on_delete: :nilify_all)
      add :location, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :name, :text, null: false
      add :published, :boolean, null: false
      add :region_id, references(:first_regions, type: :uuid, on_delete: :delete_all), null: false
      add :remote, :boolean, null: false
      add :season, :integer, null: false
      add :type, :text, null: false
      add :website, :text

      timestamps type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:first_events, [:season, :code])
    create_if_not_exists index(:first_events, [:season, :league_id])
    create_if_not_exists index(:first_events, [:season, :region_id])
  end
end
