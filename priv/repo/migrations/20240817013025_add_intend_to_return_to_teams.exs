defmodule RM.Repo.Migrations.AddIntendToReturnToTeams do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :intend_to_return, :boolean, null: false, default: false
    end
  end
end
