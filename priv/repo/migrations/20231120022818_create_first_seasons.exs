defmodule Connect.Repo.Migrations.CreateFirstSeasons do
  use Ecto.Migration

  def change do
    create table(:first_seasons, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :name, :text, null: false
      add :year, :integer, null: false

      timestamps type: :utc_datetime_usec
    end

    create index(:first_seasons, [:year])
  end
end
