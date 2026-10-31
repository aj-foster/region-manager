defmodule RMWeb.EventResourceControllerTest do
  use RMWeb.ConnCase

  alias RM.Account.Region, as: UserRegion
  alias RM.Local.LeagueAssignment
  alias RM.Repo

  describe "GET /s/:season/r/:region/e/:event/r/team_list.pdf" do
    test "region admins can download an event team list PDF", %{conn: conn} do
      imported_at = ~U[2026-10-30 18:15:00Z]

      region = Factory.insert(:region)

      region =
        region
        |> Ecto.Changeset.change(stats: %RM.FIRST.Region.Stats{teams_imported_at: imported_at})
        |> Repo.update!()

      event = Factory.insert(:first_event, region: region)
      team = Factory.insert(:team, region: region, name: "Robotics Team")
      RM.Local.create_event_registrations(event, [team], %{waitlisted: false})

      user = Factory.insert(:user)
      Repo.insert!(%UserRegion{region_id: region.id, user_id: user.id})

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Identity.Plug.log_in_user(user)
        |> get(
          "/s/#{region.current_season}/r/#{region.abbreviation}/e/#{event.code}/r/team_list.pdf?timezone=America%2FLos_Angeles"
        )

      assert response(conn, 200) =~ "%PDF-"
      assert get_resp_header(conn, "content-type") == ["application/pdf"]

      assert Enum.any?(
               get_resp_header(conn, "content-disposition"),
               &String.contains?(&1, "event-teams-")
             )
    end

    test "users without event resource access are redirected to the event", %{conn: conn} do
      region = Factory.insert(:region)
      event = Factory.insert(:first_event, region: region)
      user = Factory.insert(:user)

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Identity.Plug.log_in_user(user)
        |> get(
          "/s/#{region.current_season}/r/#{region.abbreviation}/e/#{event.code}/r/team_list.pdf"
        )

      assert redirected_to(conn) ==
               "/s/#{region.current_season}/r/#{String.downcase(region.abbreviation)}/e/#{String.downcase(event.code)}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not authorized to perform this action"
    end

    test "redirects unauthorized league event resources to the league event page", %{conn: conn} do
      region = Factory.insert(:region)
      league = Factory.insert(:league, region: region)
      event = Factory.insert(:first_event, region: region, local_league: league)
      user = Factory.insert(:user)

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Identity.Plug.log_in_user(user)
        |> get(
          "/s/#{region.current_season}/r/#{region.abbreviation}/l/#{league.code}/e/#{event.code}/r/team_list.pdf"
        )

      assert redirected_to(conn) ==
               "/s/#{region.current_season}/r/#{String.downcase(region.abbreviation)}/l/#{league.code}/e/#{String.downcase(event.code)}"
    end

    test "rejects an invalid season", %{conn: conn} do
      conn = get(conn, "/s/invalid/r/FL/e/USFLORS/r/team_list.pdf")

      assert response(conn, 404) == "Invalid season"
    end

    test "does not load an event from a different region", %{conn: conn} do
      region = Factory.insert(:region)
      other_region = Factory.insert(:region)
      event = Factory.insert(:first_event, region: other_region)

      conn =
        get(
          conn,
          "/s/#{other_region.current_season}/r/#{region.abbreviation}/e/#{event.code}/r/team_list.pdf"
        )

      assert response(conn, 404) == "Event not found"
    end

    test "renders a separate unregistered-team section for league events", %{conn: conn} do
      region = Factory.insert(:region)
      league = Factory.insert(:league, region: region)
      event = Factory.insert(:first_event, region: region, local_league: league)
      registered_team = Factory.insert(:team, region: region)
      unregistered_team = Factory.insert(:team, region: region)

      for team <- [registered_team, unregistered_team] do
        Repo.insert!(%LeagueAssignment{league_id: league.id, team_id: team.id})
      end

      RM.Local.create_event_registrations(event, [registered_team], %{waitlisted: false})

      user = Factory.insert(:user)
      Repo.insert!(%UserRegion{region_id: region.id, user_id: user.id})

      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> Identity.Plug.log_in_user(user)
        |> get(
          "/s/#{region.current_season}/r/#{region.abbreviation}/l/#{league.code}/e/#{event.code}/r/team_list.pdf"
        )

      assert response(conn, 200) =~ "%PDF-"
    end
  end
end
