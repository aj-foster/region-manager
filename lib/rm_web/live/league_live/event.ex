defmodule RMWeb.LeagueLive.Event do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  alias RM.FIRST.Event

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}
  on_mount {__MODULE__, :preload_event}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(registration_settings_form: nil)
    |> ok()
  end

  def on_mount(:preload_event, %{"event" => event_code}, _session, socket) do
    case RM.FIRST.fetch_event_by_code(event_code, preload: [:league, :region]) do
      {:ok, event} ->
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

  def handle_event("registration_settings_change", %{"event_settings" => params}, socket) do
    IO.inspect(params)

    socket
    |> registration_settings_change(params)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec registration_settings_change(Socket.t(), map) :: Socket.t()
  defp registration_settings_change(socket, params) do
    event = socket.assigns[:event]

    params =
      params
      |> registration_settings_normalize_team_limit()
      |> registration_settings_normalize_waitlist_limit()

    case RM.Local.update_event_settings(event, params) |> IO.inspect() do
      {:ok, _settings} ->
        socket
        |> refresh_league(events: true)
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

  @spec event_format(Event.t()) :: String.t()
  defp event_format(%Event{remote: true}), do: "Remote"
  defp event_format(%Event{hybrid: true}), do: "Hybrid"
  defp event_format(_event), do: "Traditional"

  @spec multi_day?(Event.t()) :: boolean
  defp multi_day?(%Event{date_start: start, date_end: finish}) do
    Date.diff(start, finish) != 0
  end

  @spec present?(String.t() | nil) :: boolean
  defp present?(""), do: false
  defp present?(nil), do: false
  defp present?(_else), do: true
end
