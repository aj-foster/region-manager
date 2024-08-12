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

      # Removed event to be resurrected
      Factory.insert(:first_event, code: "USFLFLORM2", season: 2023)

      FIRST.update_events_from_ftc_events(2023, fixture_events())

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
        removed_at: nil,
        type: :league_tournament
      })
      |> assert_match_in(%FIRST.Event{
        code: "USFLFLORM1",
        league_id: ^league_id,
        name: "FL Orlando Robotics League Meet #1",
        region_id: ^region_id,
        removed_at: nil,
        season: 2023
      })
      |> assert_match_in(%FIRST.Event{
        code: "USFLFLORM2",
        league_id: ^league_id,
        name: "FL Orlando Robotics League Meet #2",
        region_id: ^region_id,
        removed_at: nil,
        season: 2023
      })
      |> assert_match_in(%FIRST.Event{code: "USIDKS", removed_at: %DateTime{}})
    end

    test "matches event proposals" do
      region = Factory.insert(:region, code: "USFL")
      Factory.insert(:first_league, region: region, code: "FLOR")
      date = Date.new!(2023, 10, 14)

      proposal =
        Factory.insert(:event_proposal,
          date_end: date,
          date_start: date,
          name: "Orlando Scrimmage",
          region: region,
          season: 2023,
          type: :scrimmage,
          venue: Factory.build(:venue, city: "Orlando", state_province: "Florida")
        )

      FIRST.update_events_from_ftc_events(2023, fixture_events())

      Repo.reload!(proposal)
      |> assert_match(%RM.Local.EventProposal{first_event_id: <<_::binary>> = event_id})

      Repo.get(RM.FIRST.Event, event_id)
      |> assert_match(%RM.FIRST.Event{code: "USFLORS"})
    end
  end

  defp fixture_events do
    File.read!("test/fixture/api_events.json")
    |> Jason.decode!()
    |> Map.fetch!("events")
  end
end
