defmodule RMWeb.RegionLive.Teams do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_owner}

  def mount(_params, _session, socket) do
    region = socket.assigns[:region]
    unready_teams = Enum.reject(region.teams, & &1.event_ready)

    socket
    |> assign(
      unready_teams: unready_teams,
      unready_team_count: length(unready_teams)
    )
    |> ok()
  end
end
