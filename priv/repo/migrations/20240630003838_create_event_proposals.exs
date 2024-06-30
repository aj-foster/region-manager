defmodule RM.Repo.Migrations.CreateEventProposals do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:event_proposals, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :capacity, :integer
      add :description, :text, null: false
      add :date_end, :date, null: false
      add :date_start, :date, null: false
      add :format, :text, null: false
      add :live_stream_url, :text
      add :name, :text, null: false
      add :notes, :text
      add :season, :integer, null: false
      add :type, :text, null: false
      add :website, :text

      add :log, :jsonb, null: false, default: fragment("'[]'::jsonb")
      timestamps type: :utc_datetime_usec
      add :submitted_at, :utc_datetime_usec
      add :removed_at, :utc_datetime_usec

      add :first_event_id, references(:first_events, type: :uuid, on_delete: :nilify_all)
      add :league_id, references(:first_leagues, type: :uuid, on_delete: :nilify_all)
      add :region_id, references(:first_regions, type: :uuid, on_delete: :delete_all)
      add :venue_id, references(:event_venues, type: :uuid, on_delete: :nilify_all)

      add :contact, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :registration_settings, :jsonb, null: false, default: fragment("'{}'::jsonb")
    end
  end
end
