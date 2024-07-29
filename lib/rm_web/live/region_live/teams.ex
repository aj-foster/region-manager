defmodule RMWeb.RegionLive.Teams do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}

  def mount(_params, _session, socket) do
    region =
      socket.assigns[:region]
      |> RM.Repo.preload(teams: [:league])

    socket
    |> assign(region: region)
    |> ok()
  end
end
