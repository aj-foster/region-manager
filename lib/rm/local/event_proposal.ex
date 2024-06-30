defmodule RM.Local.EventProposal do
  use Ecto.Schema

  alias RM.FIRST.League
  alias RM.FIRST.Region
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
end
