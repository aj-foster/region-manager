defmodule RMWeb.RegionLive.Show do
  use RMWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    region = socket.assigns[:region]

    socket
    |> assign(:page_title, "#{region.name} Region")
    |> assign_latest_news()
    |> ok()
  end

  #
  # Helpers
  #

  @spec assign_latest_news(Socket.t()) :: Socket.t()
  defp assign_latest_news(socket) do
    region = socket.assigns[:region]

    latest_news =
      if region.metadata.keila_project_id do
        RM.Email.list_campaigns_for_region_or_league(region, page_size: 3)
      else
        []
      end

    assign(socket, :latest_news, latest_news)
  end
end
