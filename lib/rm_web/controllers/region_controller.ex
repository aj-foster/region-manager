defmodule RMWeb.RegionController do
  use RMWeb, :controller
  plug :assign_season

  def show(conn, %{"region" => abbreviation}) do
    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation) do
      render(conn, :show, region: region)
    end
  end

  def events(conn, %{"region" => abbreviation}) do
    season = conn.assigns[:season]

    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation) do
      events = RM.FIRST.list_events_by_region(region, season: season)
      render(conn, :events, events: events)
    end
  end

  def leagues(conn, %{"region" => abbreviation}) do
    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation, preload: [:leagues]) do
      render(conn, :leagues, leagues: region.leagues)
    end
  end

  def teams(conn, %{"region" => abbreviation}) do
    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation, preload: [:leagues]) do
      teams = RM.Local.list_teams_by_region(region, preload: [:league])
      render(conn, :teams, teams: teams)
    end
  end

  #
  # Helper Plugs
  #

  @spec assign_season(Plug.Conn.t(), any) :: Plug.Conn.t()
  defp assign_season(%Plug.Conn{path_params: %{"season" => season}} = conn, _opts) do
    case Integer.parse(season) do
      {season, ""} -> assign(conn, :season, season)
      :error -> assign(conn, :season, RM.Config.get("current_season"))
    end
  end

  defp assign_season(conn, _opts) do
    assign(conn, :season, RM.Config.get("current_season"))
  end
end
