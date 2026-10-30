defmodule RM.Repo.Migrations.AddDetailsUpdatedAtToEventProposals do
  use Ecto.Migration

  def change do
    alter table(:event_proposals) do
      add :details_updated_at, :utc_datetime_usec
    end
  end
end
