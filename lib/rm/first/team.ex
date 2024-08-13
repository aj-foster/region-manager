defmodule RM.FIRST.Team do
  @moduledoc """
  Team as represented in the FTC Events API

  This data does not include much of the information _Region Manager_ requires (for example,
  exact locations and coach contact information). This must be provided by the Program Delivery
  Partner via imports. However, because the FTC Events API is updated automatically when teams
  register, it can be a good canary for whether or not a team data import is necessary.
  """
  use Ecto.Schema

  alias RM.FIRST.Region

  @type t :: %__MODULE__{
          city: String.t() | nil,
          country: String.t() | nil,
          display_location: String.t() | nil,
          display_team_number: String.t() | nil,
          id: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          name_full: String.t() | nil,
          name_short: String.t() | nil,
          region: Ecto.Schema.belongs_to(Region.t()),
          region_id: Ecto.UUID.t(),
          robot_name: String.t() | nil,
          rookie_year: integer | nil,
          season: integer,
          school_name: String.t() | nil,
          state_province: String.t() | nil,
          team_number: integer,
          updated_at: DateTime.t(),
          website: String.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "first_teams" do
    field :city, :string
    field :country, :string
    field :display_location, :string
    field :display_team_number, :string
    field :name_full, :string
    field :name_short, :string
    field :robot_name, :string
    field :rookie_year, :integer
    field :season, :integer
    field :school_name, :string
    field :state_province, :string
    field :team_number, :integer
    field :website, :string

    belongs_to :region, Region
    has_one :league_assignment, RM.FIRST.LeagueAssignment
    has_one :league, through: [:league_assignment, :league]

    timestamps type: :utc_datetime_usec

    field :local_team, :any, virtual: true
  end

  @spec from_ftc_events(map, map) :: map
  def from_ftc_events(
        %{
          "city" => city,
          "country" => country,
          "displayLocation" => display_location,
          "displayTeamNumber" => display_team_number,
          "homeRegion" => region_code,
          "nameFull" => name_full,
          "nameShort" => name_short,
          "robotName" => robot_name,
          "rookieYear" => rookie_year,
          "schoolName" => school_name,
          "stateProv" => state_province,
          "teamNumber" => team_number,
          "website" => website
        },
        regions_by_code
      ) do
    now = DateTime.utc_now()
    region = regions_by_code[region_code]

    %{
      city: city,
      country: country,
      display_location: display_location,
      display_team_number: display_team_number,
      inserted_at: now,
      name_full: name_full,
      name_short: name_short,
      region_id: region && region.id,
      robot_name: robot_name,
      rookie_year: rookie_year,
      school_name: school_name,
      state_province: state_province,
      team_number: team_number,
      updated_at: now,
      website: website
    }
  end
end
