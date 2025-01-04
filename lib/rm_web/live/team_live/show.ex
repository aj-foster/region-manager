defmodule RMWeb.TeamLive.Show do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_leagues()
    |> ok()
  end

  on_mount {__MODULE__, :preload_team}

  def on_mount(:preload_team, %{"team" => number}, _session, socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]

    redirect_target = url_for([season, region, league, :teams])

    if season == region.current_season do
      case RM.Local.fetch_team_by_number(number,
             league: league,
             preload: [:region, :league, :users]
           ) do
        {:ok, team} ->
          {:cont,
           assign(socket,
             lc1: Enum.find(team.user_assignments, &(&1.relationship == :lc1)),
             lc2: Enum.find(team.user_assignments, &(&1.relationship == :lc2)),
             team: team,
             page_title: team.name
           )}

        {:error, :team, :not_found} ->
          socket =
            socket
            |> put_flash(:error, "Team not found")
            |> redirect(to: redirect_target)

          {:halt, socket}
      end
    else
      case RM.FIRST.fetch_team_by_number(number,
             region: region,
             season: season,
             preload: [:league]
           ) do
        {:ok, team} ->
          {:cont, assign(socket, lc1: nil, lc2: nil, team: team, page_title: team.name_short)}

        {:error, :team, :not_found} ->
          socket =
            socket
            |> put_flash(:error, "Team not found")
            |> redirect(to: redirect_target)

          {:halt, socket}
      end
    end
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("league_change", %{"league" => league_id}, socket) do
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    team = socket.assigns[:team]
    user = socket.assigns[:current_user]

    if can?(user, :team_league_update, team) and season == region.current_season do
      socket
      |> league_change(league_id)
      |> noreply()
    else
      socket
      |> put_flash(:error, "You do not have permission to perform this action")
      |> noreply()
    end
  end

  #
  # Helpers
  #

  @spec assign_leagues(Socket.t()) :: Socket.t()
  defp assign_leagues(socket) do
    region = socket.assigns[:region]
    leagues = RM.Local.list_leagues_by_region(region)

    assign(socket, leagues: leagues)
  end

  @spec league_change(Socket.t(), Ecto.UUID.t()) :: Socket.t()
  defp league_change(socket, league_id_or_empty) do
    leagues = socket.assigns[:leagues]
    team = socket.assigns[:team]
    league_or_nil = Enum.find(leagues, &(&1.id == league_id_or_empty))

    if league_or_nil do
      case RM.Local.create_or_update_league_assignment(league_or_nil, team) do
        {:ok, _assignment} ->
          team = RM.Repo.preload(team, :league, force: true)

          socket
          |> assign(team: team)
          |> put_flash(:info, "League assignment updated successfully")
          |> push_js("#league-assignment-change-modal", "data-cancel")

        {:error, _changeset} ->
          socket
          |> put_flash(:error, "An error occurred while updating league assignment")
          |> push_js("#league-assignment-change-modal", "data-cancel")
      end
    else
      RM.Local.remove_league_assignment(team)
      team = RM.Repo.preload(team, :league, force: true)

      socket
      |> assign(team: team)
      |> put_flash(:info, "League assignment removed successfully")
      |> push_js("#league-assignment-change-modal", "data-cancel")
    end
  end

  #
  # Template Helpers
  #

  @spec league_options([RM.Local.League.t()]) :: [{String.t(), String.t()}]
  defp league_options(leagues) do
    Enum.map(leagues, fn league ->
      {league.name, league.id}
    end)
    |> List.insert_at(0, {"No League Assignment", ""})
  end

  @spec requires_attention?(RM.Local.Team.t()) :: boolean
  defp requires_attention?(team) do
    team.notices.lc1_missing or
      team.notices.lc1_ypp or
      team.notices.lc2_missing or
      team.notices.lc2_ypp or
      team.notices.unsecured
  end
end
