defmodule RM.Repo.Migrations.AddKickoffToSeasons do
  use Ecto.Migration

  def change do
    alter table(:first_seasons) do
      add :kickoff, :date
    end
  end
end
