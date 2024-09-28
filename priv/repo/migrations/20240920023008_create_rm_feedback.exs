defmodule RM.Repo.Migrations.CreateRmFeedback do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:rm_feedback, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :category, :text, null: false
      add :message, :text, null: false
      add :user_agent, :text, null: false
      add :user_id, :uuid, null: false

      timestamps type: :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
    end

    create_if_not_exists index(:rm_feedback, [:inserted_at])
  end
end
