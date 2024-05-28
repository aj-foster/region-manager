defmodule RM.FIRST.Event do
  use Ecto.Schema

  alias RM.FIRST.League
  alias RM.FIRST.Region
  alias RM.Local.EventSettings

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
    belongs_to :region, Region
    has_one :settings, EventSettings

    embeds_one :location, Location, on_replace: :update, primary_key: false do
      field :address, :string
      field :city, :string
      field :country, :string
      field :state_province, :string
      field :venue, :string
    end

    timestamps type: :utc_datetime_usec
  end

  @spec from_ftc_events(map, map, map) :: map
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
        league_id_map \\ %{}
      ) do
    now = DateTime.utc_now()
    region = regions_by_code[region_code]

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
      league_id: league_id_map[league_code],
      live_stream_url: live_stream_url,
      name: name,
      published: published,
      region_id: region && region.id,
      remote: remote,
      type: cast_type(type_code),
      updated_at: now,
      website: website,
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
    Date.compare(a.date_start, b.date_start)
  end
end
