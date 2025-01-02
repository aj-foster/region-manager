defmodule RMWeb.EventLive.Index do
  use RMWeb, :live_view
  require Logger

  alias Phoenix.LiveView.AsyncResult

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
    |> assign_refresh_disabled()
    |> assign(grouped_events: [], sort: "", refresh_events: AsyncResult.ok(nil))
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

  def handle_event("refresh_events", _params, socket) do
    region = socket.assigns[:region]
    user = socket.assigns[:current_user]

    if can?(user, :event_sync, region) do
      socket
      |> start_async(:refresh_events, fn -> RM.FIRST.refresh_events(region) end)
      |> assign(refresh_events: AsyncResult.loading())
      |> noreply()
    else
      socket
      |> put_flash(:error, "You do not have permission to refresh events.")
      |> noreply()
    end
  end

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

  @doc false
  @impl true
  def handle_async(name, async_fun_result, socket)

  def handle_async(:refresh_events, {:ok, {:ok, _events}}, socket) do
    socket
    |> assign(refresh_events: AsyncResult.ok(true))
    |> refresh_region()
    |> assign_events()
    |> assign_refresh_disabled()
    |> noreply()
  end

  def handle_async(:refresh_events, {:ok, {:error, reason}}, socket) do
    Logger.error("Error while refreshing events: #{inspect(reason)}")

    socket
    |> assign(refresh_events: AsyncResult.ok(false))
    |> put_flash(:error, "An error occurred while refreshing events. Please try again later.")
    |> noreply()
  end

  def handle_async(:refresh_events_disabled, {:ok, :done}, socket) do
    socket
    |> assign(refresh_events_disabled: false)
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

    page_title =
      cond do
        local_league -> "#{local_league.name} Events in #{season}–#{season + 1}"
        first_league -> "#{first_league.name} Events in #{season}–#{season + 1}"
        :else -> "#{region.name} Events in #{season}–#{season + 1}"
      end

    assign(socket, events: events, page_title: page_title)
  end

  @spec assign_refresh_disabled(Socket.t()) :: Socket.t()
  defp assign_refresh_disabled(socket) do
    %RM.FIRST.Region{stats: %{events_imported_at: last_refresh}} = socket.assigns[:region]

    if not is_nil(last_refresh) and
         DateTime.after?(last_refresh, DateTime.add(DateTime.utc_now(), -10, :minute)) do
      time_until_enabled_ms =
        DateTime.add(last_refresh, 10, :minute)
        |> DateTime.diff(DateTime.utc_now(), :millisecond)

      socket
      |> assign(refresh_events_disabled: true)
      |> start_async(:refresh_events_disabled, fn ->
        Process.sleep(time_until_enabled_ms)
        :done
      end)
    else
      assign(socket, refresh_events_disabled: false)
    end
  end

  @spec group_by_league(Socket.t()) :: Socket.t()
  defp group_by_league(socket) do
    events = socket.assigns[:events]

    grouped_events =
      Enum.group_by(events, fn event ->
        cond do
          event.local_league -> {1, event.local_league.name <> " League"}
          event.league -> {1, event.league.name <> " League"}
          :else -> {0, ""}
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
          {0, ""}
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

  @spec refresh_region(Socket.t()) :: Socket.t()
  defp refresh_region(socket) do
    region =
      socket.assigns[:region]
      |> RM.Repo.reload!()

    assign(socket, region: region)
  end

  #
  # Template Helpers
  #

  @spec events_page_title(
          RM.Local.League.t() | nil,
          RM.FIRST.League.t() | nil,
          RM.FIRST.Region.t()
        ) :: String.t()
  defp events_page_title(local_league, first_league, region)
  defp events_page_title(%RM.Local.League{name: name}, _, _), do: name <> " League"
  defp events_page_title(_, %RM.FIRST.League{name: name}, _), do: name <> " League"
  defp events_page_title(_, _, %RM.FIRST.Region{name: name}), do: name
end
