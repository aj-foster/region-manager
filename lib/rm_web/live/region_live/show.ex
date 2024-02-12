defmodule RMWeb.RegionLive.Show do
  use RMWeb, :live_view

  on_mount {RMWeb.Live.Util, :preload_region}
  on_mount {RMWeb.Live.Util, :require_region_owner}

  def mount(_params, _session, socket) do
    region = socket.assigns[:region]
    unready_teams = Enum.reject(region.teams, & &1.event_ready)

    socket
    |> assign(
      league_count: length(region.leagues),
      team_count: length(region.teams),
      unready_teams: unready_teams,
      unready_team_count: length(unready_teams)
    )
    |> ok()
  end
end
