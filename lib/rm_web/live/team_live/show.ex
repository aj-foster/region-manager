defmodule RMWeb.TeamLive.Show do
  use RMWeb, :live_view

  on_mount {__MODULE__, :preload_team}

  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

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
  # Template Helpers
  #

  defp requires_attention?(team) do
    team.notices.lc1_missing or
      team.notices.lc1_ypp or
      team.notices.lc2_missing or
      team.notices.lc2_ypp or
      team.notices.unsecured
  end
end
