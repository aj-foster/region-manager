defmodule RM.Repo.Migrations.ChangeCodesToCitext do
  use Ecto.Migration

  def change do
    alter table(:first_events) do
      modify :code, :citext, from: :text
    end

    alter table(:first_leagues) do
      modify :code, :citext, from: :text
    end

    alter table(:first_regions) do
      modify :code, :citext, from: :text
    end
  end
end
