defmodule RMWeb.TeamLive.Map do
  use RMWeb, :live_view

  @unassigned_league "Unassigned"

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    with :ok <- require_permission(socket) do
      socket
      |> assign_map()
      |> ok()
    end
  end

  @spec require_permission(Socket.t()) :: :ok | {:ok, Socket.t()}
  defp require_permission(socket) do
    region = socket.assigns[:region]
    user = socket.assigns[:current_user]

    if can?(user, :team_update, region) do
      :ok
    else
      socket
      |> put_flash(:error, "You are not authorized to view the team map.")
      |> redirect(to: ~p"/s/#{socket.assigns[:season]}/r/#{region}/teams")
      |> ok()
    end
  end

  @spec assign_map(Socket.t()) :: Socket.t()
  defp assign_map(socket) do
    region = socket.assigns[:region]
    season = socket.assigns[:season]

    teams =
      RM.Local.list_teams_by_region(region,
        active: true,
        preload: [:league],
        season: season
      )
      |> Enum.reject(& &1.hidden_at)

    markers = build_markers(teams)

    assign(socket,
      page_title: "#{region.name} Team Map",
      markers: markers,
      mapped_team_count: Enum.sum(Enum.map(markers, &length(&1.teams))),
      leagues: marker_leagues(markers)
    )
  end

  defp build_markers(teams) do
    teams
    |> Enum.reduce(%{}, fn team, markers ->
      with postcode when not is_nil(postcode) <- normalize_postcode(team),
           {latitude, longitude} when is_number(latitude) and is_number(longitude) <-
             RM.Util.Postcode.coordinates(postcode) do
        league = league_name(team)

        marker_team = %{
          id: team.id,
          number: team.number,
          name: team.name,
          league: league
        }

        Map.update(
          markers,
          postcode,
          %{latitude: latitude, longitude: longitude, teams: [marker_team]},
          fn marker -> %{marker | teams: [marker_team | marker.teams]} end
        )
      else
        _invalid_postcode -> markers
      end
    end)
    |> add_league_colors()
  end

  defp normalize_postcode(%RM.Local.Team{location: %{postal_code: postcode}})
       when is_binary(postcode) do
    String.trim(postcode)
  end

  defp normalize_postcode(_team), do: nil

  defp add_league_colors(markers) do
    leagues =
      markers
      |> Map.values()
      |> Enum.flat_map(& &1.teams)
      |> Enum.map(& &1.league)
      |> Enum.uniq()
      |> Enum.sort()

    colors =
      leagues
      |> Enum.with_index()
      |> Map.new(fn {league, index} ->
        hue = div(index * 360, length(leagues))
        {league, "hsl(#{hue}, 68%, 42%)"}
      end)

    markers
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {_postcode, marker} ->
      teams =
        marker.teams
        |> Enum.map(&Map.put(&1, :color, Map.fetch!(colors, &1.league)))
        |> Enum.sort_by(& &1.number)

      marker_leagues =
        teams
        |> Enum.uniq_by(& &1.league)
        |> Enum.map(fn team -> %{name: team.league, color: team.color} end)

      Map.merge(marker, %{teams: teams, leagues: marker_leagues})
    end)
  end

  defp marker_leagues(markers) do
    markers
    |> Enum.flat_map(& &1.leagues)
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(& &1.name)
  end

  defp league_name(%RM.Local.Team{league: %RM.Local.League{name: name}}), do: name
  defp league_name(_team), do: @unassigned_league
end
