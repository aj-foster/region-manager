defmodule RMWeb.LeagueLive.Teams do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}

  def mount(_params, _session, socket) do
    league = socket.assigns[:league]
    unready_teams = Enum.reject(league.teams, & &1.event_ready)

    socket
    |> assign(
      unready_teams: unready_teams,
      unready_team_count: length(unready_teams)
    )
    |> ok()
  end
end
