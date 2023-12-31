defmodule RM.Repo.Migrations.CreateUserRegions do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:user_regions, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :region_id, references(:first_regions, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps type: :utc_datetime_usec
    end

    create_if_not_exists unique_index(:user_regions, [:region_id, :user_id])
  end
end
