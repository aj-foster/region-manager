defmodule RMWeb.LeagueLive.Event.Show do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  alias RM.FIRST.Event

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}
  on_mount {__MODULE__, :preload_event}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_event_metadata()
    |> assign(edit_registration: false, registration_settings_form: nil)
    |> registration_settings_form()
    |> ok()
  end

  def on_mount(:preload_event, %{"event" => event_code}, _session, socket) do
    league = socket.assigns[:league]
    preloads = [:league, :local_league, :proposal, :region, :settings, :venue]
    league_id = league.id

    case RM.FIRST.fetch_event_by_code(league.region.current_season, event_code, preload: preloads) do
      {:ok, %RM.FIRST.Event{local_league_id: ^league_id} = event} ->
        event = RM.Repo.preload(event, proposal: [:attachments])
        {:cont, assign(socket, event: event, page_title: event.name)}

      {:error, :event, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Event not found")
          |> redirect(to: ~p"/dashboard")

        {:halt, socket}
    end
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("edit_registration_init", _params, socket) do
    socket
    |> assign(edit_registration: not socket.assigns[:edit_registration])
    |> registration_settings_form()
    |> noreply()
  end

  def handle_event("event_virtual_toggle", _params, socket) do
    socket = push_js(socket, "#event-virtual-modal", "data-cancel")

    with :ok <- require_permission(socket, :events) do
      socket
      |> event_virtual_toggle()
      |> noreply()
    end
  end

  def handle_event("registration_settings_change", %{"event_settings" => params}, socket) do
    socket
    |> registration_settings_change(params)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_event_metadata(Socket.t()) :: Socket.t()
  defp assign_event_metadata(socket) do
    event =
      socket.assigns[:event]
      |> RM.Repo.preload(registrations: :team)

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

  @spec event_virtual_toggle(Socket.t()) :: Socket.t()
  defp event_virtual_toggle(socket) do
    event = socket.assigns[:event]
    params = %{virtual: not event.settings.virtual}

    case RM.Local.update_event_settings(event, params) do
      {:ok, settings} ->
        event = %{event | settings: settings}

        socket
        |> assign(event: event)
        |> put_flash(:info, "Event modified successfully")

      {:error, _changeset} ->
        put_flash(socket, :error, "Error while changing virtual status, please try again")
    end
  end

  @spec refresh_event_settings(Socket.t()) :: Socket.t()
  defp refresh_event_settings(socket) do
    event =
      socket.assigns[:event]
      |> RM.Repo.preload(:settings, force: true)

    assign(socket, event: event)
  end

  @spec registration_settings_change(Socket.t(), map) :: Socket.t()
  defp registration_settings_change(socket, params) do
    event = socket.assigns[:event]

    params =
      params
      |> registration_settings_normalize_team_limit()
      |> registration_settings_normalize_waitlist_limit()

    case RM.Local.update_event_settings(event, params) do
      {:ok, _settings} ->
        socket
        |> refresh_event_settings()
        |> registration_settings_form()

      {:error, changeset} ->
        assign(socket, registration_settings_form: to_form(changeset))
    end
  end

  @spec registration_settings_form(Socket.t()) :: Socket.t()
  defp registration_settings_form(socket) do
    event = socket.assigns[:event]
    form = RM.Local.change_event_settings(event) |> to_form()

    assign(socket, registration_settings_form: form)
  end

  @spec registration_settings_normalize_team_limit(map) :: map
  defp registration_settings_normalize_team_limit(
         %{"registration" => %{"team_limit_enable" => "true"}} = params
       ) do
    put_in(params, ["registration", "team_limit"], params["registration"]["team_limit"] || "50")
  end

  defp registration_settings_normalize_team_limit(params) do
    put_in(params, ["registration", "team_limit"], nil)
  end

  @spec registration_settings_normalize_waitlist_limit(map) :: map
  defp registration_settings_normalize_waitlist_limit(
         %{"registration" => %{"waitlist_limit_enable" => "true"}} = params
       ) do
    params
    |> put_in(
      ["registration", "waitlist_limit"],
      params["registration"]["waitlist_limit"] || "50"
    )
    |> put_in(
      ["registration", "waitlist_deadline_days"],
      params["registration"]["waitlist_deadline_days"] || "7"
    )
  end

  defp registration_settings_normalize_waitlist_limit(params) do
    put_in(params, ["registration", "waitlist_limit"], nil)
  end

  #
  # Template Helpers
  #

  @spec event_league(RM.FIRST.Event.t()) :: String.t()
  defp event_league(%RM.FIRST.Event{
         league: %RM.FIRST.League{},
         local_league: %RM.Local.League{name: name}
       }) do
    name
  end

  defp event_league(%RM.FIRST.Event{local_league: %RM.Local.League{name: name}}) do
    "#{name} (Unofficial)"
  end

  @spec registration_pool_options(RM.FIRST.Event.t()) :: [{String.t(), String.t()}]
  defp registration_pool_options(%RM.FIRST.Event{league: %_{} = league, region: region}) do
    [
      {"Teams in #{league.name} League", "league"},
      {"Teams in #{region.name}", "region"},
      {"Any Team", "all"}
    ]
  end

  defp registration_pool_options(%RM.FIRST.Event{local_league: %_{} = league, region: region}) do
    [
      {"Teams in #{league.name} League", "league"},
      {"Teams in #{region.name}", "region"},
      {"Any Team", "all"}
    ]
  end

  defp registration_pool_options(%RM.FIRST.Event{region: region}) do
    [
      {"Teams in #{region.name}", "region"},
      {"Any Team", "all"}
    ]
  end
end
