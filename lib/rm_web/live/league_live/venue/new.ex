defmodule RMWeb.LeagueLive.Venue.New do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util
  import RMWeb.LeagueLive.Venue.Components

  alias RM.Local.Venue

  #
  # Lifecycle
  #

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, {:require_league_manager, :events}}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_venue_form()
    |> assign(page_title: "Create Venue")
    |> ok()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("venue_cancel", _params, socket) do
    league = socket.assigns[:league]

    socket
    |> push_navigate(to: ~p"/league/#{league.region}/#{league}/venues")
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
    league = socket.assigns[:league]

    params =
      params
      |> Map.put("by", socket.assigns[:current_user])
      |> Map.put_new("country", league.region.metadata.default_country)
      |> Map.put_new("state_province", league.region.metadata.default_state_province)
      |> Map.put_new("timezone", socket.assigns[:timezone])

    form = Venue.create_changeset(league, params) |> to_form()

    assign(socket, venue_form: form)
  end

  @spec venue_submit(Socket.t(), map) :: Socket.t()
  defp venue_submit(socket, params) do
    league = socket.assigns[:league]
    params = Map.put(params, "by", socket.assigns[:current_user])

    case RM.Local.create_venue(league, params) do
      {:ok, _venue} ->
        socket
        |> put_flash(:info, "Venue added successfully")
        |> push_navigate(to: ~p"/league/#{league.region}/#{league}/venues")

      {:error, changeset} ->
        assign(socket, venue_form: to_form(changeset))
    end
  end
end
