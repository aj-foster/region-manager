defmodule RMWeb.DashboardLive.Home do
  use RMWeb, :live_view

  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    socket
    |> assign(
      league_count: length(current_user.leagues),
      region_count: length(current_user.regions),
      team_count: length(current_user.teams)
    )
    |> ok()
  end
end
