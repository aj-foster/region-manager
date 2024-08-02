defmodule RMWeb.RegionLive.Setup do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util
  require Logger

  alias Phoenix.LiveView.AsyncResult
  alias RM.FIRST
  alias RM.FIRST.Region
  alias RM.Import

  #
  # Lifecycle
  #

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_current_season()
    |> allow_upload(:team_data, accept: ["text/csv"], max_file_size: 1024 * 1024)
    |> assign(
      import_successful: nil,
      refresh_events: AsyncResult.ok(nil),
      refresh_leagues: AsyncResult.ok(nil)
    )
    |> ok()
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("setup_submit_no_leagues", _params, socket) do
    socket
    |> setup_submit_no_leagues()
    |> noreply()
  end

  def handle_event("validate", _params, socket) do
    noreply(socket)
  end

  def handle_event("import", _params, socket) do
    user = socket.assigns[:current_user]

    consume_uploaded_entries(socket, :team_data, fn %{path: path}, _entry ->
      Import.import_from_team_info_tableau_export(user, path)
      {:ok, path}
    end)

    socket
    |> assign(import_successful: true)
    |> noreply()
  end

  def handle_event("refresh_events", _params, socket) do
    region = socket.assigns[:region]

    socket
    |> start_async(:refresh_events, fn -> FIRST.refresh_events(region) end)
    |> assign(refresh_events: AsyncResult.loading())
    |> noreply()
  end

  def handle_event("refresh_leagues", _params, socket) do
    region = socket.assigns[:region]

    socket
    |> start_async(:refresh_leagues, fn -> FIRST.refresh_leagues(region) end)
    |> assign(refresh_leagues: AsyncResult.loading())
    |> noreply()
  end

  @doc false
  @impl true
  def handle_async(name, async_fun_result, socket)

  def handle_async(:refresh_events, {:ok, _events}, socket) do
    socket
    |> assign(refresh_events: AsyncResult.ok(true))
    |> refresh_region()
    |> noreply()
  end

  def handle_async(:refresh_events, {:error, reason}, socket) do
    Logger.error("Error while refreshing events: #{inspect(reason)}")

    socket
    |> assign(refresh_events: AsyncResult.ok(false))
    |> noreply()
  end

  def handle_async(:refresh_leagues, {:ok, _leagues}, socket) do
    socket
    |> assign(refresh_leagues: AsyncResult.ok(true))
    |> refresh_region()
    |> noreply()
  end

  def handle_async(:refresh_leagues, {:error, reason}, socket) do
    Logger.error("Error while refreshing leagues: #{inspect(reason)}")

    socket
    |> assign(refresh_leagues: AsyncResult.ok(false))
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_current_season(Socket.t()) :: Socket.t()
  defp assign_current_season(socket) do
    current_season = RM.Config.get("current_season")
    region = socket.assigns[:region]

    assign(socket,
      current_season: current_season,
      needs_season_update: region.current_season < current_season
    )
  end

  @spec setup_submit_no_leagues(Socket.t()) :: Socket.t()
  defp setup_submit_no_leagues(socket) do
    region = socket.assigns[:region]
    season = socket.assigns[:current_season]

    case RM.FIRST.update_region_season(region, season) do
      {:ok, _region} ->
        socket
        |> refresh_region()
        |> assign_current_season()
        |> put_flash(:info, "Welcome to the new season!")
    end
  end

  #
  # Template Helpers
  #

  @spec refreshed_events_recently?(Region.t()) :: boolean
  defp refreshed_events_recently?(%Region{stats: %{events_imported_at: last_refresh}}) do
    not is_nil(last_refresh) and
      DateTime.after?(last_refresh, DateTime.add(DateTime.utc_now(), -1, :hour))
  end

  @spec refreshed_leagues_recently?(Region.t()) :: boolean
  defp refreshed_leagues_recently?(%Region{stats: %{leagues_imported_at: last_refresh}}) do
    not is_nil(last_refresh) and
      DateTime.after?(last_refresh, DateTime.add(DateTime.utc_now(), -1, :hour))
  end
end
