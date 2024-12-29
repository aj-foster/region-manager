defmodule RM.Local.Venue do
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.FIRST.Region
  alias RM.Local.EventProposal
  alias RM.Local.League
  alias RM.Local.Log

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @required_fields [:name, :address, :city, :country, :timezone]
  @optional_fields [:website, :address_2, :state_province, :postal_code, :notes, :hidden_at]

  schema "event_venues" do
    field :name, :string
    field :website, :string

    field :address, :string
    field :address_2, :string
    field :city, :string
    field :state_province, :string
    field :postal_code, :string
    field :country, :string
    field :timezone, :string

    field :notes, :string
    # belongs_to :map, File

    belongs_to :league, League
    belongs_to :region, Region
    has_many :event_proposals, EventProposal

    embeds_many :log, Log

    timestamps type: :utc_datetime_usec
    field :hidden_at, :utc_datetime_usec
  end

  #
  # Changesets
  #

  @doc """
  Create a changeset for adding a new venue to the given region or league
  """
  @spec create_changeset(Region.t() | League.t(), map) :: Changeset.t(t)
  def create_changeset(%Region{} = region, params) do
    %__MODULE__{}
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.put_assoc(:region, region)
    |> Changeset.put_embed(:log, [Log.new("created", params)])
    |> Changeset.validate_required(@required_fields)
  end

  def create_changeset(%League{} = league, params) do
    %__MODULE__{}
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.put_assoc(:league, league)
    |> Changeset.put_assoc(:region, league.region)
    |> Changeset.put_embed(:log, [Log.new("created", params)])
    |> Changeset.validate_required(@required_fields)
  end

  @doc """
  Create a changeset to update an existing venue
  """
  @spec update_changeset(t, map) :: Changeset.t(t)
  def update_changeset(venue, params) do
    venue
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.put_embed(:log, [Log.new("updated", params) | venue.log])
    |> Changeset.validate_required(@required_fields)
  end

  @doc """
  Create a changeset based on an existing (published) event
  """
  @spec retroactive_changeset(RM.FIRST.Event.t(), League.t(), map) :: Changeset.t(t)
  def retroactive_changeset(event, league, params) do
    %RM.FIRST.Event{
      date_timezone: timezone,
      location: %RM.FIRST.Event.Location{
        address: address,
        city: city,
        country: country,
        state_province: state_province,
        venue: venue
      }
    } = event

    %__MODULE__{}
    |> Changeset.change(
      address: address,
      city: city,
      country: country,
      name: venue,
      state_province: state_province,
      timezone: timezone
    )
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.put_assoc(:league, league)
    |> Changeset.put_embed(:log, [Log.new("created", params)])
    |> Changeset.validate_required(@required_fields)
  end

  #
  # Protocols
  #

  @doc false
  def compare(a, b) do
    cond do
      a.name < b.name -> :lt
      a.name > b.name -> :gt
      :else -> :eq
    end
  end
end
