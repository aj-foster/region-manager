defmodule External.FTCEvents do
  @moduledoc """
  Interface for the [FTC Events API](https://ftc-events.firstinspires.org/services/API) and
  related data
  """
  alias RM.FIRST.League
  alias RM.FIRST.Region
  alias External.FTCEvents.API

  @season 2023

  @spec list_events :: API.response(API.list_events_response())
  def list_events do
    API.client().list_events(@season)
  end

  @spec list_leagues(Region.t()) :: API.response(API.list_leagues_response())
  def list_leagues(region) do
    %Region{code: region_code} = region
    API.client().list_leagues(@season, region: region_code)
  end

  @spec list_league_members(Region.t(), League.t()) ::
          API.response(API.list_league_members_response())
  def list_league_members(region, league) do
    %Region{code: region_code} = region
    %League{code: league_code} = league
    API.client().list_league_members(@season, region_code, league_code)
  end
end
