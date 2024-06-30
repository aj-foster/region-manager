defmodule RM.Local.EventProposal do
  use Ecto.Schema

  alias Ecto.Changeset
  alias RM.FIRST.League
  alias RM.FIRST.Region
  alias RM.Local.Log
  alias RM.Local.Venue

  @type t :: %__MODULE__{}

  @typedoc "Even formats"
  @type format :: :traditional | :hybrid | :remote
  @formats [:traditional, :hybrid, :remote]

  @typedoc "Event type"
  @type type ::
          :scrimmage
          | :league_meet
          | :qualifier
          | :league_tournament
          | :off_season
          | :kickoff
          | :workshop
          | :demo
          | :volunteer
          | :practice

  @types [
    :scrimmage,
    :league_meet,
    :qualifier,
    :league_tournament,
    :off_season,
    :kickoff,
    :workshop,
    :demo,
    :volunteer,
    :practice
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @required_fields [:date_end, :date_start, :format, :name, :season, :type, :venue]

  schema "event_proposals" do
    field :capacity, :integer
    field :description, :string
    field :date_end, :date
    field :date_start, :date
    field :format, Ecto.Enum, values: @formats
    field :live_stream_url, :string
    field :name, :string
    field :notes, :string
    field :season, :integer
    field :type, Ecto.Enum, values: @types
    field :website, :string

    embeds_many :log, Log

    timestamps type: :utc_datetime_usec
    field :submitted_at, :utc_datetime_usec
    field :removed_at, :utc_datetime_usec

    belongs_to :first_event, RM.FIRST.Event
    belongs_to :league, League
    belongs_to :region, Region
    belongs_to :venue, Venue

    embeds_one :registration_settings, RegistrationSettings, on_replace: :update

    embeds_one :contact, Contact, on_replace: :update do
      field :email, :string
      field :name, :string
      field :phone, :string
    end

    # has_many :attachments, File, join_through: :event_attachments
  end

  #
  # Changesets
  #

  @doc """
  Create a changeset for proposing a new event
  """
  @spec create_changeset(map) :: Changeset.t(t)
  def create_changeset(params) do
    %__MODULE__{}
    |> Changeset.cast(params, [
      :capacity,
      :description,
      :date_end,
      :date_start,
      :format,
      :live_stream_url,
      :name,
      :notes,
      :season,
      :type,
      :website
    ])
    |> Changeset.cast_embed(:contact, with: &contact_changeset/2)
    |> Changeset.put_assoc(:league, params["league"])
    |> Changeset.put_assoc(:region, params["region"])
    |> Changeset.put_assoc(:venue, params["venue"])
    |> Changeset.put_embed(:log, [Log.new("created", params)])
    |> Changeset.validate_required(@required_fields)
  end

  @spec contact_changeset(%__MODULE__.Contact{}, map) :: Changeset.t(%__MODULE__.Contact{})
  defp contact_changeset(contact, params) do
    contact
    |> Changeset.cast(params, [:email, :name, :phone])
    |> Changeset.validate_required([:email, :name, :phone])
  end
end
