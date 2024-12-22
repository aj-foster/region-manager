defmodule RM.Repo.Migrations.AddVideoSubmissionToEventSettings do
  use Ecto.Migration

  def change do
    alter table(:event_settings) do
      add :video_submission, :boolean, null: false, default: false
      add :video_submission_date, :date
    end

    create_if_not_exists table(:event_videos, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :award, :text, null: false
      add :url, :text, null: false

      timestamps(type: :utc_datetime_usec)

      add :event_id, references(:first_events, type: :uuid, on_delete: :delete_all), null: false
      add :team_id, references(:first_teams, type: :uuid, on_delete: :delete_all), null: false
    end
  end
end
