defmodule RMWeb.LeagueLive.Settings do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    with :ok <- require_permission(socket) do
      socket
      |> registration_settings_form()
      |> ok()
    end
  end

  @spec require_permission(Socket.t()) :: :ok | Socket.t()
  defp require_permission(socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    user = socket.assigns[:current_user]

    cond do
      can?(user, :league_update, league) ->
        :ok

      can?(user, :league_settings_update, league) ->
        :ok

      :else ->
        socket
        |> put_flash(:error, "You do not have permission to perform this action.")
        |> redirect(to: url_for([season, region, league]))
        |> ok()
    end
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("registration_settings_change", %{"league_settings" => params}, socket) do
    socket
    |> registration_settings_form(params)
    |> noreply()
  end

  def handle_event("registration_settings_submit", %{"league_settings" => params}, socket) do
    socket
    |> registration_settings_submit(params)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec registration_settings_form(Socket.t()) :: Socket.t()
  @spec registration_settings_form(Socket.t(), map) :: Socket.t()
  defp registration_settings_form(socket, params \\ %{}) do
    league = socket.assigns[:local_league]
    form = RM.Local.change_league_settings(league, params) |> to_form()

    assign(socket, registration_settings_form: form, registration_settings_success: false)
  end

  @spec registration_settings_submit(Socket.t(), map) :: Socket.t()
  defp registration_settings_submit(socket, params) do
    league = socket.assigns[:local_league]

    params =
      params
      |> registration_settings_normalize_team_limit()
      |> registration_settings_normalize_waitlist_limit()

    case RM.Local.update_league_settings(league, params) do
      {:ok, _settings} ->
        league = RM.Repo.preload(league, :settings, force: true)

        socket
        |> assign(local_league: league)
        |> registration_settings_form()
        |> assign(registration_settings_success: true)

      {:error, changeset} ->
        assign(socket, registration_settings_form: to_form(changeset))
    end
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
end
