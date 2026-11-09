defmodule RMWeb.QueryRevealTest do
  use RMWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RM.Account.Region, as: UserRegion
  alias RM.Local.EventBatch
  alias RM.Repo

  test "venue and proposal reveals accept query patches", %{conn: conn} do
    region = Factory.insert(:region)
    user = Factory.insert(:user)
    Repo.insert!(%UserRegion{region_id: region.id, user_id: user.id})

    Factory.insert(:venue, region: region, league: nil, hidden_at: DateTime.utc_now())

    Repo.insert!(%EventBatch{
      id: Ecto.UUID.generate(),
      region_id: region.id,
      generated_by: user.id,
      generated_at: DateTime.utc_now(),
      event_count: 1
    })

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Identity.Plug.log_in_user(user)

    base = "/s/#{region.current_season}/r/#{region.abbreviation}"

    for {path, param} <- [
          {base <> "/venues", "inactive"},
          {base <> "/proposals", "submissions"}
        ] do
      {:ok, view, _html} = live(conn, path <> "?#{param}=true")
      assert has_element?(view, "#reveal-#{param}-toggle[data-query-param=#{param}]")
      assert render_patch(view, path) =~ "reveal-#{param}-toggle"
      assert render_patch(view, path <> "?#{param}=true") =~ "reveal-#{param}-toggle"
    end
  end

  test "an overridden handle_params continues to control event sorting", %{conn: conn} do
    region = Factory.insert(:region, has_leagues: true)
    path = "/s/#{region.current_season}/r/#{region.abbreviation}/events"
    {:ok, view, _html} = live(conn, path <> "?sort=upcoming")

    assert has_element?(view, "[phx-click=sort_league]")
    refute has_element?(view, "[phx-click=sort_upcoming]")

    render_patch(view, path <> "?sort=league")
    assert has_element?(view, "[phx-click=sort_upcoming]")
    refute has_element?(view, "[phx-click=sort_league]")

    view |> element("[phx-click=sort_upcoming]") |> render_click()
    assert_patch(view, path <> "?sort=upcoming")
    assert has_element?(view, "[phx-click=sort_league]")
  end
end
