defmodule RMWeb.LeagueLive.Team.Show do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  #
  # Lifecycle
  #

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}
  on_mount {__MODULE__, :preload_team}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  def on_mount(:preload_team, %{"team" => team_number}, _session, socket) do
    league = socket.assigns[:league]

    case RM.Local.fetch_team_by_number(team_number, league: league, preload: [:league, :users]) do
      {:ok, team} ->
        {:cont,
         assign(socket,
           lc1: Enum.find(team.user_assignments, &(&1.relationship == :lc1)),
           lc2: Enum.find(team.user_assignments, &(&1.relationship == :lc2)),
           team: team,
           page_title: "Team #{team.number} • #{league.name}"
         )}

      {:error, :team, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Team not found")
          |> redirect(to: ~p"/dashboard")

        {:halt, socket}
    end
  end
end
