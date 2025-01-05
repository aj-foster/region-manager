defmodule RM.Repo.Migrations.AddLogToEventVideos do
  use Ecto.Migration

  def change do
    alter table(:event_videos) do
      add :log, :jsonb, null: false, default: fragment("'[]'::jsonb")

      modify :team_id, references(:teams, type: :uuid, on_delete: :delete_all),
        null: false,
        from: {references(:first_teams, type: :uuid, on_delete: :delete_all), null: false}
    end
  end
end
