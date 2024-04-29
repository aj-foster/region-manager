defmodule RMWeb.RegionLive.Import do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util
  require Logger

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
    socket =
      socket
      |> allow_upload(:team_data, accept: ["text/csv"], max_file_size: 1024 * 1024)
      |> assign(refresh_events: nil, refresh_leagues: nil)

    {:ok, socket}
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("validate", _params, socket) do
    noreply(socket)
  end

  def handle_event("import", _params, socket) do
    user = socket.assigns[:current_user]

    consume_uploaded_entries(socket, :team_data, fn %{path: path}, _entry ->
      Import.import_from_team_info_tableau_export(user, path)
      {:ok, path}
    end)

    noreply(socket)
  end

  def handle_event("refresh_events", _params, socket) do
    socket
    |> assign_async(:refresh_events, fn -> do_refresh_events() end)
    |> noreply()
  end

  def handle_event("refresh_leagues", _params, socket) do
    region = socket.assigns[:region]

    socket
    |> assign_async(:refresh_leagues, fn -> do_refresh_leagues(region) end)
    |> noreply()
  end

  #
  # Helpers
  #

  defp do_refresh_events do
    case FIRST.refresh_events() do
      {:ok, _events} ->
        {:ok, %{refresh_events: true}}

      {:error, reason} ->
        Logger.error("Error while refreshing events: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_refresh_leagues(region) do
    case FIRST.refresh_leagues(region) do
      {:ok, _leagues} ->
        {:ok, %{refresh_leagues: true}}

      {:error, reason} ->
        Logger.error("Error while refreshing leagues: #{inspect(reason)}")
        {:error, reason}
    end
  end

  #
  # Template Helpers
  #

  defp refreshed_events_recently?(%Region{stats: %{events_imported_at: last_refresh}}) do
    not is_nil(last_refresh) and
      DateTime.after?(last_refresh, DateTime.add(DateTime.utc_now(), -1, :hour))
  end

  defp refreshed_leagues_recently?(%Region{stats: %{leagues_imported_at: last_refresh}}) do
    not is_nil(last_refresh) and
      DateTime.after?(last_refresh, DateTime.add(DateTime.utc_now(), -1, :hour))
  end
end
