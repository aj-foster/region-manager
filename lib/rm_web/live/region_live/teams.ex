defmodule RMWeb.RegionLive.Teams do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

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
    |> assign_first_teams()
    |> assign_teams()
    |> allow_upload(:team_data,
      accept: ["text/csv"],
      auto_upload: true,
      max_file_size: 1024 * 1024,
      progress: &handle_progress/3
    )
    |> assign(
      import_errors: [],
      import_status: :none
    )
    |> ok()
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("import_change", _params, socket) do
    case socket.assigns[:uploads].team_data do
      %{entries: [%{valid?: false} = entry]} = upload ->
        socket
        |> assign(
          import_errors: upload_errors(upload, entry),
          import_status: :error
        )
        |> noreply()

      _else ->
        noreply(socket)
    end
  end

  def handle_event("import_submit", _params, socket) do
    noreply(socket)
  end

  @doc false
  defp handle_progress(upload, entry, socket)

  defp handle_progress(:team_data, entry, socket) do
    cond do
      entry.done? ->
        user = socket.assigns[:current_user]

        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          Import.import_from_team_info_tableau_export(user, path)
          {:ok, path}
        end)

        socket
        |> assign(import_status: :done)
        |> refresh_region()
        |> assign_first_teams()
        |> assign_teams()
        |> noreply()

      entry.cancelled? ->
        socket
        |> assign(import_status: :cancelled)
        |> noreply()

      :else ->
        socket
        |> assign(import_status: :in_progress)
        |> noreply()
    end
  end

  #
  # Helpers
  #

  @spec assign_first_teams(Socket.t()) :: Socket.t()
  defp assign_first_teams(socket) do
    region = socket.assigns[:region]
    teams_by_number = Map.new(region.teams, fn team -> {team.number, team} end)

    first_teams =
      RM.FIRST.list_teams_by_region(region)
      |> Enum.map(fn team ->
        Map.put(team, :local_team, teams_by_number[team.team_number])
      end)

    unmatched_first_teams = Enum.filter(first_teams, &is_nil(&1.local_team))

    assign(socket,
      unmatched_first_teams: unmatched_first_teams,
      unmatched_first_teams_count: length(unmatched_first_teams)
    )
  end

  @spec assign_teams(Socket.t()) :: Socket.t()
  defp assign_teams(socket) do
    teams =
      socket.assigns[:region].teams
      |> RM.Repo.preload(:league)

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

  #
  # Template Helpers
  #

  @spec upload_error_to_string(atom) :: String.t()
  defp upload_error_to_string(:too_large), do: "Provided file is too large"
  defp upload_error_to_string(:not_accepted), do: "Please select a .csv file"
  defp upload_error_to_string(:external_client_failure), do: "Something went terribly wrong"
end
