defmodule RMWeb.DashboardLive.Home do
  use RMWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]
    unconfirmed_email_count = Enum.count(current_user.emails, fn e -> is_nil(e.confirmed_at) end)

    socket
    |> assign(
      page_title: "Dashboard",
      league_count: length(current_user.leagues),
      region_count: length(current_user.regions),
      team_count: length(current_user.teams),
      unconfirmed_email_count: unconfirmed_email_count,
      pending_tasks: []
    )
    |> start_async(:pending_proposals, fn -> pending_proposals(current_user.regions) end)
    |> start_async(:teams_to_import, fn -> teams_to_import(current_user.regions) end)
    |> start_async(:teams_without_league, fn -> teams_without_league(current_user.regions) end)
    |> assign_seasons()
    |> ok()
  end

  @impl true
  def handle_async(name, {:ok, tasks}, socket)
      when name in [
             :pending_proposals,
             :teams_to_import,
             :teams_without_league
           ] do
    socket
    |> assign(:pending_tasks, socket.assigns.pending_tasks ++ tasks)
    |> noreply()
  end

  def handle_async(name, {:exit, reason}, socket)
      when name in [
             :pending_proposals,
             :teams_to_import,
             :teams_without_league
           ] do
    Logger.error("Error while loading dashboard pending tasks (#{name}): #{inspect(reason)}")

    socket
    |> assign(:pending_tasks, [
      %{
        id: "pending-task-error-#{name}",
        title: pending_task_error(name),
        description: "Please try again later.",
        href: nil,
        error: true
      }
      | socket.assigns.pending_tasks
    ])
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_seasons(Socket.t()) :: Socket.t()
  defp assign_seasons(socket) do
    seasons = RM.FIRST.list_seasons() |> Enum.reverse()
    assign(socket, seasons: seasons, seasons_count: length(seasons))
  end

  defp pending_proposals(regions) do
    regions
    |> Enum.flat_map(fn region ->
      count =
        RM.Local.list_event_proposals_by_region(region)
        |> Enum.count(fn proposal ->
          is_nil(proposal.removed_at) and
            ((is_nil(proposal.first_event_id) and is_nil(proposal.submitted_at)) or
               not is_nil(proposal.details_updated_at))
        end)

      if count > 0 do
        [
          %{
            id: "pending-proposals-#{region.id}",
            title:
              "#{region.name} has #{dumb_inflect("new or updated event proposal", count)} awaiting submission",
            description: "Click to navigate to the event proposals page.",
            href: ~p"/s/#{region.current_season}/r/#{region}/proposals",
            error: false
          }
        ]
      else
        []
      end
    end)
  end

  defp teams_to_import(regions) do
    regions
    |> Enum.flat_map(fn region ->
      team_numbers =
        RM.Local.list_teams_by_region(region)
        |> MapSet.new(& &1.number)

      count =
        RM.FIRST.list_teams_by_region(region, season: region.current_season)
        |> Enum.count(fn team -> not MapSet.member?(team_numbers, team.team_number) end)

      if count > 0 do
        [
          %{
            id: "teams-to-import-#{region.id}",
            title: "#{region.name} has #{dumb_inflect("team", count)} awaiting import",
            description: "Click to navigate to the team page.",
            href: ~p"/s/#{region.current_season}/r/#{region}/teams",
            error: false
          }
        ]
      else
        []
      end
    end)
  end

  defp teams_without_league(regions) do
    regions
    |> Enum.filter(& &1.has_leagues)
    |> Enum.flat_map(fn region ->
      count =
        RM.Local.list_teams_by_region(region, preload: [:league])
        |> Enum.count(fn team ->
          team.active and is_nil(team.hidden_at) and is_nil(team.league)
        end)

      if count > 0 do
        [
          %{
            id: "teams-without-league-#{region.id}",
            title:
              "#{region.name} has #{dumb_inflect("team", count)} needing a league assignment",
            description: "Click to navigate to the team page.",
            href: ~p"/s/#{region.current_season}/r/#{region}/teams",
            error: false
          }
        ]
      else
        []
      end
    end)
  end

  defp pending_task_error(:pending_proposals), do: "Could not check pending event proposals."
  defp pending_task_error(:teams_to_import), do: "Could not check teams awaiting import."

  defp pending_task_error(:teams_without_league),
    do: "Could not check teams without league assignments."
end
