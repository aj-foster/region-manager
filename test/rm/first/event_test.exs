defmodule RM.FIRST.EventTest do
  use RM.DataCase

  alias RM.FIRST.Event

  describe "from_ftc_events/3" do
    test "parses all events from the 2023 season" do
      region = Factory.insert(:region, code: "USFL")

      File.read!("test/fixture/api_events_full.json")
      |> Jason.decode!()
      |> Map.fetch!("events")
      |> Enum.map(&Event.from_ftc_events(&1, %{"USFL" => region}))
    end
  end
end
