defmodule RMWeb.EventLive.Settings do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @impl true
  def mount(%{"event" => event_code}, _session, socket) do
    socket
    |> assign_event(event_code)
    |> require_permission()
    |> registration_settings_form()
    |> ok()
  end

  @spec require_permission(Socket.t()) :: Socket.t()
  defp require_permission(socket) do
    event = socket.assigns[:event]
    user = socket.assigns[:current_user]

    if can?(user, :registration_settings_update, event) do
      socket
    else
      socket
      |> put_flash(:error, "You are not authorized to perform this action")
      |> redirect(to: ~p"/")
    end
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("registration_settings_change", %{"event_settings" => params}, socket) do
    event = socket.assigns[:event]

    with :ok <- require_noreply(socket, :registration_settings_update, event) do
      socket
      |> registration_settings_change(params)
      |> noreply()
    end
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
            RM.Repo.preload(event, proposal: :attachments, registrations: :team)
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

  @spec safe_subtract_date(Date.t(), integer | String.t()) :: String.t()
  defp safe_subtract_date(date, days_to_subtract) do
    case days_to_subtract do
      x when is_integer(x) ->
        Date.add(date, -1 * x) |> format_date(:date)

      x when is_binary(x) ->
        case Integer.parse(x) do
          {x, ""} -> Date.add(date, -1 * x) |> format_date(:date)
          _else -> "(?)"
        end

      _else ->
        "(?)"
    end
  end
end
