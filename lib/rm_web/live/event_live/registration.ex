defmodule RMWeb.EventLive.Registration do
  use RMWeb, :live_view
  require Logger

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
    |> assign(edit_registration: nil)
    |> ok()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("edit_registration_init", %{"team" => team_number_str}, socket) do
    socket
    |> edit_registration_init(team_number_str)
    |> noreply()
  end

  def handle_event("rescind_submit", _params, socket) do
    socket
    |> push_js("#team-registration-change", "data-cancel")
    |> rescind_submit()
    |> refresh_registrations()
    |> noreply()
  end

  def handle_event("team_registration_submit", _params, socket) do
    socket
    |> push_js("#team-registration-confirm", "data-cancel")
    |> register_teams()
    |> refresh_registrations()
    |> noreply()
  end

  def handle_event("team_select_change", %{"team-registration-select" => params}, socket) do
    socket
    |> select_teams(params)
    |> noreply()
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

      assign(socket, selected: [], selected_count: 0, teams: teams, teams_count: length(teams))
    else
      assign(socket, selected: [], selected_count: 0, teams: [], teams_count: 0)
    end
  end

  @spec edit_registration_init(Socket.t(), String.t()) :: Socket.t()
  defp edit_registration_init(socket, team_number_str) do
    registrations = socket.assigns[:event].registrations
    teams = socket.assigns[:teams]

    with {number, ""} <- Integer.parse(team_number_str),
         %{team: %RM.Local.Team{id: team_id}} <- Enum.find(teams, &(&1.team.number == number)),
         %RM.Local.EventRegistration{} = r <- Enum.find(registrations, &(&1.team.id == team_id)) do
      socket
      |> assign(edit_registration: r)
      |> push_js("#team-registration-change", "data-show")
    else
      _ ->
        put_flash(socket, :error, "An error occurred while changing registration")
    end
  end

  @spec refresh_registrations(Socket.t()) :: Socket.t()
  defp refresh_registrations(socket) do
    event =
      socket.assigns[:event]
      |> RM.Repo.preload([registrations: [team: [:league, :region]]], force: true)

    socket
    |> assign(event: event)
    |> assign_event_metadata()
    |> assign_teams()
  end

  @spec register_teams(Socket.t()) :: Socket.t()
  defp register_teams(socket) do
    event = socket.assigns[:event]
    teams = Enum.map(socket.assigns[:selected], & &1.team)
    user = socket.assigns[:current_user]

    registrations =
      RM.Local.create_event_registrations(event, teams, %{by: user, waitlisted: false})

    if length(registrations) == length(teams) do
      put_flash(socket, :info, "#{dumb_inflect("team", registrations)} registered successfully")
    else
      put_flash(socket, :error, "Not all teams were successfully registered; please try again")
    end
  end

  @spec rescind_submit(Socket.t()) :: Socket.t()
  defp rescind_submit(socket) do
    registration = socket.assigns[:edit_registration]
    user = socket.assigns[:current_user]

    case RM.Local.rescind_event_registration(registration, %{by: user}) do
      {:ok, _registration} ->
        put_flash(socket, :info, "Registration rescinded")

      {:error, changeset} ->
        Logger.error("Failed to rescind registration for event: #{inspect(changeset)}")
        put_flash(socket, :error, "An error occurred; please contact support")
    end
  end

  @spec select_teams(Socket.t(), map) :: Socket.t()
  defp select_teams(socket, params) do
    team_numbers =
      params
      |> Enum.filter(fn {_team_number, value} -> value in ["true", true] end)
      |> Enum.map(fn {team_number, _value} ->
        case Integer.parse(team_number) do
          {number, ""} -> number
          :error -> nil
        end
      end)

    selected_teams =
      socket.assigns[:teams]
      |> Enum.filter(& &1.eligible?)
      |> Enum.filter(&(&1.status == :unregistered))
      |> Enum.filter(&(&1.team.number in team_numbers))

    assign(socket, selected: selected_teams, selected_count: length(selected_teams))
  end
end
