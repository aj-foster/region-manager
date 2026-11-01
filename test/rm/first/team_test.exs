defmodule RM.FIRST.TeamTest do
  use ExUnit.Case, async: true

  alias RM.FIRST.Team

  describe "from_ftc_events/2" do
    test "maps FTC fields and resolves the home region" do
      region = %RM.FIRST.Region{id: Ecto.UUID.generate()}

      attrs =
        Team.from_ftc_events(
          %{
            "city" => "Orlando",
            "country" => "USA",
            "displayLocation" => "Orlando, Florida",
            "displayTeamNumber" => "00123",
            "homeRegion" => "USFL",
            "nameFull" => "Full name",
            "nameShort" => "Short name",
            "robotName" => "Robot",
            "rookieYear" => 2020,
            "schoolName" => "School",
            "stateProv" => "Florida",
            "teamNumber" => 123,
            "website" => "https://example.com"
          },
          %{"USFL" => region}
        )

      assert %{
               city: "Orlando",
               display_team_number: "00123",
               name_full: "Full name",
               region_id: region_id,
               team_number: 123,
               website: "https://example.com"
             } = attrs

      assert region_id == region.id
      assert %DateTime{} = attrs.inserted_at
      assert attrs.updated_at == attrs.inserted_at
    end

    test "leaves region_id nil when the API region is unknown" do
      attrs =
        Team.from_ftc_events(
          %{
            "city" => nil,
            "country" => nil,
            "displayLocation" => nil,
            "displayTeamNumber" => "7",
            "homeRegion" => "UNKNOWN",
            "nameFull" => nil,
            "nameShort" => nil,
            "robotName" => nil,
            "rookieYear" => nil,
            "schoolName" => nil,
            "stateProv" => nil,
            "teamNumber" => 7,
            "website" => nil
          },
          %{}
        )

      assert attrs.region_id == nil
    end
  end
end
