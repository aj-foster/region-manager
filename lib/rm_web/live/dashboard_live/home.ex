defmodule RMWeb.DashboardLive.Home do
  use RMWeb, :live_view

  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    unconfirmed_email_count = Enum.count(current_user.emails, fn e -> is_nil(e.confirmed_at) end)

    socket
    |> assign(
      page_title: "Dashboard",
      league_count: length(current_user.leagues),
      region_count: length(current_user.regions),
      team_count: length(current_user.teams),
      unconfirmed_email_count: unconfirmed_email_count
    )
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
