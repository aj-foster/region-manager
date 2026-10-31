defmodule RMWeb.TeamLive.MapTest do
  use RMWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RM.Local.LeagueAssignment
  alias RM.Repo

  test "groups teams by postal code and distinguishes league assignments", %{conn: conn} do
    region = Factory.insert(:region)
    user = Factory.insert(:user)
    Repo.insert!(%RM.Account.Region{region_id: region.id, user_id: user.id})

    league_a = Factory.insert(:league, name: "League A", region: region)
    league_b = Factory.insert(:league, name: "League B", region: region)

    team_a =
      Factory.insert(:team,
        name: "Team A",
        number: 1001,
        region: region,
        location: %RM.Local.Team.Location{postal_code: " 99553 "}
      )

    team_b =
      Factory.insert(:team,
        name: "Team B",
        number: 1002,
        region: region,
        location: %RM.Local.Team.Location{postal_code: "99553"}
      )

    Factory.insert(:team,
      number: 1003,
      region: region,
      location: %RM.Local.Team.Location{postal_code: "not a postcode"}
    )

    Repo.insert!(%LeagueAssignment{team_id: team_a.id, league_id: league_a.id})
    Repo.insert!(%LeagueAssignment{team_id: team_b.id, league_id: league_b.id})

    path = "/s/#{region.current_season}/r/#{region.abbreviation}/teams/map"

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Identity.Plug.log_in_user(user)

    {:ok, _view, html} = live(conn, path)

    assert html =~ "Showing 2 active teams"

    [map] =
      html
      |> Floki.parse_document!()
      |> Floki.find("#team-map")

    [markers_json] = Floki.attribute(map, "data-markers")
    [marker] = Jason.decode!(markers_json)

    assert marker["latitude"] == 54.143
    assert marker["longitude"] == -165.7854
    assert Enum.map(marker["teams"], & &1["number"]) == [1001, 1002]
    assert Enum.map(marker["leagues"], & &1["name"]) == ["League A", "League B"]
    refute Enum.at(marker["leagues"], 0)["color"] == Enum.at(marker["leagues"], 1)["color"]
    refute html =~ "not a postcode"
    assert html =~ "List View"
    assert html =~ "Map View"
  end

  test "users without region admin access cannot view or navigate to the map", %{conn: conn} do
    region = Factory.insert(:region)
    Factory.insert(:team, region: region)
    user = Factory.insert(:user)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Identity.Plug.log_in_user(user)

    teams_path = "/s/#{region.current_season}/r/#{region.abbreviation}/teams"
    {:ok, _view, html} = live(conn, teams_path)

    refute html =~ "List View"
    refute html =~ "Map View"

    map_path = teams_path <> "/map"

    assert {:error,
            {:redirect,
             %{
               to: redirect_path,
               flash: %{"error" => "You are not authorized to view the team map."}
             }}} = live(conn, map_path)

    assert redirect_path == String.downcase(teams_path)
  end
end
