defmodule RM.FIRSTTest do
  use RM.DataCase

  alias RM.FIRST

  describe "update_events_from_ftc_events/2" do
    test "inserts, updates, and removes events" do
      region = Factory.insert(:region, code: "USFL")
      league = Factory.insert(:first_league, region: region, code: "FLOR")

      # Event to be updated
      Factory.insert(:first_event, code: "USFLFLORM1", season: 2023)

      # Event to be removed
      Factory.insert(:first_event, code: "USIDKS", season: 2023)

      input =
        File.read!("test/fixture/api_events.json")
        |> Jason.decode!()
        |> Map.fetch!("events")

      RM.Config.get("current_season")
      |> FIRST.update_events_from_ftc_events(input)

      events = RM.Repo.all(RM.FIRST.Event)
      region_id = region.id
      league_id = league.id

      events
      |> assert_match_in(%FIRST.Event{
        league_id: nil,
        name: "Florida Championship",
        region_id: ^region_id,
        type: :regional_championship
      })
      |> assert_match_in(%FIRST.Event{
        league_id: ^league_id,
        name: "FL Orlando Robotics League Tournament",
        region_id: ^region_id,
        type: :league_tournament
      })
      |> assert_match_in(%FIRST.Event{
        code: "USFLFLORM1",
        league_id: ^league_id,
        name: "FL Orlando Robotics League Meet #1",
        season: 2023
      })
      |> assert_no_match_in(%FIRST.Event{code: "USIDKS"})
    end
  end
end
