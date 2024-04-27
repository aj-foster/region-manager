defmodule RMWeb.RegionLive.Leagues do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_owner}

  def mount(_params, _session, socket) do
    socket
    |> ok()
  end
end
