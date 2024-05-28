defmodule RMWeb.TeamLive.Events do
  use RMWeb, :live_view
  import RMWeb.TeamLive.Util

  on_mount {RMWeb.TeamLive.Util, :preload_team}
  on_mount {RMWeb.TeamLive.Util, :require_team_manager}

  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  def handle_params(_params, _uri, socket) do
    socket
    |> load_events()
    |> noreply()
  end
end
