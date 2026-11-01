defmodule RM.Repo.Migrations.AddYouthOrganizationToTeams do
  use Ecto.Migration

  def change do
    alter table(:teams) do
      add :youth_organization, :string
    end
  end
end
