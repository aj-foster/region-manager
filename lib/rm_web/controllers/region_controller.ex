defmodule RMWeb.RegionController do
  use RMWeb, :controller
  import RMWeb.Controller.Util, only: [assign_season: 2]

  plug :assign_season

  def show(conn, %{"region" => abbreviation}) do
    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation) do
      render(conn, :show, region: region)
    end
  end

  def events(conn, %{"region" => abbreviation}) do
    preloads = [:league, :local_league, :proposal, :settings, :venue]
    season = conn.assigns[:season]

    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation) do
      events =
        RM.FIRST.list_events_by_region(region, season: season, preload: preloads)
        |> RM.Repo.preload(proposal: [:attachments], registrations: [:team])

      render(conn, :events, events: events)
    end
  end

  def leagues(conn, %{"region" => abbreviation}) do
    season = conn.assigns[:season]

    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation, preload: [:leagues]) do
      if season == region.current_season do
        render(conn, :leagues, leagues: region.leagues)
      else
        leagues = RM.FIRST.list_leagues_by_region(region, season: season)
        render(conn, :leagues, leagues: leagues)
      end
    end
  end

  def news(conn, %{"region" => abbreviation}) do
    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation) do
      news =
        if region.metadata.keila_sender_id do
          RM.Email.list_campaigns_for_region_or_league(region, page_size: 3)
        else
          []
        end

      render(conn, :news, news: news, region: region)
    end
  end

  def teams(conn, %{"region" => abbreviation}) do
    season = conn.assigns[:season]

    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation, preload: [:leagues]) do
      if season == region.current_season do
        teams = RM.Local.list_teams_by_region(region, active: true, preload: [:league])
        render(conn, :teams, teams: teams, season: season)
      else
        teams = RM.FIRST.list_teams_by_region(region, preload: [:league], season: season)
        render(conn, :teams, teams: teams, season: season)
      end
    end
  end

  def videos(conn, %{"region" => abbreviation}) do
    season = conn.assigns[:season]
    preloads = [:event, :team]

    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation) do
      videos =
        RM.Local.list_event_videos_by_region(region, season: season, preload: preloads)
        |> RM.Repo.preload(event: :settings)

      render(conn, :videos, videos: videos)
    end
  end
end
