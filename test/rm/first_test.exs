defmodule RM.FIRSTTest do
  use RM.DataCase

  alias RM.FIRST

  describe "update_events_from_ftc_events/2" do
    test "inserts, updates, and removes events" do
      region = Factory.insert(:region, code: "USFL")
      league = Factory.insert(:first_league, region: region, code: "FLOR", season: 2023)

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
      Factory.insert(:first_league, region: region, code: "FLOR", season: 2023)
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

    test "propagates league assignments from proposals" do
      region = Factory.insert(:region, code: "USFL")
      league = Factory.insert(:league, code: "FLOR", region: region)
      Factory.insert(:first_league, region: region, code: "FLOR", season: 2023)
      date = Date.new!(2023, 10, 14)
      league_id = league.id

      proposal =
        Factory.insert(:event_proposal,
          date_end: date,
          date_start: date,
          league: league,
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
      |> assert_match(%RM.FIRST.Event{local_league_id: ^league_id})
    end

    test "uses proposal registration settings, then league registration settings, then defaults" do
      region = Factory.insert(:region, code: "USFL")

      league =
        Factory.insert(:league, code: "FLOR", region: region)
        |> Factory.with_league_settings(registration: %{open_days: 222})

      Factory.insert(:first_league, region: region, code: "FLOR", season: 2023)
      date = Date.new!(2023, 10, 14)

      proposal =
        Factory.insert(:event_proposal,
          date_end: date,
          date_start: date,
          league: league,
          name: "Orlando Scrimmage",
          region: region,
          season: 2023,
          registration_settings: %{open_days: 333},
          type: :scrimmage,
          venue: Factory.build(:venue, city: "Orlando", state_province: "Florida")
        )

      events = FIRST.update_events_from_ftc_events(2023, fixture_events())

      Repo.reload!(proposal)
      |> assert_match(%RM.Local.EventProposal{first_event_id: <<_::binary>> = event_id})

      Repo.get(RM.FIRST.Event, event_id)
      |> Repo.preload(:settings)
      |> assert_match(%RM.FIRST.Event{settings: %{registration: %{open_days: 333}}})

      league_event_no_proposal = Enum.find(events, &(&1.code == "USFLFLORLT"))

      Repo.get(RM.FIRST.Event, league_event_no_proposal.id)
      |> Repo.preload(:settings)
      |> assert_match(%RM.FIRST.Event{settings: %{registration: %{open_days: 222}}})
    end
  end

  defp fixture_events do
    File.read!("test/fixture/api_events.json")
    |> Jason.decode!()
    |> Map.fetch!("events")
  end
end
