defmodule RMWeb.CalendarController do
  use RMWeb, :controller

  def region(conn, %{"region" => abbreviation}) do
    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation) do
      events = RM.FIRST.list_calendar_events_by_region(region)
      send_calendar(conn, "#{region.name} Events", events)
    end
  end

  def league(conn, %{"region" => abbreviation, "league" => code}) do
    with {:ok, region} <- RM.FIRST.fetch_region_by_abbreviation(abbreviation),
         {:ok, league} <- RM.Local.fetch_league_by_code(abbreviation, code) do
      events = RM.FIRST.list_calendar_events_by_region(region, league: league)

      send_calendar(conn, "#{league.name} Events", events)
    end
  end

  defp send_calendar(conn, name, events) do
    conn
    |> put_resp_content_type("text/calendar")
    |> put_resp_header("cache-control", "no-cache, must-revalidate")
    |> send_resp(:ok, RMWeb.ICS.render(name, events))
  end
end
