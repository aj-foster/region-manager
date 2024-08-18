defmodule RMWeb.DashboardLive.Home do
  use RMWeb, :live_view

  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    unconfirmed_email_count = Enum.count(current_user.emails, fn e -> is_nil(e.confirmed_at) end)

    socket
    |> assign(
      league_count: length(current_user.leagues),
      region_count: length(current_user.regions),
      team_count: length(current_user.teams),
      unconfirmed_email_count: unconfirmed_email_count
    )
    |> ok()
  end
end
