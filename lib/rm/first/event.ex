defmodule RM.FIRST.Event do
  use Ecto.Schema

  alias RM.FIRST.League
  alias RM.FIRST.Region
  alias RM.Local.EventProposal
  alias RM.Local.EventRegistration
  alias RM.Local.EventSettings
  alias RM.Local.RegistrationSettings

  @type t :: %__MODULE__{}

  @typedoc "Event type"
  @type type ::
          :scrimmage
          | :league_meet
          | :qualifier
          | :league_tournament
          | :regional_championship
          | :championship
          | :super_qualifier
          | :off_season
          | :kickoff
          | :workshop
          | :demo
          | :volunteer
          | :practice
          | :unknown
  @types [
    :scrimmage,
    :league_meet,
    :qualifier,
    :league_tournament,
    :regional_championship,
    :championship,
    :super_qualifier,
    :off_season,
    :kickoff,
    :workshop,
    :demo,
    :volunteer,
    :practice,
    :unknown
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "first_events" do
    field :code, :string
    field :date_end, :date
    field :date_start, :date
    field :date_timezone, :string
    field :division_code, :string
    field :field_count, :integer
    field :hybrid, :boolean
    field :live_stream_url, :string
    field :name, :string
    field :published, :boolean
    field :remote, :boolean
    field :season, :integer
    field :type, Ecto.Enum, values: @types
    field :website, :string

    belongs_to :league, League
    belongs_to :local_league, RM.Local.League
    belongs_to :region, Region
    has_one :proposal, EventProposal, foreign_key: :first_event_id
    has_many :registrations, EventRegistration
    has_one :settings, EventSettings

    embeds_one :location, Location, on_replace: :update, primary_key: false do
      field :address, :string
      field :city, :string
      field :country, :string
      field :state_province, :string
      field :venue, :string
    end

    timestamps type: :utc_datetime_usec
    field :removed_at, :utc_datetime_usec
  end

  @spec from_ftc_events(map, map, map, map) :: map
  def from_ftc_events(
        %{
          "address" => address,
          "city" => city,
          "code" => code,
          "country" => country,
          "dateEnd" => date_end,
          "dateStart" => date_start,
          "divisionCode" => division_code,
          "eventId" => id,
          "fieldCount" => field_count,
          "hybrid" => hybrid,
          "leagueCode" => league_code,
          "liveStreamUrl" => live_stream_url,
          "name" => name,
          "published" => published,
          "regionCode" => region_code,
          "remote" => remote,
          "stateprov" => state_province,
          "timezone" => timezone,
          "type" => type_code,
          "venue" => venue,
          "website" => website
        },
        regions_by_code,
        leagues_by_code,
        local_leagues_by_code
      ) do
    now = DateTime.utc_now()
    region = regions_by_code[region_code]
    league = leagues_by_code[{region_code, league_code}]
    local_league = local_leagues_by_code[{region_code, league_code}]

    %{
      code: code,
      date_end: cast_date(date_end),
      date_start: cast_date(date_start),
      date_timezone: timezone,
      division_code: division_code,
      field_count: field_count,
      hybrid: hybrid,
      id: id,
      inserted_at: now,
      league_id: league && league.id,
      local_league_id: local_league && local_league.id,
      live_stream_url: if(live_stream_url != "", do: live_stream_url),
      name: name,
      published: published,
      region_id: region && region.id,
      remote: remote,
      removed_at: nil,
      type: cast_type(type_code),
      updated_at: now,
      website: if(website != "", do: website),
      location: %__MODULE__.Location{
        address: address,
        city: city,
        country: country,
        state_province: state_province,
        venue: venue
      }
    }
  end

  @spec cast_date(String.t()) :: Date.t()
  defp cast_date(timestamp) do
    timestamp
    |> NaiveDateTime.from_iso8601!()
    |> NaiveDateTime.to_date()
  end

  @spec cast_type(String.t()) :: type
  defp cast_type("0"), do: :scrimmage
  defp cast_type("1"), do: :league_meet
  defp cast_type("2"), do: :qualifier
  defp cast_type("3"), do: :league_tournament
  defp cast_type("4"), do: :regional_championship
  defp cast_type("6"), do: :championship
  defp cast_type("7"), do: :super_qualifier
  defp cast_type("10"), do: :off_season
  defp cast_type("12"), do: :kickoff
  defp cast_type("13"), do: :workshop
  defp cast_type("14"), do: :demo
  defp cast_type("15"), do: :volunteer
  defp cast_type("16"), do: :practice
  defp cast_type(_), do: :unknown

  #
  # Helpers
  #

  @doc "Whether the event has passed"
  @spec event_passed?(t) :: boolean
  def event_passed?(event) do
    %__MODULE__{date_end: date_end, date_timezone: date_timezone} = event
    today = DateTime.now!(date_timezone) |> DateTime.to_date()
    Date.after?(today, date_end)
  end

  @doc "Whether the event spans multiple calendar days"
  @spec multi_day?(t) :: boolean
  def multi_day?(%__MODULE__{date_start: start, date_end: finish}) do
    Date.after?(finish, start)
  end

  @doc "Deadline for registering, in the event's local timezone"
  @spec registration_deadline(t) :: DateTime.t()
  def registration_deadline(event) do
    %__MODULE__{
      date_start: date_start,
      date_timezone: date_timezone,
      settings: %EventSettings{registration: %RegistrationSettings{deadline_days: deadline_days}}
    } = event

    DateTime.new!(
      Date.add(date_start, -1 * deadline_days),
      Time.new!(23, 59, 59, 999_999),
      date_timezone
    )
  end

  @doc "Whether the registration deadline has passed"
  @spec registration_deadline_passed?(t) :: boolean
  def registration_deadline_passed?(event) do
    %__MODULE__{date_timezone: date_timezone} = event

    DateTime.after?(
      DateTime.now!(date_timezone),
      registration_deadline(event)
    )
  end

  @doc "Start of registration, in the event's local timezone"
  @spec registration_opens(t) :: DateTime.t()
  def registration_opens(event) do
    %__MODULE__{
      date_start: date_start,
      date_timezone: date_timezone,
      settings: %EventSettings{registration: %RegistrationSettings{open_days: open_days}}
    } = event

    DateTime.new!(
      Date.add(date_start, -1 * open_days),
      Time.new!(0, 0, 0, 1),
      date_timezone
    )
  end

  @doc "Whether the registration opening has passed"
  @spec registration_opening_passed?(t) :: boolean
  def registration_opening_passed?(event) do
    %__MODULE__{date_timezone: date_timezone} = event

    DateTime.after?(
      DateTime.now!(date_timezone),
      registration_opens(event)
    )
  end

  @doc "Human-readable format of the event"
  @spec format_name(t) :: String.t()
  def format_name(%__MODULE__{remote: true}), do: "Remote"
  def format_name(%__MODULE__{hybrid: true}), do: "Hybrid"
  def format_name(_event), do: "Traditional"

  @doc "Human-readable name of the given event type"
  @spec type_name(type) :: String.t()
  def type_name(:scrimmage), do: "Scrimmage"
  def type_name(:league_meet), do: "League Meet"
  def type_name(:qualifier), do: "Qualifier"
  def type_name(:league_tournament), do: "League Tournament"
  def type_name(:regional_championship), do: "Regional Championship"
  def type_name(:championship), do: "FIRST Championship"
  def type_name(:super_qualifier), do: "Super-Qualifier"
  def type_name(:off_season), do: "Off-Season"
  def type_name(:kickoff), do: "Kickoff"
  def type_name(:workshop), do: "Workshop"
  def type_name(:demo), do: "Demo / Exhibition"
  def type_name(:volunteer), do: "Volunteer Signup"
  def type_name(:practice), do: "Practice Day"
  def type_name(:unknown), do: "Unknown"

  #
  # Protocols
  #

  defimpl Phoenix.Param do
    def to_param(%RM.FIRST.Event{code: code}) do
      String.downcase(code)
    end
  end

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
