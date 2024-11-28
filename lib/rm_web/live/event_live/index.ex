defmodule RMWeb.EventLive.Index do
  use RMWeb, :live_view

  @typedoc "Key used for sorting groups of events"
  @type group_key :: {priority :: integer, title :: String.t()}

  #
  # Lifecycle
  #

  on_mount {RMWeb.Live.Util, :check_season}
  on_mount {RMWeb.Live.Util, :check_region}
  on_mount {RMWeb.Live.Util, :check_league}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_events()
    |> assign(grouped_events: [], sort: "")
    |> assign_new(:first_league, fn -> nil end)
    |> assign_new(:local_league, fn -> nil end)
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

  @spec assign_events(Socket.t()) :: Socket.t()
  defp assign_events(socket) do
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    first_league = socket.assigns[:first_league]
    local_league = socket.assigns[:local_league]
    preloads = [:league, :local_league, :proposal, :settings, :venue]

    events =
      RM.FIRST.list_events_by_region(region,
        league: first_league,
        local_league: local_league,
        season: season,
        preload: preloads
      )
      |> RM.Repo.preload(registrations: [:team])

    page_title =
      cond do
        local_league -> "#{local_league.name} Events #{season}–#{season + 1}"
        first_league -> "#{first_league.name} Events #{season}–#{season + 1}"
        :else -> "#{region.name} Events #{season}–#{season + 1}"
      end

    assign(socket, events: events, page_title: page_title)
  end

  @spec group_by_league(Socket.t()) :: Socket.t()
  defp group_by_league(socket) do
    events = socket.assigns[:events]
    region = socket.assigns[:region]

    grouped_events =
      Enum.group_by(events, fn event ->
        cond do
          event.local_league -> {1, event.local_league.name <> " League"}
          event.league -> {1, event.league.name <> " League"}
          :else -> {0, region.name}
        end
      end)
      |> Enum.map(fn {key, event_list} ->
        {key, Enum.sort(event_list, RM.FIRST.Event)}
      end)
      |> Enum.sort_by(fn {key, _event_list} -> key end)

    assign(socket,
      event_group_count: length(grouped_events),
      grouped_events: grouped_events,
      sort: "league"
    )
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

    assign(socket,
      event_group_count: length(grouped_events),
      grouped_events: grouped_events,
      sort: "upcoming"
    )
  end

  #
  # Template Helpers
  #

  defp events_page_title(local_league, first_league, region)
  defp events_page_title(%RM.Local.League{name: name}, _, _), do: name <> " League"
  defp events_page_title(_, %RM.FIRST.League{name: name}, _), do: name <> " League"
  defp events_page_title(_, _, %RM.FIRST.Region{name: name}), do: name
end
