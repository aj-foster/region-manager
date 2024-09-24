defmodule RM.Local.EventProposal do
  use Ecto.Schema
  import Ecto.Query

  alias Ecto.Changeset
  alias RM.FIRST.Region
  alias RM.Local.League
  alias RM.Local.Log
  alias RM.Local.Query
  alias RM.Local.RegistrationSettings
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

  @required_fields [:date_end, :date_start, :format, :name, :season, :type]
  @optional_fields [:description, :live_stream_url, :notes, :website]

  schema "event_proposals" do
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
    belongs_to :venue, Venue, on_replace: :nilify

    # Temporary: no longer used once copied to the :first_event on import / reconciliation.
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
    registration_settings =
      if league = params["league"] do
        league.settings.registration
      end

    %__MODULE__{registration_settings: registration_settings}
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.cast_embed(:contact, with: &contact_changeset/2)
    |> Changeset.cast_embed(:registration_settings, with: &RegistrationSettings.changeset/2)
    |> Changeset.put_assoc(:league, params["league"])
    |> Changeset.put_assoc(:region, params["region"])
    |> Changeset.put_assoc(:venue, params["venue"])
    |> Changeset.put_embed(:log, [Log.new("created", params)])
    |> Changeset.validate_required(@required_fields)
    |> Changeset.validate_required([:region, :venue])
    |> validate_dates()
  end

  @doc """
  Create a changeset to update an existing event proposal
  """
  @spec update_changeset(t, map) :: Changeset.t(t)
  def update_changeset(proposal, params) do
    proposal
    |> Changeset.cast(params, @required_fields ++ @optional_fields)
    |> Changeset.cast_embed(:contact, with: &contact_changeset/2)
    |> Changeset.cast_embed(:registration_settings, with: &RegistrationSettings.changeset/2)
    |> Changeset.put_assoc(:venue, params["venue"])
    |> Changeset.put_embed(:log, [Log.new("updated", params) | proposal.log])
    |> Changeset.validate_required(@required_fields)
    |> Changeset.validate_required([:venue])
    |> validate_dates()
  end

  @spec contact_changeset(%__MODULE__.Contact{}, map) :: Changeset.t(%__MODULE__.Contact{})
  defp contact_changeset(contact, params) do
    contact
    |> Changeset.cast(params, [:email, :name, :phone])
    |> Changeset.validate_required([:email, :name, :phone])
  end

  @spec validate_dates(Changeset.t(t)) :: Changeset.t(t)
  defp validate_dates(changeset) do
    date_start = Changeset.get_field(changeset, :date_start)
    date_end = Changeset.get_field(changeset, :date_end)

    cond do
      is_nil(date_end) or is_nil(date_start) ->
        changeset

      Date.before?(date_end, date_start) ->
        Changeset.add_error(changeset, :date_end, "cannot be before start date")

      Date.diff(date_end, date_start) > 7 ->
        Changeset.add_error(changeset, :date_start, "cannot be more than 7 days before end date")

      :else ->
        changeset
    end
  end

  #
  # Queries
  #

  @doc """
  Select proposals from the given season
  """
  @spec season_query(integer) :: Ecto.Query.t()
  def season_query(season) do
    from(__MODULE__, as: :event)
    |> where([event: e], e.season == ^season)
  end

  @doc "Query to update the provided proposals' submitted_at field to the current time"
  @spec update_submitted_at_query([t]) :: Ecto.Query.t()
  def update_submitted_at_query(proposals) do
    ids = Enum.map(proposals, & &1.id)
    now = DateTime.utc_now()

    Query.from_proposal()
    |> where([proposal: p], p.id in ^ids)
    |> update(set: [submitted_at: ^now])
  end

  #
  # Helpers
  #

  @doc "Whether the given event originated from the given proposal"
  @spec event_matches?(t, RM.FIRST.Event.t()) :: boolean
  def event_matches?(proposal, event)

  def event_matches?(%__MODULE__{first_event_id: a}, %RM.FIRST.Event{id: b}) when not is_nil(a) do
    a == b
  end

  def event_matches?(proposal, event) do
    proposal.region_id == event.region_id and
      proposal.date_end == event.date_end and
      proposal.type == event.type and
      loose_match?(proposal.venue.city, event.location.city)
  end

  defp loose_match?(nil, nil), do: true
  defp loose_match?(_, nil), do: false
  defp loose_match?(nil, _), do: false

  defp loose_match?(a, b) do
    String.jaro_distance(
      a |> String.trim() |> String.downcase(),
      b |> String.trim() |> String.downcase()
    ) > 0.8
  end

  @doc "Whether the proposed event has passed"
  @spec event_passed?(t) :: boolean
  def event_passed?(proposal) do
    %__MODULE__{date_end: date_end, venue: %RM.Local.Venue{timezone: timezone}} = proposal
    today = DateTime.now!(timezone) |> DateTime.to_date()
    Date.after?(today, date_end)
  end

  @doc "Whether the proposal should be submitted to FIRST"
  @spec pending?(t) :: boolean
  def pending?(proposal)
  def pending?(%__MODULE__{first_event_id: <<_::binary>>}), do: false
  def pending?(%__MODULE__{submitted_at: %DateTime{}}), do: false
  def pending?(proposal), do: not event_passed?(proposal)

  @doc "Human-readable event format"
  @spec format_string(t) :: String.t()
  def format_string(%__MODULE__{format: :traditional}), do: "Traditional"
  def format_string(%__MODULE__{format: :hybrid}), do: "Hybrid"
  def format_string(%__MODULE__{format: :remote}), do: "Remote"

  #
  # Protocols
  #

  @doc false
  def compare(a, b) do
    date_comparison = Date.compare(a.date_start, b.date_start)

    cond do
      date_comparison == :lt -> :lt
      date_comparison == :gt -> :gt
      a.name < b.name -> :lt
      a.name > b.name -> :gt
      :else -> :eq
    end
  end
end
