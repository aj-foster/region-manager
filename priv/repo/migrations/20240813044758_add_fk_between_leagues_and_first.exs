defmodule RM.Repo.Migrations.AddFkBetweenLeaguesAndFirst do
  use Ecto.Migration

  def change do
    alter table(:first_leagues) do
      add :local_league_id, references(:leagues, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:first_events) do
      add :local_league_id, references(:leagues, type: :uuid, on_delete: :nilify_all)
    end
  end
end
