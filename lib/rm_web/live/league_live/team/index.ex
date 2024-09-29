defmodule RMWeb.LeagueLive.Team.Index do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}

  def mount(_params, _session, socket) do
    league = socket.assigns[:league]
    {active_teams, inactive_teams} = Enum.split_with(league.teams, & &1.active)
    intend_to_return = Enum.filter(inactive_teams, & &1.intend_to_return)

    socket
    |> assign(
      page_title: "#{league.name} Teams",
      active_teams: active_teams,
      active_teams_count: length(active_teams),
      inactive_teams: inactive_teams,
      inactive_teams_count: length(inactive_teams),
      intend_to_return_teams: intend_to_return,
      intend_to_return_teams_count: length(intend_to_return)
    )
    |> ok()
  end
end
