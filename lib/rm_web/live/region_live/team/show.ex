defmodule RMWeb.RegionLive.Team.Show do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  #
  # Lifecycle
  #

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}
  on_mount {__MODULE__, :preload_team}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  def on_mount(:preload_team, %{"team" => team_number}, _session, socket) do
    region = socket.assigns[:region]

    case RM.Local.fetch_team_by_number(team_number, region: region, preload: [:league, :users]) do
      {:ok, team} ->
        {:cont,
         assign(socket,
           lc1: Enum.find(team.user_assignments, &(&1.relationship == :lc1)),
           lc2: Enum.find(team.user_assignments, &(&1.relationship == :lc2)),
           team: team,
           page_title: "Team #{team.number} • #{region.name}"
         )}

      {:error, :team, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Team not found")
          |> redirect(to: ~p"/dashboard")

        {:halt, socket}
    end
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("league_change", %{"league" => league_id}, socket) do
    socket
    |> league_change(league_id)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec league_change(Socket.t(), Ecto.UUID.t()) :: Socket.t()
  defp league_change(socket, league_id_or_empty) do
    region = socket.assigns[:region]
    team = socket.assigns[:team]
    league_or_nil = Enum.find(region.leagues, &(&1.id == league_id_or_empty))

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

  @spec league_options(RM.FIRST.Region.t()) :: [{String.t(), String.t()}]
  defp league_options(region) do
    Enum.map(region.leagues, fn league ->
      {league.name, league.id}
    end)
    |> List.insert_at(0, {"No League Assignment", ""})
  end
end
