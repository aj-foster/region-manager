defmodule RMWeb.EventLive.Index do
  use RMWeb, :live_view

  @typedoc "Key used for sorting groups of events"
  @type group_key :: {priority :: integer, title :: String.t()}

  #
  # Lifecycle
  #

  on_mount {RMWeb.Live.Util, :require_season}

  @impl true
  def mount(%{"region" => region_abbr}, _session, socket) do
    socket
    |> assign_events(region_abbr)
    |> assign(grouped_events: [], sort: "")
    |> ok()
  end

  @impl true
  def handle_params(params, _uri, socket) do
    region = socket.assigns[:region]

    case params["sort"] do
      "upcoming" ->
        group_by_upcoming(socket)

      _else ->
        if region.has_leagues do
          group_by_league(socket)
        else
          group_by_upcoming(socket)
        end
    end
    |> noreply()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("sort_league", _params, socket) do
    socket
    |> push_query(sort: "league")
    |> noreply()
  end

  def handle_event("sort_upcoming", _params, socket) do
    socket
    |> push_query(sort: "upcoming")
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_events(Socket.t(), String.t()) :: Socket.t()
  defp assign_events(socket, region_abbr) do
    preloads = [:league, :local_league, :proposal, :settings, :venue]
    season = socket.assigns[:season]

    case RM.FIRST.fetch_region_by_abbreviation(region_abbr) do
      {:ok, region} ->
        events =
          RM.FIRST.list_events_by_region(region, season: season, preload: preloads)
          |> RM.Repo.preload(registrations: [:team])

        assign(socket, events: events, region: region)

      {:error, :region, :not_found} ->
        socket
        |> put_flash(:error, "Region not found")
        |> redirect(to: ~p"/")
    end
  end

  @spec group_by_league(Socket.t()) :: Socket.t()
  defp group_by_league(socket) do
    events = socket.assigns[:events]
    region = socket.assigns[:region]

    grouped_events =
      Enum.group_by(events, fn event ->
        if event.local_league do
          {1, event.local_league.name}
        else
          {0, region.name}
        end
      end)
      |> Enum.map(fn {key, event_list} ->
        {key, Enum.sort(event_list, RM.FIRST.Event)}
      end)
      |> Enum.sort_by(fn {key, _event_list} -> key end)

    assign(socket, grouped_events: grouped_events, sort: "league")
  end

  @spec group_by_upcoming(Socket.t()) :: Socket.t()
  defp group_by_upcoming(socket) do
    events = socket.assigns[:events]

    grouped_events =
      Enum.group_by(events, fn event ->
        if RM.FIRST.Event.event_passed?(event) do
          {1, "Past Events"}
        else
          {0, "Upcoming Events"}
        end
      end)
      |> Enum.map(fn {key, event_list} ->
        {key, Enum.sort(event_list, RM.FIRST.Event)}
      end)
      |> Enum.sort_by(fn {key, _event_list} -> key end)

    assign(socket, grouped_events: grouped_events, sort: "upcoming")
  end
end
