defmodule RMWeb.TeamLive.Show do
  use RMWeb, :live_view
  import RMWeb.TeamLive.Util

  on_mount {RMWeb.TeamLive.Util, :preload_team}
  on_mount {RMWeb.TeamLive.Util, :require_team_manager}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
