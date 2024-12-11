defmodule RMWeb.LeagueLive.Overview do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}

  def mount(_params, _session, socket) do
    league = socket.assigns[:league]

    socket
    |> assign(page_title: league.name)
    |> ok()
  end
end
