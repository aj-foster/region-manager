defmodule Connect.Repo.Migrations.CreateFirstRegions do
  use Ecto.Migration

  def change do
    create table(:first_regions, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :abbreviation, :citext
      add :description, :text
      add :has_leagues, :boolean, null: false, default: false
      add :name, :text, null: false

      timestamps type: :utc_datetime_usec
    end

    create index(:first_regions, [:abbreviation])
    create index(:first_regions, [:name])
  end
end
