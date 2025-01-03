defmodule RMWeb.LeagueLive.Settings do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    with :ok <- require_permission(socket) do
      league = RM.Repo.preload(socket.assigns[:local_league], [users: [:profile]], force: true)

      socket
      |> add_user_form()
      |> registration_settings_form()
      |> assign(local_league: league, remove_user: nil)
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

  def handle_event("add_user_change", %{"league" => params}, socket) do
    league = socket.assigns[:local_league]
    user = socket.assigns[:current_user]

    if can?(user, :league_add_user, league) do
      socket
      |> add_user_form(params)
      |> noreply()
    else
      socket
      |> put_flash(:error, "You do not have permission to perform this action.")
      |> noreply()
    end
  end

  def handle_event("add_user_submit", %{"league" => params}, socket) do
    league = socket.assigns[:local_league]
    user = socket.assigns[:current_user]

    if can?(user, :league_add_user, league) do
      socket
      |> add_user_submit(params)
      |> noreply()
    else
      socket
      |> put_flash(:error, "You do not have permission to perform this action.")
      |> noreply()
    end
  end

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

  def handle_event("remove_user_cancel", _params, socket) do
    league = socket.assigns[:local_league]
    user = socket.assigns[:current_user]

    if can?(user, :league_add_user, league) do
      socket
      |> remove_user_cancel()
      |> noreply()
    else
      socket
      |> put_flash(:error, "You do not have permission to perform this action.")
      |> noreply()
    end
  end

  def handle_event("remove_user_init", %{"assignment" => assignment_id}, socket) do
    league = socket.assigns[:local_league]
    user = socket.assigns[:current_user]

    if can?(user, :league_add_user, league) do
      socket
      |> remove_user_init(assignment_id)
      |> noreply()
    else
      socket
      |> put_flash(:error, "You do not have permission to perform this action.")
      |> noreply()
    end
  end

  def handle_event("remove_user_submit", _params, socket) do
    league = socket.assigns[:local_league]
    user = socket.assigns[:current_user]

    if can?(user, :league_add_user, league) do
      socket
      |> remove_user_submit()
      |> noreply()
    else
      socket
      |> put_flash(:error, "You do not have permission to perform this action.")
      |> noreply()
    end
  end

  #
  # Helpers
  #

  @spec add_user_form(Socket.t()) :: Socket.t()
  @spec add_user_form(Socket.t(), map) :: Socket.t()
  defp add_user_form(socket, params \\ %{"permissions" => %{"users" => true}}) do
    league = socket.assigns[:local_league]
    form = RM.Account.League.create_changeset(league, params) |> to_form()
    assign(socket, add_user_form: form)
  end

  @spec add_user_submit(Socket.t(), map) :: Socket.t()
  defp add_user_submit(socket, params) do
    league = socket.assigns[:local_league]

    case RM.Account.add_league_user(league, params) do
      {:ok, _assignment} ->
        league = RM.Repo.preload(league, [users: [:profile]], force: true)

        socket
        |> assign(local_league: league)
        |> put_flash(:info, "League administrator added successfully")
        |> push_js("#league-add-user-modal", "data-cancel")
        |> add_user_form()

      {:error, changeset} ->
        assign(socket, add_user_form: to_form(changeset))
    end
  end

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

  @spec remove_user_cancel(Socket.t()) :: Socket.t()
  defp remove_user_cancel(socket) do
    socket
    |> assign(remove_user: nil)
    |> push_js("#league-remove-user-modal", "data-cancel")
  end

  @spec remove_user_init(Socket.t(), Ecto.UUID.t()) :: Socket.t()
  defp remove_user_init(socket, assignment_id) do
    league = socket.assigns[:local_league]

    if assignment = Enum.find(league.user_assignments, &(&1.id == assignment_id)) do
      socket
      |> assign(remove_user: assignment)
      |> push_js("#league-remove-user-modal", "data-show")
    else
      league = RM.Repo.preload(league, [users: [:profile]], force: true)

      socket
      |> assign(localleague: league)
      |> put_flash(:error, "An error occurred; please try again")
    end
  end

  @spec remove_user_submit(Socket.t()) :: Socket.t()
  defp remove_user_submit(socket) do
    assignment = socket.assigns[:remove_user]
    league = socket.assigns[:local_league]

    case RM.Repo.delete(assignment) do
      {:ok, _assignment} ->
        league = RM.Repo.preload(league, [users: [:profile]], force: true)

        socket
        |> assign(local_league: league, remove_user: nil)
        |> put_flash(:info, "League administrator removed successfully")
        |> push_js("#league-remove-user-modal", "data-cancel")

      {:error, _changeset} ->
        league = RM.Repo.preload(league, [users: [:profile]], force: true)

        socket
        |> assign(local_league: league, remove_user: nil)
        |> put_flash(:error, "An error occurred; please try again")
        |> push_js("#league-remove-user-modal", "data-cancel")
    end
  end
end
