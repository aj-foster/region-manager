defmodule RM.Repo.Migrations.RemoveCapacityFromEventProposals do
  use Ecto.Migration

  def change do
    alter table(:event_proposals) do
      remove :capacity, :integer
      modify :description, :text, null: true, from: {:text, null: false}
    end
  end
end
