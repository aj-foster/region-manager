defmodule RM.Repo.Migrations.MigrateLeagues do
  use Ecto.Migration

  def change do
    execute "TRUNCATE first_leagues CASCADE", "TRUNCATE leagues CASCADE"

    alter table(:event_proposals) do
      modify :league_id, references(:leagues, type: :uuid, on_delete: :delete_all),
        from: references(:first_leagues, type: :uuid, on_delete: :nilify_all)
    end

    alter table(:event_venues) do
      modify :league_id, references(:leagues, type: :uuid, on_delete: :delete_all),
        null: false,
        from: {references(:first_leagues, type: :uuid, on_delete: :delete_all), null: false}
    end

    alter table(:league_settings) do
      modify :league_id, references(:leagues, type: :uuid, on_delete: :delete_all),
        null: false,
        from: {references(:first_leagues, type: :uuid, on_delete: :delete_all), null: false}
    end

    alter table(:user_leagues) do
      modify :league_id, references(:leagues, type: :uuid, on_delete: :delete_all),
        null: false,
        from: {references(:first_leagues, type: :uuid, on_delete: :delete_all), null: false}
    end
  end
end
