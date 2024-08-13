defmodule RMWeb.MetaControllerTest do
  use RMWeb.ConnCase

  describe "GET /api/" do
    test "returns general information", %{conn: conn} do
      conn
      |> get(~p"/api/")
      |> assert_success(200)
      |> assert_match(%{
        "description" => "Welcome" <> _,
        "latest_version" => _,
        "all_versions" => ["2024-07-01" | _]
      })
    end
  end

  describe "GET /api/meta/regions" do
    test "returns region information", %{conn: conn} do
      Factory.insert(:region, code: "USFL", name: "Florida")

      conn
      |> get(~p"/api/meta/regions")
      |> assert_success(200)
      |> assert_match(%{
        "regions" => [%{"code" => "USFL", "name" => "Florida"} | _]
      })
    end
  end

  describe "GET /api/meta/seasons" do
    test "returns season information", %{conn: conn} do
      Factory.insert(:season, name: "CENTERSTAGE")

      conn
      |> get(~p"/api/meta/seasons")
      |> assert_success(200)
      |> assert_match(%{
        "current_season" => _,
        "seasons" => [%{"name" => "CENTERSTAGE"} | _],
        "season_count" => _
      })
    end
  end
end
