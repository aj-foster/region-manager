defmodule RMWeb.LeagueLive.Teams do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}

  def mount(_params, _session, socket) do
    league = socket.assigns[:league]
    {active_teams, inactive_teams} = Enum.split_with(league.teams, & &1.active)

    socket
    |> assign(
      active_teams: active_teams,
      active_teams_count: length(active_teams),
      inactive_teams: inactive_teams,
      inactive_teams_count: length(inactive_teams)
    )
    |> ok()
  end
end
