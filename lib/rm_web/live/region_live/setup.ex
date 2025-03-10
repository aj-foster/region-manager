defmodule RMWeb.RegionLive.Setup do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_current_season()
    |> ok()
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("setup_submit_no_leagues", _params, socket) do
    socket
    |> setup_submit_no_leagues()
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_current_season(Socket.t()) :: Socket.t()
  defp assign_current_season(socket) do
    current_season = RM.System.current_season()
    region = socket.assigns[:region]

    assign(socket,
      current_season: current_season,
      needs_season_update: region.current_season < current_season
    )
  end

  @spec setup_submit_no_leagues(Socket.t()) :: Socket.t()
  defp setup_submit_no_leagues(socket) do
    region = socket.assigns[:region]
    season = socket.assigns[:current_season]

    case RM.FIRST.update_region_season(region, season) do
      {:ok, _region} ->
        socket
        |> assign_current_season()
        |> put_flash(:info, "Welcome to the new season!")
    end
  end
end
