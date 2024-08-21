defmodule RMWeb.LeagueLive.Venue.Index do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  #
  # Lifecycle
  #

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_venues()
    |> ok()
  end

  #
  # Helpers
  #

  @spec assign_venues(Socket.t()) :: Socket.t()
  defp assign_venues(socket) do
    league =
      socket.assigns[:league]
      |> RM.Repo.preload(:venues)

    {active_venues, archived_venues} = Enum.split_with(league.venues, &is_nil(&1.hidden_at))

    assign(socket,
      active_venues: Enum.sort_by(active_venues, & &1.name),
      active_venue_count: length(active_venues),
      archived_venues: Enum.sort_by(archived_venues, & &1.name),
      archived_venue_count: length(archived_venues)
    )
  end
end
