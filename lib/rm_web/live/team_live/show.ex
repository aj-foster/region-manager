defmodule RMWeb.TeamLive.Show do
  use RMWeb, :live_view
  import RMWeb.TeamLive.Util

  on_mount {RMWeb.TeamLive.Util, :preload_team}
  on_mount {RMWeb.TeamLive.Util, :require_team_manager}

  def mount(_params, _session, socket) do
    team = socket.assigns[:team]

    socket
    |> assign(page_title: "Team #{team.number} Overview")
    |> ok()
  end

  #
  # Template Helpers
  #

  defp requires_attention?(team) do
    team.notices.lc1_missing or
      team.notices.lc1_ypp or
      team.notices.lc2_missing or
      team.notices.lc2_ypp or
      team.notices.unsecured
  end
end
