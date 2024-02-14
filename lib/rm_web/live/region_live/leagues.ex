defmodule RMWeb.RegionLive.Leagues do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_owner}

  def mount(_params, _session, socket) do
    region = socket.assigns[:region]

    socket
    |> assign(league_count: length(region.leagues))
    |> ok()
  end
end
