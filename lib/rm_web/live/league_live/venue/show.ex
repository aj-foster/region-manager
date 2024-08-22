defmodule RMWeb.LeagueLive.Venue.Show do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  #
  # Lifecycle
  #

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}
  on_mount {__MODULE__, :preload_venue}

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  def on_mount(:preload_venue, %{"venue" => id}, _session, socket) do
    league = socket.assigns[:league]

    case RM.Local.fetch_venue_by_id(id, league: league, preload: [:event_proposals]) do
      {:ok, venue} ->
        {:cont, assign(socket, venue: venue)}

      {:error, :venue, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Venue not found")
          |> redirect(to: ~p"/league/#{league.region}/#{league}/venues")

        {:halt, socket}
    end
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("archive_change", _params, socket) do
    socket
    |> toggle_archive()
    |> noreply()
  end

  #
  # Helpers
  #

  @spec toggle_archive(Socket.t()) :: Socket.t()
  defp toggle_archive(socket) do
    user = socket.assigns[:current_user]
    venue = socket.assigns[:venue]
    new_archived? = is_nil(venue.hidden_at)

    case RM.Local.update_venue_archive_status(venue, new_archived?, by: user) do
      {:ok, new_venue} ->
        venue = %{new_venue | event_proposals: venue.event_proposals}

        socket
        |> assign(venue: venue)
        |> put_flash(:info, "Archive status updated")

      {:error, _changeset} ->
        put_flash(socket, :error, "An error occurred while updating archive status")
    end
  end
end
