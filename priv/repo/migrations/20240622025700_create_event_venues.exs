defmodule RM.Repo.Migrations.CreateEventVenues do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:event_venues, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :league_id, references(:first_leagues, type: :uuid, on_delete: :delete_all), null: false

      add :name, :text, null: false
      add :website, :text

      add :address, :text, null: false
      add :address_2, :text
      add :city, :text, null: false
      add :state_province, :text
      add :postal_code, :text
      add :country, :text, null: false
      add :timezone, :text, null: false

      add :notes, :text
      add :map, :jsonb

      add :log, :jsonb, null: false, default: fragment("'[]'::jsonb")
      timestamps type: :utc_datetime_usec
      add :hidden_at, :utc_datetime_usec
    end
  end
end
