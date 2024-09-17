defmodule RMWeb.RegionLive.League.Index do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util
  require Logger

  alias Phoenix.LiveView.AsyncResult
  alias RM.FIRST.Region
  alias RM.Local.League

  #
  # Lifecycle
  #

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_first_leagues()
    |> assign_leagues()
    |> assign_refresh_disabled()
    |> assign(refresh_leagues: AsyncResult.ok(nil))
    |> ok()
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, params, socket)

  def handle_event("copy_league", %{"league" => league_id}, socket) do
    socket
    |> copy_league(league_id)
    |> noreply()
  end

  def handle_event("refresh_leagues", _params, socket) do
    region = socket.assigns[:region]

    socket
    |> start_async(:refresh_leagues, fn -> RM.FIRST.refresh_leagues(region) end)
    |> assign(refresh_leagues: AsyncResult.loading())
    |> noreply()
  end

  def handle_event("unhide_league", %{"league" => league_id}, socket) do
    socket
    |> unhide_league(league_id)
    |> noreply()
  end

  @doc false
  @impl true
  def handle_async(name, async_fun_result, socket)

  def handle_async(:refresh_leagues, {:ok, {:ok, _leagues}}, socket) do
    socket
    |> assign(refresh_leagues: AsyncResult.ok(true))
    |> refresh_region()
    |> assign_first_leagues()
    |> assign_leagues()
    |> assign_refresh_disabled()
    |> noreply()
  end

  def handle_async(:refresh_leagues, {:ok, {:error, reason}}, socket) do
    Logger.error("Error while refreshing leagues: #{inspect(reason)}")

    socket
    |> assign(refresh_leagues: AsyncResult.ok(false))
    |> put_flash(:error, "An error occurred while refreshing leagues. Please try again later.")
    |> noreply()
  end

  def handle_async(:refresh_leagues_disabled, {:ok, :done}, socket) do
    socket
    |> assign(refresh_leagues_disabled: false)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_first_leagues(Socket.t()) :: Socket.t()
  defp assign_first_leagues(socket) do
    region = socket.assigns[:region]
    leagues_by_code = Map.new(region.leagues, fn league -> {league.code, league} end)

    first_leagues =
      RM.FIRST.list_leagues_by_region(region)
      |> Enum.map(fn league ->
        Map.put(league, :local_league, leagues_by_code[league.code])
      end)

    unmatched_first_leagues =
      Enum.filter(first_leagues, fn league ->
        is_nil(league.local_league) or not is_nil(league.local_league.removed_at)
      end)

    first_leagues_by_code = Map.new(first_leagues, &{&1.code, &1})

    leagues =
      Enum.map(region.leagues, fn league ->
        league
        |> Map.put(:first_league, first_leagues_by_code[league.code])
        |> Map.put(:region, region)
      end)

    assign(socket,
      first_leagues: first_leagues,
      region: %{region | leagues: leagues},
      unmatched_first_leagues: unmatched_first_leagues,
      unmatched_first_leagues_count: length(unmatched_first_leagues)
    )
  end

  @spec assign_leagues(Socket.t()) :: Socket.t()
  defp assign_leagues(socket) do
    region = socket.assigns[:region]
    visible_leagues = Enum.filter(region.leagues, &is_nil(&1.removed_at))

    assign(socket, visible_leagues: visible_leagues)
  end

  @spec assign_refresh_disabled(Socket.t()) :: Socket.t()
  defp assign_refresh_disabled(socket) do
    %Region{stats: %{leagues_imported_at: last_refresh}} = socket.assigns[:region]

    if not is_nil(last_refresh) and
         DateTime.after?(last_refresh, DateTime.add(DateTime.utc_now(), -10, :minute)) do
      time_until_enabled_ms =
        DateTime.add(last_refresh, 10, :minute)
        |> DateTime.diff(DateTime.utc_now(), :millisecond)

      socket
      |> assign(refresh_leagues_disabled: true)
      |> start_async(:refresh_leagues_disabled, fn ->
        Process.sleep(time_until_enabled_ms)
        :done
      end)
    else
      assign(socket, refresh_leagues_disabled: false)
    end
  end

  @spec copy_league(Socket.t(), String.t()) :: Socket.t()
  defp copy_league(socket, league_id) do
    first_leagues = socket.assigns[:first_leagues]

    if first_league = Enum.find(first_leagues, &(&1.id == league_id)) do
      case RM.Local.create_league_from_first(first_league) do
        {:ok, _league} ->
          socket
          |> put_flash(:info, "#{first_league.name} League was copied successfully")
          |> refresh_region()
          |> assign_first_leagues()
          |> assign_leagues()

        {:error, _changeset} ->
          socket
          |> put_flash(:error, "An error occurred while copying the league")
      end
    else
      socket
      |> put_flash(:error, "League not found; please try again")
      |> refresh_region()
      |> assign_first_leagues()
      |> assign_leagues()
    end
  end

  @spec unhide_league(Socket.t(), String.t()) :: Socket.t()
  defp unhide_league(socket, league_id) do
    region = socket.assigns[:region]

    if league = Enum.find(region.leagues, &(&1.id == league_id)) do
      case RM.Local.unhide_league(league) do
        {:ok, _league} ->
          socket
          |> put_flash(:info, "#{league.name} League is no longer hidden")
          |> refresh_region()
          |> assign_first_leagues()
          |> assign_leagues()

        {:error, _changeset} ->
          socket
          |> put_flash(:error, "An error occurred while unhiding the league")
      end
    else
      socket
      |> put_flash(:error, "League not found; please try again")
      |> refresh_region()
      |> assign_first_leagues()
      |> assign_leagues()
    end
  end
end
