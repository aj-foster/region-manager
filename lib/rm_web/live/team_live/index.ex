defmodule RMWeb.TeamLive.Index do
  use RMWeb, :live_view

  alias RM.Import

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    region = socket.assigns[:region]
    first_league = socket.assigns[:first_league]
    local_league = socket.assigns[:local_league]

    socket
    |> assign_teams()
    |> assign_unmatched_teams()
    |> maybe_allow_upload()
    |> assign(
      import_errors: [],
      import_status: :none,
      page_title: "#{context_name(local_league || first_league || region)} Teams"
    )
    |> ok()
  end

  @spec maybe_allow_upload(Socket.t()) :: Socket.t()
  defp maybe_allow_upload(socket) do
    region = socket.assigns[:region]
    first_league = socket.assigns[:first_league]
    local_league = socket.assigns[:local_league]
    user = socket.assigns[:current_user]

    if can?(user, :team_update, region) and is_nil(first_league) and is_nil(local_league) do
      allow_upload(socket, :team_data,
        accept: ["text/csv"],
        auto_upload: true,
        max_file_size: 1024 * 1024,
        progress: &handle_progress/3
      )
    else
      socket
    end
  end

  # @doc false
  # @impl true
  # def handle_params(params, _uri, socket) do
  #   region = socket.assigns[:region]

  #   case params["sort"] do
  #     "number" ->
  #       group_by_number(socket)

  #     _else ->
  #       if region.has_leagues do
  #         group_by_league(socket)
  #       else
  #         group_by_number(socket)
  #       end
  #   end
  #   |> noreply()
  # end

  #
  # Events
  #

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

  def handle_event("sort_league", _params, socket) do
    socket
    |> push_query(sort: "league")
    |> noreply()
  end

  def handle_event("sort_number", _params, socket) do
    socket
    |> push_query(sort: "number")
    |> noreply()
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
        |> assign_teams()
        |> refresh_region()
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

  @spec assign_teams(Socket.t()) :: Socket.t()
  defp assign_teams(socket) do
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    first_league = socket.assigns[:first_league]
    local_league = socket.assigns[:local_league]

    if season == region.current_season do
      teams =
        if local_league do
          RM.Local.list_teams_by_league(local_league)
        else
          RM.Local.list_teams_by_region(region, preload: [:league])
        end

      {active_teams, inactive_teams} = Enum.split_with(teams, & &1.active)
      intend_to_return = Enum.filter(inactive_teams, & &1.intend_to_return)

      assign(socket,
        active_teams: active_teams,
        active_teams_count: length(active_teams),
        inactive_teams: inactive_teams,
        inactive_teams_count: length(inactive_teams),
        intend_to_return_teams: intend_to_return,
        intend_to_return_teams_count: length(intend_to_return),
        teams: teams,
        teams_count: length(teams)
      )
    else
      teams =
        if first_league do
          RM.Repo.preload(first_league, :teams)
          |> Map.fetch!(:teams)
          |> Enum.map(&Map.put(&1, :league, first_league))
          |> Enum.sort(&team_sort/2)
        else
          RM.FIRST.list_teams_by_region(region, season: season, preload: [:league])
          |> Enum.sort(&team_sort/2)
        end

      assign(socket,
        active_teams: teams,
        active_teams_count: length(teams),
        inactive_teams: [],
        inactive_teams_count: 0,
        intend_to_return_teams: [],
        intend_to_return_teams_count: 0,
        teams: teams,
        teams_count: length(teams)
      )
    end
  end

  @spec assign_unmatched_teams(Socket.t()) :: Socket.t()
  defp assign_unmatched_teams(socket) do
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    first_league = socket.assigns[:first_league]
    local_league = socket.assigns[:local_league]

    if season == region.current_season and is_nil(local_league) and is_nil(first_league) do
      teams_by_number = Map.new(socket.assigns[:teams], fn team -> {team.number, team} end)

      first_teams =
        RM.FIRST.list_teams_by_region(region, season: season)
        |> Enum.map(fn team ->
          Map.put(team, :local_team, teams_by_number[team.team_number])
        end)

      unmatched_first_teams = Enum.filter(first_teams, &is_nil(&1.local_team))

      assign(socket,
        unmatched_first_teams: unmatched_first_teams,
        unmatched_first_teams_count: length(unmatched_first_teams)
      )
    else
      assign(socket,
        unmatched_first_teams: [],
        unmatched_first_teams_count: 0
      )
    end
  end

  @spec refresh_region(Socket.t()) :: Socket.t()
  defp refresh_region(socket) do
    region =
      socket.assigns[:region]
      |> RM.Repo.reload!()

    assign(socket, region: region)
  end

  #
  # Template Helpers
  #

  @spec context_name(RM.FIRST.Region.t() | RM.FIRST.League.t() | RM.Local.League.t()) ::
          String.t()
  defp context_name(%RM.FIRST.Region{name: name}), do: name

  defp context_name(%RM.FIRST.League{name: name}),
    do: RM.Local.League.shorten_name(name, nil) <> " League"

  defp context_name(%RM.Local.League{name: name}),
    do: RM.Local.League.shorten_name(name, nil) <> " League"

  @spec upload_error_to_string(atom) :: String.t()
  defp upload_error_to_string(:too_large), do: "Provided file is too large"
  defp upload_error_to_string(:not_accepted), do: "Please select a .csv file"
  defp upload_error_to_string(:external_client_failure), do: "Something went terribly wrong"

  @doc false
  @spec team_sort(RM.FIRST.Team.t() | RM.Local.Team.t(), RM.FIRST.Team.t() | RM.Local.Team.t()) ::
          boolean
  def team_sort(a, b) do
    extract_number(a) <= extract_number(b)
  end

  @spec extract_number(RM.FIRST.Team.t() | RM.Local.Team.t()) :: integer
  defp extract_number(%RM.FIRST.Team{team_number: number}), do: number
  defp extract_number(%RM.Local.Team{number: number}), do: number
end
