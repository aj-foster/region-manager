defmodule RM.FIRST.LeagueAssignmentTest do
  use ExUnit.Case, async: true

  alias RM.FIRST.League
  alias RM.FIRST.LeagueAssignment
  alias RM.FIRST.Team

  test "new/2 links the provided league and team and uses one timestamp" do
    league = %League{id: Ecto.UUID.generate()}
    team = %Team{id: Ecto.UUID.generate()}

    assert %{
             league_id: league_id,
             team_id: team_id,
             inserted_at: %DateTime{} = inserted_at,
             updated_at: updated_at
           } = LeagueAssignment.new(league, team)

    assert league_id == league.id
    assert team_id == team.id
    assert updated_at == inserted_at
  end
end
