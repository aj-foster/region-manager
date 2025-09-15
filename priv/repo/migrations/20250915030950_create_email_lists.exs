defmodule RM.Repo.Migrations.CreateEmailLists do
  use Ecto.Migration

  def change do
    create table(:email_lists, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :name, :text, null: false
      add :description, :text

      add :auto_subscribe, :jsonb, null: false, default: fragment("'{}'::jsonb")
      add :metadata, :jsonb, null: false, default: fragment("'{}'::jsonb")

      add :region_id, references(:first_regions, type: :binary_id, on_delete: :nilify_all)
      add :league_id, references(:leagues, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
      add :removed_at, :utc_datetime_usec
    end

    create index(:email_lists, [:region_id])
    create index(:email_lists, [:league_id])
  end
end
