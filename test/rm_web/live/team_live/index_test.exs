defmodule RMWeb.TeamLive.IndexTest do
  use RMWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RM.Account.Region, as: UserRegion
  alias RM.Local.LeagueAssignment
  alias RM.Repo

  test "region admins see active teams needing league assignments only on the region page", %{
    conn: conn
  } do
    region = Factory.insert(:region, has_leagues: true)
    league = Factory.insert(:league, region: region)
    assigned_team = Factory.insert(:team, region: region)
    unassigned_team = Factory.insert(:team, region: region)

    Factory.insert(:team, region: region, active: false)
    Factory.insert(:team, region: region, hidden_at: DateTime.utc_now())

    Repo.insert!(%LeagueAssignment{league_id: league.id, team_id: assigned_team.id})

    user = Factory.insert(:user)
    Repo.insert!(%UserRegion{region_id: region.id, user_id: user.id})

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Identity.Plug.log_in_user(user)

    region_path = "/s/#{region.current_season}/r/#{region.abbreviation}/teams"
    {:ok, region_view, html} = live(conn, region_path)

    assert html =~ "Awaiting League Assignment (1)"

    section_text =
      html
      |> Floki.parse_document!()
      |> Floki.find("#teams-needing-league-assignments")
      |> Floki.text()

    assert section_text =~ "#{unassigned_team.number}"
    refute section_text =~ "#{assigned_team.number}"

    league_path = "/s/#{region.current_season}/r/#{region.abbreviation}/l/#{league.code}/teams"
    {:ok, league_view, league_html} = live(conn, league_path)

    refute league_html =~ "Awaiting League Assignment"
    assert render(region_view) =~ "Awaiting League Assignment (1)"
    assert render(league_view) =~ "#{assigned_team.number}"
  end

  test "users without region assignment permission do not see the section", %{conn: conn} do
    region = Factory.insert(:region, has_leagues: true)
    Factory.insert(:team, region: region)
    user = Factory.insert(:user)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Identity.Plug.log_in_user(user)

    path = "/s/#{region.current_season}/r/#{region.abbreviation}/teams"
    {:ok, _view, html} = live(conn, path)

    refute html =~ "Awaiting League Assignment"
  end

  test "inactive lists opt into query state without changing the host LiveView", %{conn: conn} do
    region = Factory.insert(:region)
    Factory.insert(:team, region: region, active: false, intend_to_return: true)
    user = Factory.insert(:user)
    Repo.insert!(%UserRegion{region_id: region.id, user_id: user.id})

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Identity.Plug.log_in_user(user)

    path = "/s/#{region.current_season}/r/#{region.abbreviation}/teams"
    {:ok, view, _html} = live(conn, path <> "?inactive=true")

    assert has_element?(
             view,
             "#reveal-returning-toggle[phx-hook=QueryReveal][data-query-param=returning]"
           )

    assert has_element?(
             view,
             "#reveal-inactive-toggle[phx-hook=QueryReveal][data-query-param=inactive]"
           )

    assert has_element?(view, "#reveal-inactive-toggle[data-reveal-show][data-reveal-hide]")
    assert render_patch(view, path) =~ "reveal-inactive-toggle"
    assert render_patch(view, path <> "?inactive=true") =~ "reveal-inactive-toggle"

    {:ok, unauthorized_view, _html} =
      live(build_conn(), path <> "?inactive=true&returning=true")

    refute has_element?(unauthorized_view, "[phx-hook=QueryReveal]")
  end
end
