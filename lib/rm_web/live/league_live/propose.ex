defmodule RMWeb.LeagueLive.Propose do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  alias RM.Local.Venue

  @season 2024

  #
  # Lifecycle
  #

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(venue: nil)
    |> ok()
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket
    |> add_venue_form()
    |> event_form()
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

  def handle_event("event_change", %{"event_proposal" => params}, socket) do
    socket
    |> event_form(params)
    |> noreply()
  end

  def handle_event("event_submit", %{"event_proposal" => params}, socket) do
    socket
    |> event_submit(params)
    |> noreply()
  end

  def handle_event("venue_change", %{"venue" => venue_id}, socket) do
    socket
    |> venue_change(venue_id)
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

  @spec event_form(Socket.t()) :: Socket.t()
  @spec event_form(Socket.t(), map) :: Socket.t()
  defp event_form(socket, params \\ %{}) do
    params =
      params
      |> Map.put("by", socket.assigns[:current_user])
      |> Map.put("league", socket.assigns[:league])
      |> Map.put("region", socket.assigns[:region])
      |> Map.put("season", @season)
      |> Map.put("venue", socket.assigns[:venue])

    form =
      params
      |> RM.Local.EventProposal.create_changeset()
      |> to_form()

    assign(socket, event_form: form)
  end

  @spec event_submit(Socket.t(), map) :: Socket.t()
  def event_submit(socket, params) do
    league = socket.assigns[:league]

    params =
      params
      |> Map.put("by", socket.assigns[:current_user])
      |> Map.put("league", league)
      |> Map.put("region", socket.assigns[:region])
      |> Map.put("season", @season)
      |> Map.put("venue", socket.assigns[:venue])

    case RM.Local.create_event(params) do
      {:ok, _proposal} ->
        socket
        |> put_flash(:info, "Event proposal created successfully")
        |> push_navigate(to: ~p"/league/#{league}/events")

      {:error, changeset} ->
        assign(socket, event_form: to_form(changeset) |> IO.inspect())
    end
  end

  @spec venue_change(Socket.t(), Ecto.UUID.t() | String.t()) :: Socket.t()
  defp venue_change(socket, venue_id) do
    league = socket.assigns[:league]

    if venue = Enum.find(league.venues, &(&1.id == venue_id)) do
      assign(socket, venue: venue)
    else
      assign(socket, venue: nil)
    end
  end

  #
  # Template Helpers
  #

  @spec event_format_options :: [{String.t(), String.t()}]
  defp event_format_options do
    [
      {"Traditional", "traditional"},
      {"Hybrid", "hybrid"},
      {"Remote", "remote"}
    ]
  end

  @spec event_type_options :: [{String.t(), String.t()}]
  defp event_type_options do
    [
      :kickoff,
      :scrimmage,
      :league_meet,
      :league_tournament,
      :off_season,
      :workshop,
      :demo
    ]
    |> Enum.map(fn type ->
      {RM.FIRST.Event.type_name(type), to_string(type)}
    end)
  end

  @spec venue_options([Venue.t()]) :: [{String.t(), Ecto.UUID.t()}]
  defp venue_options(venues) do
    for %Venue{id: id, name: name} <- venues do
      {name, id}
    end
  end
end
