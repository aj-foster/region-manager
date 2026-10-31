defmodule RMWeb.EventLive.ResourcesTest do
  use RMWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RM.Account.Region, as: UserRegion
  alias RM.Repo

  test "region admins can access the resources page and team list download", %{conn: conn} do
    region = Factory.insert(:region)
    event = Factory.insert(:first_event, region: region) |> Factory.with_event_settings()
    user = Factory.insert(:user)
    Repo.insert!(%UserRegion{region_id: region.id, user_id: user.id})

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Identity.Plug.log_in_user(user)

    path =
      "/s/#{region.current_season}/r/#{region.abbreviation}/e/#{event.code}/resources"

    {:ok, _view, html} = live(conn, path)

    assert html =~ "Team Check-in List"

    page_text =
      html
      |> Floki.parse_document!()
      |> Floki.text()

    assert page_text =~ "Printable team list with \"Event Ready\" status and check-in tracking."

    href =
      html
      |> Floki.parse_document!()
      |> Floki.find("a")
      |> Enum.find_value(fn link ->
        if Floki.text(link) =~ "Team Check-in List" do
          Floki.attribute(link, "href") |> List.first()
        end
      end)

    assert href

    uri = URI.parse(href)
    assert String.ends_with?(uri.path, "/r/team_list.pdf")
    assert URI.decode_query(uri.query)["timezone"] == "Etc/UTC"
  end

  test "users without resource access cannot open the resources page", %{conn: conn} do
    region = Factory.insert(:region)
    event = Factory.insert(:first_event, region: region) |> Factory.with_event_settings()
    user = Factory.insert(:user)

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> Identity.Plug.log_in_user(user)

    path =
      "/s/#{region.current_season}/r/#{region.abbreviation}/e/#{event.code}/resources"

    assert {:error,
            {:redirect,
             %{
               to: "/",
               flash: %{"error" => "You are not authorized to perform this action"}
             }}} = live(conn, path)
  end
end
