defmodule RMWeb.LeagueLive.Propose do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  alias RM.Local.Venue

  #
  # Lifecycle
  #

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket
    |> add_venue_form()
    |> load_venues()
    |> noreply()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("add_venue_change", %{"venue" => params}, socket) do
    socket
    |> add_venue_form(params)
    |> noreply()
  end

  def handle_event("add_venue_submit", %{"venue" => params}, socket) do
    socket
    |> add_venue_submit(params)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec add_venue_form(Socket.t()) :: Socket.t()
  @spec add_venue_form(Socket.t(), map) :: Socket.t()
  defp add_venue_form(socket, params \\ %{}) do
    league = socket.assigns[:league]
    params = Map.put(params, "by", socket.assigns[:current_user])
    form = Venue.create_changeset(league, params) |> to_form()

    assign(socket, add_venue_form: form)
  end

  @spec add_venue_submit(Socket.t(), map) :: Socket.t()
  defp add_venue_submit(socket, params) do
    league = socket.assigns[:league]
    params = Map.put(params, "by", socket.assigns[:current_user])

    case RM.Local.create_venue(league, params) do
      {:ok, _venue} ->
        socket
        |> push_js("#add-venue-modal", "data-cancel")
        |> put_flash(:info, "Venue added successfully")
        |> load_venues()

      {:error, changeset} ->
        assign(socket, add_venue_form: to_form(changeset))
    end
  end

  #
  # Template Helpers
  #

  @spec venue_options([Venue.t()]) :: [{String.t(), Ecto.UUID.t()}]
  defp venue_options(venues) do
    for %Venue{id: id, name: name} <- venues do
      {name, id}
    end
  end
end
