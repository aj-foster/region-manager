defmodule RMWeb.RegionLive.League do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}
  on_mount {__MODULE__, :preload_league}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  def on_mount(:preload_league, %{"league" => league_code}, _session, socket) do
    case RM.FIRST.fetch_league_by_code(league_code, preload: [:region]) do
      {:ok, league} ->
        league =
          league
          |> RM.Repo.preload([:events, :teams, :users])
          |> Map.update!(:events, &Enum.sort(&1, RM.FIRST.Event))
          |> Map.update!(:teams, &Enum.sort(&1, RM.Local.Team))

        {:cont, assign(socket, league: league)}

      {:error, :league, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "League not found")
          |> redirect(to: ~p"/dashboard")

        {:halt, socket}
    end
  end
end
