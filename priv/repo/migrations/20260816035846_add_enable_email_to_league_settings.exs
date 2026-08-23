defmodule RM.Repo.Migrations.AddEnableEmailToLeagueSettings do
  use Ecto.Migration

  def change do
    alter table(:league_settings) do
      add :enable_email, :boolean, default: false, null: false
    end
  end
end
