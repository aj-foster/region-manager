defmodule RMWeb.RegionLive.Event.Show do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  alias RM.FIRST.Event

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}
  on_mount {__MODULE__, :preload_event}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(registration_settings_form: nil)
    |> ok()
  end

  def on_mount(:preload_event, %{"event" => event_code}, _session, socket) do
    region = socket.assigns[:region]
    preloads = [:league, :local_league, :proposal, :region, :settings, :venue]
    region_id = region.id

    case RM.FIRST.fetch_event_by_code(region.current_season, event_code, preload: preloads) do
      {:ok, %RM.FIRST.Event{region_id: ^region_id} = event} ->
        event = RM.Repo.preload(event, proposal: [:league])
        {:cont, assign(socket, event: event)}

      {:error, :event, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Event not found")
          |> redirect(to: ~p"/dashboard")

        {:halt, socket}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket
    |> registration_settings_form()
    |> noreply()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("event_virtual_toggle", _params, socket) do
    socket
    |> event_virtual_toggle()
    |> push_js("#event-virtual-modal", "data-cancel")
    |> noreply()
  end

  def handle_event("registration_settings_change", %{"event_settings" => params}, socket) do
    socket
    |> registration_settings_change(params)
    |> noreply()
  end

  #
  # Helpers
  #

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

  @spec event_proposal_league(RM.Local.EventProposal.t() | nil) :: String.t()
  defp event_proposal_league(nil), do: "None"
  defp event_proposal_league(%RM.Local.EventProposal{league: nil}), do: "None"

  defp event_proposal_league(%RM.Local.EventProposal{league: %RM.Local.League{name: name}}) do
    name
  end
end
