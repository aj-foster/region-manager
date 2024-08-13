defmodule RMWeb.RegionControllerTest do
  use RMWeb.ConnCase

  setup :create_region
  setup :create_seasons

  describe "GET /api/r/:region" do
    test "returns region information", %{conn: conn} do
      conn
      |> get(~p"/api/r/FL")
      |> assert_success()
      |> assert_match(%{
        "abbreviation" => "FL",
        "name" => "Florida"
      })
    end

    test "looks up region by FTC Events API code", %{conn: conn} do
      conn
      |> get(~p"/api/r/USFL")
      |> assert_success()
      |> assert_match(%{
        "abbreviation" => "FL",
        "name" => "Florida"
      })
    end
  end

  describe "GET /api/s/:season/r/:region" do
    test "returns region information", %{conn: conn} do
      conn
      |> get(~p"/api/s/2023/r/FL")
      |> assert_success()
      |> assert_match(%{
        "abbreviation" => "FL",
        "name" => "Florida"
      })
    end
  end

  describe "GET /api/r/:region/events" do
    test "returns events for the current season", %{conn: conn, region: region} do
      Factory.insert(:first_event, code: "USFLORS", region: region, season: 2024)
      |> Factory.with_event_settings()

      conn
      |> get(~p"/api/r/FL/events")
      |> assert_success()
      |> assert_match(%{
        "events" => [
          %{
            "code" => "USFLORS",
            "date_end" => _,
            "date_start" => _,
            "format" => "Traditional",
            "name" => _,
            "season" => 2024,
            "type" => "Scrimmage",
            "location" => %{},
            "registration" => %{}
          }
        ],
        "event_count" => 1
      })
    end
  end

  describe "GET /api/s/:season/r/:region/events" do
    test "returns events for a chosen season", %{conn: conn, region: region} do
      Factory.insert(:first_event, code: "USFLORS", region: region, season: 2023)
      |> Factory.with_event_settings()

      conn
      |> get(~p"/api/s/2023/r/FL/events")
      |> assert_success()
      |> assert_match(%{
        "events" => [
          %{
            "code" => "USFLORS",
            "date_end" => _,
            "date_start" => _,
            "format" => "Traditional",
            "name" => _,
            "season" => 2023,
            "type" => "Scrimmage",
            "location" => %{},
            "registration" => %{}
          }
        ],
        "event_count" => 1
      })
    end
  end

  describe "GET /api/r/:region/leagues" do
    test "returns leagues for the current season", %{conn: conn, region: region} do
      Factory.insert(:league, code: "FLOR", name: "Orlando Robotics", region: region)

      Factory.insert(:first_league,
        code: "FLOR",
        name: "Florida Orlando Robotics League",
        region: region,
        season: 2023
      )

      conn
      |> get(~p"/api/r/FL/leagues")
      |> assert_success()
      |> assert_match(%{
        "leagues" => [
          %{
            "code" => "FLOR",
            "location" => _,
            "name" => "Orlando Robotics",
            "remote" => false,
            "stats" => %{}
          }
        ],
        "league_count" => 1
      })
    end
  end

  describe "GET /api/s/:season/r/:region/leagues" do
    test "returns leagues for a chosen season", %{conn: conn, region: region} do
      Factory.insert(:league, code: "FLOR", name: "Orlando Robotics", region: region)

      Factory.insert(:first_league,
        code: "FLOR",
        name: "Florida Orlando Robotics League",
        region: region,
        season: 2023
      )

      conn
      |> get(~p"/api/s/2023/r/FL/leagues")
      |> assert_success()
      |> assert_match(%{
        "leagues" => [
          %{
            "code" => "FLOR",
            "location" => _,
            "name" => "Orlando Robotics",
            "remote" => false,
            "stats" => %{}
          }
        ],
        "league_count" => 1
      })
    end
  end

  describe "GET /api/r/:region/teams" do
    test "returns active teams for the current season", %{conn: conn, region: region} do
      Factory.insert(:team, active: true, number: 1111, region: region)
      Factory.insert(:team, active: false, number: 2222, region: region)

      conn
      |> get(~p"/api/r/FL/teams")
      |> assert_success()
      |> assert_match(%{
        "teams" => [
          %{
            "league" => nil,
            "number" => 1111
          }
        ],
        "team_count" => 1
      })
    end

    test "returns league assignments", %{conn: conn, region: region} do
      team = Factory.insert(:team, number: 1111, region: region)
      %{league: %{name: league_name}} = Factory.insert(:league_assignment, team: team)

      conn
      |> get(~p"/api/r/FL/teams")
      |> assert_success()
      |> assert_match(%{
        "teams" => [
          %{
            "league" => %{"name" => ^league_name},
            "number" => 1111
          }
        ],
        "team_count" => 1
      })
    end
  end

  describe "GET /api/s/:season/r/:region/teams" do
    test "returns teams for a chosen season", %{conn: conn, region: region} do
      Factory.insert(:first_team, team_number: 1111, region: region, season: 2023)
      Factory.insert(:team, number: 2222, region: region)

      conn
      |> get(~p"/api/s/2023/r/FL/teams")
      |> assert_success()
      |> assert_match(%{
        "teams" => [
          %{"number" => 1111}
        ],
        "team_count" => 1
      })
    end

    test "returns league assignments", %{conn: conn, region: region} do
      team = Factory.insert(:first_team, team_number: 1111, region: region, season: 2023)
      %{league: %{name: league_name}} = Factory.insert(:first_league_assignment, team: team)

      conn
      |> get(~p"/api/s/2023/r/FL/teams")
      |> assert_success()
      |> assert_match(%{
        "teams" => [
          %{
            "league" => %{"name" => ^league_name},
            "number" => 1111
          }
        ],
        "team_count" => 1
      })
    end
  end
end
