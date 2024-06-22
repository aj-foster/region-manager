defmodule RM.Local.Venue do
  use Ecto.Schema

  alias RM.FIRST.League
  alias RM.Local.Log

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "event_venues" do
    field :name, :string
    field :website, :string

    field :address, :string
    field :city, :string
    field :state_province, :string
    field :postal_code, :string
    field :country, :string
    field :timezone, :string

    field :notes, :string
    # belongs_to :map, File

    belongs_to :league, League

    embeds_many :log, Log

    timestamps type: :utc_datetime_usec
    field :hidden_at, :utc_datetime_usec
  end
end
