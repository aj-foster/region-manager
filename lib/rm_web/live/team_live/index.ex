defmodule RMWeb.TeamLive.Index do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_teams()
    |> assign(grouped_teams: [], sort: "")
    |> ok()
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
          RM.Local.list_teams_by_region(region)
        end

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
    else
      active_teams =
        if first_league do
          first_league.teams
        else
          region.teams
        end

      assign(socket,
        active_teams: active_teams,
        active_teams_count: length(active_teams),
        inactive_teams: [],
        inactive_teams_count: 0,
        intend_to_return_teams: [],
        intend_to_return_teams_count: 0
      )
    end
  end

  #
  # Template Helpers
  #

  @spec context_name(RM.FIRST.Region.t() | RM.FIRST.League.t() | RM.Local.League.t()) ::
          String.t()
  defp context_name(%RM.FIRST.Region{name: name}), do: name
  defp context_name(%RM.FIRST.League{name: name}), do: RM.Local.League.shorten_name(name, nil)
  defp context_name(%RM.Local.League{name: name}), do: RM.Local.League.shorten_name(name, nil)
end
