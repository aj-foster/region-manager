defmodule RMWeb.RegionController do
  use RMWeb, :controller
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

  def teams(conn, %{"region" => abbreviation}) do
    season = conn.assigns[:season]

    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation, preload: [:leagues]) do
      if season == region.current_season do
        teams = RM.Local.list_teams_by_region(region, active: true, preload: [:league])
        render(conn, :teams, teams: teams)
      else
        teams = RM.FIRST.list_teams_by_region(region, preload: [:league], season: season)
        render(conn, :teams, teams: teams)
      end
    end
  end

  #
  # Helper Plugs
  #

  @spec assign_season(Plug.Conn.t(), any) :: Plug.Conn.t()
  defp assign_season(%Plug.Conn{path_params: %{"season" => season}} = conn, _opts) do
    case Integer.parse(season) do
      {season, ""} -> assign(conn, :season, season)
      :error -> assign(conn, :season, RM.System.current_season())
    end
  end

  defp assign_season(conn, _opts) do
    assign(conn, :season, RM.System.current_season())
  end
end
