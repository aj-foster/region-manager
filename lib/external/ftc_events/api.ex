defmodule External.FTCEvents.API do
  @moduledoc """
  Interface for the [FTC Events API](https://ftc-events.firstinspires.org/services/API)

  This module defines the functions that can be used to interact with the API. The implementation
  of those functions can be found in `External.FTCEvents.API.Client` for production environments
  and a different module for development and testing. Which implementation is active depends on
  the configuration defined in `client/0`.
  """

  @typedoc "League code, such as \"FLOR\""
  @type league :: String.t()

  @typedoc "Page number for paginated responses (starting at `1`)"
  @type page :: pos_integer

  @typedoc "Region code, such as \"USFL\""
  @type region :: String.t()

  @typedoc "4-digit year when the season started"
  @type season :: pos_integer

  #
  # Client Callbacks
  #

  @typedoc false
  @type response :: response(term)
  @typedoc "Response from API calls"
  @type response(t) :: {:ok, t} | {:error, Exception.t()}

  # List Events

  @typedoc "Response data for the `c:list_events/2` endpoint"
  @type list_events_response :: %{count: integer, events: [map]}

  @doc false
  @callback list_events(season) :: response(list_events_response)
  @doc "Returns all FTC events in a particular season"
  @callback list_events(season, keyword) :: response(list_events_response)

  # List Leagues

  @typedoc "Options for the `c:list_leagues/2` endpoint"
  @type list_leagues_options :: [{:region, region} | {:league, league}]
  @typedoc "Response data for the `c:list_leagues/2` endpoint"
  @type list_leagues_response :: %{count: integer, leagues: [map]}

  @doc false
  @callback list_leagues(season) :: response(list_leagues_response)
  @doc "Returns all FTC leagues in a particular season"
  @callback list_leagues(season, list_leagues_options) :: response(list_leagues_response)

  # League Membership

  @typedoc "Response data for the `c:list_league_members/4` endpoint"
  @type list_league_members_response :: [integer]

  @doc false
  @callback list_league_members(season, region, league) :: response(list_league_members_response)
  @doc "Returns the list of team numbers for the teams that are members of a particular league"
  @callback list_league_members(season, region, league, keyword) ::
              response(list_league_members_response)

  # Teams

  @typedoc "Options for the `c:list_teams/2` endpoint"
  @type list_teams_options :: [{:page, page}]

  @typedoc "Response data for the `c:list_teams/3` endpoint"
  @type list_teams_response :: %{
          teams: [map],
          team_count_total: integer,
          team_count_page: integer,
          page_current: integer,
          page_total: integer
        }

  @doc false
  @callback list_teams(season, region) :: response(list_teams_response)
  @doc "Returns a paginated list of teams registered in the given region"
  @callback list_teams(season, region, keyword) :: response(list_teams_response)

  #
  # Configuration
  #

  @doc "Currently configured API client module"
  @spec client :: module
  def client do
    Application.get_env(:rm, External.FTCEvents.API, [])
    |> Keyword.get(:client, External.FTCEvents.API.Client)
  end
end
