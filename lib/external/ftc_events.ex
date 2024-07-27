defmodule External.FTCEvents do
  @moduledoc """
  Interface for the [FTC Events API](https://ftc-events.firstinspires.org/services/API) and
  related data
  """
  alias RM.FIRST.League
  alias RM.FIRST.Region
  alias External.FTCEvents.API

  @spec list_events(integer) :: API.response(API.list_events_response())
  def list_events(season) do
    API.client().list_events(season)
  end

  @spec list_leagues(integer, Region.t()) :: API.response(API.list_leagues_response())
  def list_leagues(season, region) do
    %Region{code: region_code} = region
    API.client().list_leagues(season, region: region_code)
  end

  @spec list_league_members(integer, Region.t(), League.t()) ::
          API.response(API.list_league_members_response())
  def list_league_members(season, region, league) do
    %Region{code: region_code} = region
    %League{code: league_code} = league
    API.client().list_league_members(season, region_code, league_code)
  end

  @spec list_teams(integer, Region.t()) :: API.response(API.list_teams_response())
  @spec list_teams(integer, Region.t(), API.list_teams_options()) ::
          API.response(API.list_teams_response())
  def list_teams(season, region, opts \\ []) do
    %Region{metadata: %Region.Metadata{code_list_teams: code}} = region
    API.client().list_teams(season, code, opts)
  end
end
