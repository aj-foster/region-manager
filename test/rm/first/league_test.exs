defmodule RM.FIRST.LeagueTest do
  use RM.DataCase

  alias RM.FIRST.League

  describe "from_ftc_events/4" do
    test "resolves related records and treats a missing remote flag as false" do
      region = %RM.FIRST.Region{id: Ecto.UUID.generate()}
      local_league = %RM.Local.League{id: Ecto.UUID.generate()}
      parent_id = Ecto.UUID.generate()

      attrs =
        League.from_ftc_events(
          %{
            "code" => "CHAMP",
            "location" => "Main Hall",
            "name" => "Championship",
            "parentLeagueCode" => "PARENT",
            "region" => "USFL",
            "remote" => nil
          },
          %{"USFL" => region},
          %{{"USFL", "CHAMP"} => local_league},
          %{"PARENT" => parent_id}
        )

      assert attrs.region_id == region.id
      assert attrs.local_league_id == local_league.id
      assert attrs.parent_league_id == parent_id
      assert attrs.remote == false
      assert attrs.code == "CHAMP"
      assert attrs.inserted_at == attrs.updated_at
    end

    test "allows missing region and parent mappings and preserves true remote flag" do
      attrs =
        League.from_ftc_events(
          %{
            "code" => "REMOTE",
            "location" => nil,
            "name" => "Remote League",
            "parentLeagueCode" => "MISSING",
            "region" => "MISSING",
            "remote" => true
          },
          %{},
          %{}
        )

      assert attrs.region_id == nil
      assert attrs.local_league_id == nil
      assert attrs.parent_league_id == nil
      assert attrs.remote
    end
  end

  describe "compare/2" do
    test "sorts leagues by name and treats equal names as equivalent" do
      assert League.compare(%League{name: "Alpha"}, %League{name: "Beta"}) == :lt
      assert League.compare(%League{name: "Beta"}, %League{name: "Alpha"}) == :gt
      assert League.compare(%League{name: "Same"}, %League{name: "Same"}) == :eq
    end
  end

  test "serializes the league code as a lowercase route parameter" do
    assert Phoenix.Param.to_param(%League{code: "FLOR"}) == "flor"
  end
end
