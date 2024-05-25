defmodule RMWeb.LeagueLive.Events do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(registration_settings_form: nil)
    |> ok()
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket
    |> load_events()
    |> registration_settings_form()
    |> noreply()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("registration_settings_change", %{"league_settings" => params}, socket) do
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
    league = socket.assigns[:league]

    case RM.Local.update_league_settings(league, params) |> IO.inspect() do
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
    league = socket.assigns[:league]
    form = RM.Local.change_league_settings(league) |> to_form()

    assign(socket, registration_settings_form: form)
  end
end