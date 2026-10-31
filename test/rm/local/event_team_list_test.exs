defmodule RM.Local.EventTeamListTest do
  use RM.DataCase, async: true

  alias RM.Local.EventTeamList
  alias RM.Local.LeagueAssignment
  alias RM.Repo

  test "lists registered teams first and then other active teams in the event league" do
    region = Factory.insert(:region)
    league = Factory.insert(:league, region: region)
    event = Factory.insert(:first_event, region: region, local_league: league)

    registered_team = Factory.insert(:team, region: region)
    league_team = Factory.insert(:team, region: region)
    other_league_team = Factory.insert(:team, region: region)
    inactive_team = Factory.insert(:team, region: region, active: false)
    unrelated_team = Factory.insert(:team, region: region)

    for team <- [registered_team, league_team, other_league_team, inactive_team] do
      Repo.insert!(%LeagueAssignment{league_id: league.id, team_id: team.id})
    end

    RM.Local.create_event_registrations(event, [registered_team], %{waitlisted: false})
    RM.Local.create_event_registration(event, league_team, %{waitlisted: true})

    %{registered: registered, unregistered: unregistered} = EventTeamList.list_teams(event)
    assert Enum.map(registered, & &1.id) == [registered_team.id]
    assert Enum.map(unregistered, & &1.id) == [league_team.id, other_league_team.id]

    refute unrelated_team.id in Enum.map(registered ++ unregistered, & &1.id)
    refute inactive_team.id in Enum.map(registered ++ unregistered, & &1.id)
  end

  test "non-league events include registered teams only" do
    region = Factory.insert(:region)
    event = Factory.insert(:first_event, region: region)
    registered_team = Factory.insert(:team, region: region)
    unregistered_team = Factory.insert(:team, region: region)

    RM.Local.create_event_registrations(event, [registered_team], %{waitlisted: false})

    %{registered: registered, unregistered: unregistered} = EventTeamList.list_teams(event)
    assert Enum.map(registered, & &1.id) == [registered_team.id]
    assert unregistered == []
    refute unregistered_team.id in Enum.map(registered ++ unregistered, & &1.id)
  end

  test "uses FIRST league assignments when the event has no local league" do
    region = Factory.insert(:region)
    first_league = Factory.insert(:first_league, region: region)
    event = Factory.insert(:first_event, region: region, league: first_league)
    first_team = Factory.insert(:first_team, region: region, season: event.season)
    Factory.insert(:first_league_assignment, league: first_league, team: first_team)

    league_team = Factory.insert(:team, region: region, number: first_team.team_number)
    other_team = Factory.insert(:team, region: region)

    %{registered: registered, unregistered: unregistered} = EventTeamList.list_teams(event)
    assert registered == []
    assert Enum.map(unregistered, & &1.id) == [league_team.id]
    refute other_team.id in Enum.map(registered ++ unregistered, & &1.id)
  end
end
