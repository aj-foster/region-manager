defmodule RMWeb.DashboardLive.HomeTest do
  use RMWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RM.Account.Region, as: UserRegion
  alias RM.Local.LeagueAssignment
  alias RM.Repo

  test "loads teams without league assignments asynchronously", %{conn: conn} do
    region = Factory.insert(:region, has_leagues: true)
    other_region = Factory.insert(:region, name: "Other Region", has_leagues: true)
    user = Factory.insert(:user)
    league = Factory.insert(:league, region: region)
    assigned_team = Factory.insert(:team, region: region)
    Factory.insert(:team, region: region)

    Repo.insert!(%UserRegion{region_id: region.id, user_id: user.id})
    Repo.insert!(%UserRegion{region_id: other_region.id, user_id: user.id})
    Repo.insert!(%LeagueAssignment{league_id: league.id, team_id: assigned_team.id})

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Identity.Plug.log_in_user(user)

    {:ok, view, initial_html} = live(conn, "/dashboard")
    refute initial_html =~ "#{region.name}: 1 team needs a league assignment"
    refute initial_html =~ "Checking for pending tasks..."

    html = render_async(view)

    text =
      html
      |> Floki.text()
      |> String.replace(~r/\s+/, " ")

    assert text =~ "#{region.name} has 1 team needing a league assignment"
    assert text =~ "Click to navigate to the team page."
    refute text =~ "#{other_region.name}:"
    refute text =~ "Nothing to do."
    refute text =~ "Could not load teams without a league assignment."
    assert html =~ ~s(id="teams-without-league-#{region.id}")
    assert html =~ ~s(class="grow")
    refute html =~ "<ul"
    refute html =~ "<li"
  end

  test "shows no task notices when no regions have pending tasks", %{conn: conn} do
    region = Factory.insert(:region, has_leagues: true)
    user = Factory.insert(:user)
    league = Factory.insert(:league, region: region)
    team = Factory.insert(:team, region: region)

    Factory.insert(:first_team,
      region: region,
      season: region.current_season,
      team_number: team.number
    )

    Repo.insert!(%UserRegion{region_id: region.id, user_id: user.id})
    Repo.insert!(%LeagueAssignment{league_id: league.id, team_id: team.id})

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Identity.Plug.log_in_user(user)

    {:ok, view, _html} = live(conn, "/dashboard")

    html = render_async(view)

    text =
      html
      |> Floki.text()
      |> String.replace(~r/\s+/, " ")

    refute text =~ "Nothing to do."
    refute text =~ "#{region.name}:"
    refute html =~ "pending-task"
    refute html =~ "<ul"
    refute html =~ "<li"
  end
end
