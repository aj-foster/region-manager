defmodule RMWeb.LeagueLive.Proposal do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}
  on_mount {__MODULE__, :preload_proposal}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(registration_settings_form: nil)
    |> ok()
  end

  def on_mount(:preload_proposal, %{"event" => id}, _session, socket) do
    league = socket.assigns[:league]

    case RM.Local.fetch_event_proposal_by_id(id, league: league, preload: [:event, :venue]) do
      {:ok, event} ->
        {:cont, assign(socket, event: event)}

      {:error, :proposal, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Event proposal not found")
          |> redirect(to: ~p"/league/#{league.region}/#{league}/events")

        {:halt, socket}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket
    |> noreply()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("nothing yet", %{"event_settings" => _params}, socket) do
    socket
    |> noreply()
  end

  #
  # Helpers
  #
end
