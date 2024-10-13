defmodule RMWeb.SeasonLive.Index do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_seasons()
    |> ok()
  end

  #
  # Helpers
  #

  @spec assign_seasons(Socket.t()) :: Socket.t()
  defp assign_seasons(socket) do
    current = RM.System.current_season()
    seasons = RM.FIRST.list_seasons() |> Enum.reverse()
    assign(socket, current_season: current, seasons: seasons, seasons_count: length(seasons))
  end
end
