defmodule RMWeb.EventLive.Show do
  use RMWeb, :live_view

  alias RM.FIRST.Event

  #
  # Lifecycle
  #

  on_mount {RMWeb.Live.Util, :require_season}

  @impl true
  def mount(%{"region" => region_abbr, "event" => event_code}, _session, socket) do
    socket
    |> assign_event(region_abbr, event_code)
    |> assign_event_metadata()
    |> ok()
  end

  def on_mount(:preload_event, %{"event" => event_code}, _session, socket) do
    season = socket.assigns[:season]

    case RM.FIRST.fetch_event_by_code(season, event_code, preload: [:league, :region, :settings]) do
      {:ok, event} ->
        event = RM.Repo.preload(event, registrations: [:team])
        {:cont, assign(socket, event: event)}

      {:error, :event, :not_found} ->
        {:cont, assign(socket, event: nil)}
    end
  end

  #
  # Helpers
  #

  @spec assign_event(Socket.t(), String.t(), String.t()) :: Socket.t()
  defp assign_event(socket, region_abbr, event_code) do
    preloads = [:league, :local_league, :proposal, :settings, :venue]
    season = socket.assigns[:season]

    with {:ok, %{id: region_id} = region} <- RM.FIRST.fetch_region_by_abbreviation(region_abbr),
         {:ok, %RM.FIRST.Event{region_id: ^region_id} = event} <-
           RM.FIRST.fetch_event_by_code(season, event_code, preload: preloads) do
      event = RM.Repo.preload(event, registrations: :team) |> Map.put(:region, region)
      assign(socket, event: event, region: region, page_title: "#{event.name} • RM")
    else
      {:error, :region, :not_found} ->
        socket
        |> put_flash(:error, "Region not found")
        |> redirect(to: ~p"/")

      {:error, :event, :not_found} ->
        socket
        |> put_flash(:error, "Event not found")
        |> redirect(to: ~p"/dashboard")
    end
  end

  @spec assign_event_metadata(Socket.t()) :: Socket.t()
  defp assign_event_metadata(socket) do
    event = socket.assigns[:event]

    assign(socket,
      registered_teams:
        Enum.filter(event.registrations, &(not &1.waitlisted and not &1.rescinded))
        |> Enum.map(& &1.team)
        |> Enum.sort(RM.Local.Team),
      registration_enabled: get_in(event.settings.registration.enabled),
      registrations:
        (get_in(event.registrations) || [])
        |> Map.new(fn
          %{team: team, rescinded: true} -> {team.number, :rescinded}
          %{team: team, waitlisted: true} -> {team.number, :waitlisted}
          %{team: team} -> {team.number, :attending}
        end)
    )
  end

  #
  # Template Helpers
  #

  @spec event_league(RM.FIRST.Event.t()) :: String.t()
  defp event_league(%RM.FIRST.Event{local_league: nil}), do: "None"

  defp event_league(%RM.FIRST.Event{
         league: %RM.FIRST.League{},
         local_league: %RM.Local.League{name: name}
       }) do
    name
  end

  defp event_league(%RM.FIRST.Event{local_league: %RM.Local.League{name: name}}) do
    "#{name} (Unofficial)"
  end
end