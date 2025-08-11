defmodule RMWeb.RegionLive.Show do
  use RMWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    region = socket.assigns[:region]
    {:ok, assign(socket, page_title: "#{region.name} Region")}
  end
end
