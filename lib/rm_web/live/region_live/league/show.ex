defmodule RMWeb.RegionLive.League.Show do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  alias RM.Local.League

  #
  # Lifecycle
  #

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}
  on_mount {__MODULE__, :preload_league}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(edit_league: false, remove_user: nil)
    |> assign_first_league()
    |> assign_teams()
    |> add_user_form()
    |> edit_league_form()
    |> ok()
  end

  def on_mount(:preload_league, %{"league" => league_code}, _session, socket) do
    region = socket.assigns[:region]

    case RM.Local.fetch_league_by_code(region.abbreviation, league_code, preload: [:region]) do
      {:ok, league} ->
        league = preload_league_associations(league)
        {:cont, assign(socket, league: league, page_title: "#{league.name} League")}

      {:error, :league, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "League not found")
          |> redirect(to: ~p"/dashboard")

        {:halt, socket}
    end
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("add_user_change", %{"league" => params}, socket) do
    socket
    |> add_user_form(params)
    |> noreply()
  end

  def handle_event("add_user_submit", %{"league" => params}, socket) do
    socket
    |> add_user_submit(params)
    |> noreply()
  end

  def handle_event("edit_league_change", %{"league" => params}, socket) do
    socket
    |> edit_league_form(params)
    |> noreply()
  end

  def handle_event("edit_league_init", _params, socket) do
    socket
    |> assign(edit_league: not socket.assigns[:edit_league])
    |> edit_league_form()
    |> noreply()
  end

  def handle_event("edit_league_submit", %{"league" => params}, socket) do
    socket
    |> edit_league_submit(params)
    |> noreply()
  end

  def handle_event("remove_user_cancel", _params, socket) do
    socket
    |> remove_user_cancel()
    |> noreply()
  end

  def handle_event("remove_user_init", %{"assignment" => assignment_id}, socket) do
    socket
    |> remove_user_init(assignment_id)
    |> noreply()
  end

  def handle_event("remove_user_submit", _params, socket) do
    socket
    |> remove_user_submit()
    |> noreply()
  end

  #
  # Helpers
  #

  @spec add_user_form(Socket.t()) :: Socket.t()
  @spec add_user_form(Socket.t(), map) :: Socket.t()
  defp add_user_form(socket, params \\ %{"permissions" => %{"users" => true}}) do
    league = socket.assigns[:league]
    form = RM.Account.League.create_changeset(league, params) |> to_form()
    assign(socket, add_user_form: form)
  end

  @spec add_user_submit(Socket.t(), map) :: Socket.t()
  defp add_user_submit(socket, params) do
    league = socket.assigns[:league]

    case RM.Account.add_league_user(league, params) do
      {:ok, _assignment} ->
        league = RM.Repo.preload(league, [users: [:profile]], force: true)

        socket
        |> assign(league: league)
        |> put_flash(:info, "League administrator added successfully")
        |> push_js("#league-add-user-modal", "data-cancel")
        |> add_user_form()

      {:error, changeset} ->
        assign(socket, add_user_form: to_form(changeset))
    end
  end

  @spec assign_first_league(Socket.t()) :: Socket.t()
  defp assign_first_league(socket) do
    region = socket.assigns[:region]
    league = socket.assigns[:league]

    first_league = RM.FIRST.get_league_by_code(region, league.code)
    league = %{league | first_league: first_league}

    {first_matches?, first_differences} =
      case League.compare_with_first(league) do
        :unpublished -> {false, []}
        :match -> {true, []}
        {:different, differences} -> {false, differences}
      end

    assign(socket,
      first_differences: first_differences,
      first_league: first_league,
      first_matches: first_matches?,
      league: league
    )
  end

  @spec assign_teams(Socket.t()) :: Socket.t()
  defp assign_teams(socket) do
    league = socket.assigns[:league]

    teams =
      league.teams
      |> Enum.map(fn team -> %{team | league: league} end)

    {active_teams, inactive_teams} = Enum.split_with(teams, & &1.active)
    intend_to_return = Enum.filter(inactive_teams, & &1.intend_to_return)

    assign(socket,
      active_teams: active_teams,
      active_teams_count: length(active_teams),
      inactive_teams: inactive_teams,
      inactive_teams_count: length(inactive_teams),
      intend_to_return_teams: intend_to_return,
      intend_to_return_teams_count: length(intend_to_return)
    )
  end

  @spec edit_league_form(Socket.t()) :: Socket.t()
  @spec edit_league_form(Socket.t(), map) :: Socket.t()
  defp edit_league_form(socket, params \\ %{}) do
    league = socket.assigns[:league]
    form = RM.Local.League.update_changeset(league, params) |> to_form()
    assign(socket, edit_league_form: form)
  end

  @spec edit_league_submit(Socket.t(), map) :: Socket.t()
  defp edit_league_submit(socket, params) do
    league = socket.assigns[:league]

    case RM.Local.update_league(league, params) do
      {:ok, new_league} ->
        if new_league.code != league.code do
          socket
          |> put_flash(:info, "League updated successfully")
          |> push_navigate(to: ~p"/region/#{league.region}/leagues/#{new_league}", replace: true)
        else
          league = preload_league_associations(league)

          socket
          |> assign(league: league)
          |> put_flash(:info, "League updated successfully")
          |> assign(edit_league: false)
        end

      {:error, changeset} ->
        assign(socket, edit_league_form: to_form(changeset))
    end
  end

  @spec remove_user_cancel(Socket.t()) :: Socket.t()
  defp remove_user_cancel(socket) do
    socket
    |> assign(remove_user: nil)
    |> push_js("#league-remove-user-modal", "data-cancel")
  end

  @spec preload_league_associations(RM.Local.League.t()) :: RM.Local.League.t()
  defp preload_league_associations(league) do
    season = league.region.current_season

    league
    |> RM.Repo.preload([
      :teams,
      events: RM.FIRST.Event.season_query(season),
      event_proposals: RM.Local.EventProposal.season_query(season),
      users: [:profile]
    ])
    |> Map.update!(:events, &Enum.sort(&1, RM.FIRST.Event))
    |> Map.update!(:event_proposals, &Enum.sort(&1, RM.Local.EventProposal))
    |> Map.update!(:teams, &Enum.sort(&1, RM.Local.Team))
    |> Map.update!(:user_assignments, &Enum.sort(&1, RM.Account.League))
  end

  @spec remove_user_init(Socket.t(), Ecto.UUID.t()) :: Socket.t()
  defp remove_user_init(socket, assignment_id) do
    league = socket.assigns[:league]

    if assignment = Enum.find(league.user_assignments, &(&1.id == assignment_id)) do
      socket
      |> assign(remove_user: assignment)
      |> push_js("#league-remove-user-modal", "data-show")
    else
      league = RM.Repo.preload(league, [users: [:profile]], force: true)

      socket
      |> assign(league: league)
      |> put_flash(:error, "An error occurred; please try again")
    end
  end

  @spec remove_user_submit(Socket.t()) :: Socket.t()
  defp remove_user_submit(socket) do
    assignment = socket.assigns[:remove_user]
    league = socket.assigns[:league]

    case RM.Repo.delete(assignment) do
      {:ok, _assignment} ->
        league = RM.Repo.preload(league, [users: [:profile]], force: true)

        socket
        |> assign(league: league, remove_user: nil)
        |> put_flash(:info, "League administrator removed successfully")
        |> push_js("#league-remove-user-modal", "data-cancel")

      {:error, _changeset} ->
        league = RM.Repo.preload(league, [users: [:profile]], force: true)

        socket
        |> assign(league: league, remove_user: nil)
        |> put_flash(:error, "An error occurred; please try again")
        |> push_js("#league-remove-user-modal", "data-cancel")
    end
  end
end
