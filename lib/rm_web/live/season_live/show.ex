defmodule RMWeb.SeasonLive.Show do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  on_mount {RMWeb.Live.Util, :require_season}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_season()
    |> assign_regions()
    |> ok()
  end

  #
  # Helpers
  #

  @spec assign_season(Socket.t()) :: Socket.t()
  defp assign_season(socket) do
    season_year = socket.assigns[:season]

    case RM.FIRST.fetch_season_by_year(season_year) do
      {:ok, season} ->
        assign(socket, season: season)

      {:error, :season, :not_found} ->
        socket
        |> put_flash(:error, "Season #{season_year} is not available in Region Manager")
        |> redirect(to: ~p"/s")
    end
  end

  @spec assign_regions(Socket.t()) :: Socket.t()
  defp assign_regions(socket) do
    regions = RM.FIRST.list_regions()
    assign(socket, regions: regions, regions_count: length(regions))
  end
end
