defmodule RM.Local.EventTeamList do
  @moduledoc """
  Provides the teams to include in an event check-in roster.
  """

  alias RM.FIRST.League, as: FirstLeague
  alias RM.FIRST.Event
  alias RM.Local
  alias RM.Local.Team
  alias RM.Repo

  @spec list_teams(Event.t()) :: %{registered: [Team.t()], unregistered: [Team.t()]}
  def list_teams(%Event{} = event) do
    event = Repo.preload(event, [:local_league, :league, :region])

    registered_teams =
      Local.list_registered_teams_by_event(event, rescinded: false, waitlisted: false)
      |> Enum.map(& &1.team)
      |> Enum.uniq_by(& &1.id)

    registered_team_ids = MapSet.new(registered_teams, & &1.id)

    other_teams =
      case event.local_league do
        %Local.League{} = league ->
          Local.list_teams_by_league(league, active: true, season: event.season)
          |> Enum.reject(&MapSet.member?(registered_team_ids, &1.id))

        nil ->
          list_teams_by_first_league(event)
          |> Enum.reject(&MapSet.member?(registered_team_ids, &1.id))
      end

    %{registered: registered_teams, unregistered: other_teams}
  end

  defp list_teams_by_first_league(%Event{league: %FirstLeague{} = league} = event) do
    team_numbers =
      Repo.preload(league, :teams).teams
      |> Enum.map(& &1.team_number)
      |> MapSet.new()

    Local.list_teams_by_region(event.region, active: true, season: event.season)
    |> Enum.filter(&MapSet.member?(team_numbers, &1.number))
  end

  defp list_teams_by_first_league(_event), do: []
end
