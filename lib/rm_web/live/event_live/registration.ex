defmodule RMWeb.EventLive.Registration do
  use RMWeb, :live_view

  alias RM.FIRST.Event

  #
  # Lifecycle
  #

  @impl true
  def mount(%{"event" => event_code}, _session, socket) do
    socket
    |> assign_event(event_code)
    |> assign_event_metadata()
    |> assign_teams()
    |> ok()
  end

  #
  # Helpers
  #

  @spec assign_event(Socket.t(), String.t()) :: Socket.t()
  defp assign_event(socket, event_code) do
    preloads = [:league, :local_league, :proposal, :settings, :venue]
    region = socket.assigns[:region]
    season = socket.assigns[:season]

    case RM.FIRST.fetch_event_by_code(season, event_code, preload: preloads) do
      {:ok, event} ->
        if event.region_id == region.id do
          event =
            RM.Repo.preload(event,
              proposal: :attachments,
              registrations: [team: [:league, :region]]
            )
            |> Map.put(:region, region)

          assign(socket, event: event, page_title: event.name)
        else
          socket
          |> put_flash(:error, "Event not found")
          |> redirect(to: ~p"/dashboard")
        end

      {:error, :event, :not_found} ->
        socket
        |> put_flash(:error, "Event not found")
        |> redirect(to: ~p"/dashboard")
    end
  end

  @spec assign_event_metadata(Socket.t()) :: Socket.t()
  defp assign_event_metadata(socket) do
    event = socket.assigns[:event]

    registered_teams =
      Enum.filter(event.registrations, &(not &1.waitlisted and not &1.rescinded))
      |> Enum.map(& &1.team)
      |> Enum.sort(RM.Local.Team)

    assign(socket,
      registered_teams: registered_teams,
      registered_teams_count: length(registered_teams),
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

  @spec assign_teams(Socket.t()) :: Socket.t()
  defp assign_teams(socket) do
    event = socket.assigns[:event]
    user = socket.assigns[:current_user]
    registrations = socket.assigns[:registrations]

    if user do
      teams =
        user.teams
        |> Enum.filter(& &1.active)
        |> Enum.map(&%{team: &1})
        |> Enum.map(fn %{team: team} = info ->
          case RM.Local.verify_eligibility(event, team) do
            :ok ->
              Map.merge(info, %{eligible?: true, event_ready?: team.event_ready})

            {:error, reason} ->
              Map.merge(info, %{eligible?: false, reason: reason})
          end
        end)
        |> Enum.map(fn %{team: team} = info ->
          case registrations[team.number] do
            nil -> Map.merge(info, %{status: :unregistered})
            status -> Map.merge(info, %{status: status})
          end
        end)

      assign(socket, teams: teams, teams_count: length(teams))
    else
      assign(socket, teams: [], teams_count: 0)
    end
  end
end
