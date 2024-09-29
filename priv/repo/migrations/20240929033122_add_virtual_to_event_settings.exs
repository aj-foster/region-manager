defmodule RM.Repo.Migrations.AddVirtualToEventSettings do
  use Ecto.Migration

  def change do
    alter table(:event_settings) do
      add :virtual, :boolean, null: false, default: false
    end
  end
end
