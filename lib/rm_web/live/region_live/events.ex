defmodule RMWeb.RegionLive.Events do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  alias RM.FIRST.Event

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}

  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  def handle_params(_params, _uri, socket) do
    region =
      socket.assigns[:region]
      |> RM.Repo.preload(:events)
      |> Map.update!(:events, &Enum.sort(&1, Event))

    socket
    |> assign(region: region)
    |> noreply()
  end
end
