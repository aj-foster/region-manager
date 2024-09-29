defmodule RMWeb.LeagueLive.Venue.Edit do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util
  import RMWeb.LeagueLive.Venue.Components

  alias RM.FIRST.Event
  alias RM.Local.EventProposal
  alias RM.Local.Venue

  #
  # Lifecycle
  #

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, {:require_league_manager, :events}}
  on_mount {__MODULE__, :preload_venue}

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_venue_form()
    |> ok()
  end

  def on_mount(:preload_venue, %{"venue" => id}, _session, socket) do
    league = socket.assigns[:league]

    case RM.Local.fetch_venue_by_id(id, league: league, preload: [:event_proposals]) do
      {:ok, venue} ->
        proposals =
          venue.event_proposals
          |> Enum.filter(&(&1.season == league.region.current_season))
          |> Enum.sort(RM.Local.EventProposal)

        {:cont,
         assign(socket,
           proposals: proposals,
           proposal_count: length(proposals),
           venue: venue,
           page_title: "Update Venue"
         )}

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

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("venue_cancel", _params, socket) do
    league = socket.assigns[:league]
    venue = socket.assigns[:venue]

    socket
    |> push_navigate(to: ~p"/league/#{league.region}/#{league}/venues/#{venue}")
    |> noreply()
  end

  def handle_event("venue_change", %{"venue" => params}, socket) do
    socket
    |> assign_venue_form(params)
    |> noreply()
  end

  def handle_event("venue_submit", %{"venue" => params}, socket) do
    socket
    |> venue_submit(params)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_venue_form(Socket.t()) :: Socket.t()
  @spec assign_venue_form(Socket.t(), map) :: Socket.t()
  defp assign_venue_form(socket, params \\ %{}) do
    venue = socket.assigns[:venue]
    params = Map.put(params, "by", socket.assigns[:current_user])
    form = Venue.update_changeset(venue, params) |> to_form()

    assign(socket, venue_form: form)
  end

  @spec venue_submit(Socket.t(), map) :: Socket.t()
  defp venue_submit(socket, params) do
    league = socket.assigns[:league]
    venue = socket.assigns[:venue]
    params = Map.put(params, "by", socket.assigns[:current_user])

    case RM.Local.update_venue(venue, params) do
      {:ok, _venue} ->
        socket
        |> put_flash(:info, "Venue updated successfully")
        |> push_navigate(to: ~p"/league/#{league.region}/#{league}/venues")

      {:error, changeset} ->
        assign(socket, venue_form: to_form(changeset))
    end
  end
end
