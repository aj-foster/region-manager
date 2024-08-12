defmodule RM.Repo.Migrations.AddRemovedAtToFirstEvents do
  use Ecto.Migration

  def change do
    alter table(:first_events) do
      add :removed_at, :utc_datetime_usec
    end
  end
end
