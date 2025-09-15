defmodule RM.Email.List do
  @moduledoc """
  Lists are groups of email addresses that can be sent to, subscribed to, and unsubscribed from
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "email_lists" do
    field :name, :string
    field :description, :string

    embeds_one :auto_subscribe, AutoSubscribe do
      # Admins of the target league or region
      field :admins, :boolean, default: false

      # Coaches of teams in the target league or region
      field :coaches, :boolean, default: false

      # Admins of sub-leagues, if present
      field :league_admins, :boolean, default: false
    end

    embeds_one :metadata, Metadata do
      field :subscriber_count, :integer, default: 0
    end

    belongs_to :region, RM.FIRST.Region
    belongs_to :league, RM.Local.League

    timestamps(type: :utc_datetime_usec)
    field :removed_at, :utc_datetime_usec
  end
end
