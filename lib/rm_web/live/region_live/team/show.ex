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
        IO.inspect(team)

        {:cont,
         assign(socket,
           lc1: Enum.find(team.user_assignments, &(&1.relationship == :lc1)),
           lc2: Enum.find(team.user_assignments, &(&1.relationship == :lc2)),
           team: team
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
