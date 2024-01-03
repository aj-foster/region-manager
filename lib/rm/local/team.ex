defmodule RM.Local.Team do
  alias RM.FIRST.Region
  use Ecto.Schema

  @typedoc "Team record"
  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "teams" do
    field :event_ready, :boolean
    field :name, :string
    field :number, :integer
    field :rookie_year, :integer
    field :team_id, :integer
    field :temporary_number, :integer
    field :website, :string
    timestamps type: :utc_datetime_usec

    belongs_to :region, Region

    embeds_one :location, Location do
      field :city, :string
      field :country, :string
      field :county, :string
      field :postal_code, :string
      field :state_province, :string
    end

    embeds_one :notices, Notices do
      field :lc1_missing, :boolean
      field :lc1_ypp, :boolean
      field :lc2_missing, :boolean
      field :lc2_ypp, :boolean
      field :unsecured, :boolean
    end
  end
end
