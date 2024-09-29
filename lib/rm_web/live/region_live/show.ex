defmodule RMWeb.RegionLive.Show do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}

  def mount(_params, _session, socket) do
    current_season = RM.System.current_season()
    region = socket.assigns[:region]
    unready_teams = Enum.reject(region.teams, & &1.event_ready)

    socket
    |> assign(
      current_season: current_season,
      needs_setup: region.current_season < current_season,
      unready_teams: unready_teams,
      unready_team_count: length(unready_teams),
      page_title: "#{region.name} Overview"
    )
    |> ok()
  end
end
