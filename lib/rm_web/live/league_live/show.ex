defmodule RMWeb.LeagueLive.Show do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
