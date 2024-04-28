defmodule RMWeb.LeagueLive.Events do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}

  def mount(_params, _session, socket) do
    socket
    |> ok()
  end
end
