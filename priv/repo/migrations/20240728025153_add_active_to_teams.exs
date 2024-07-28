defmodule RM.Repo.Migrations.AddActiveToTeams do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :active, :boolean, null: false, default: true
      add :hidden_at, :utc_datetime_usec
    end
  end
end
