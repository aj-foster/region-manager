defmodule RMWeb.TeamLive.Event do
  use RMWeb, :live_view
  import RMWeb.TeamLive.Util

  alias RM.FIRST.Event

  on_mount {RMWeb.TeamLive.Util, :preload_team}
  on_mount {RMWeb.TeamLive.Util, :require_team_manager}
  on_mount {__MODULE__, :preload_event}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(registration_form: nil)
    |> ok()
  end

  def on_mount(:preload_event, %{"event" => event_code}, _session, socket) do
    case RM.FIRST.fetch_event_by_code(event_code, preload: [:league, :region]) do
      {:ok, event} ->
        {:cont, assign(socket, event: event)}

      {:error, :event, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Event not found")
          |> redirect(to: ~p"/dashboard")

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

  # @impl true
  # def handle_event(event, unsigned_params, socket)
end
