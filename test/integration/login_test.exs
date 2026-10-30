defmodule RMWeb.Integration.LoginTest do
  use RMWeb.ConnCase

  test "shows a generic error when login credentials are unknown", %{conn: conn} do
    {conn, login_document} = visit_login_form(conn)

    assert Floki.find(login_document, "input[name='session[email]'][type='email']") != []
    assert Floki.find(login_document, "input[name='session[password]'][type='password']") != []
    assert Floki.find(login_document, "input[name='session[remember_me]'][type='checkbox']") != []

    [login_action] =
      login_document
      |> Floki.find("form")
      |> Floki.attribute("action")

    conn =
      post(conn, login_action,
        session: %{
          email: "unknown@example.com",
          password: "incorrect-password"
        }
      )

    assert html_response(conn, 200) =~ "Invalid e-mail or password"
  end

  test "redirects to the dashboard when login credentials are valid", %{conn: conn} do
    email = "valid@example.com"
    password = "correct-horse-battery"

    assert {:ok, _user} =
             RM.Account.create_user(%{email: email, password: password, name: "Test User"})

    {conn, login_document} = visit_login_form(conn)
    [login_action] = Floki.attribute(Floki.find(login_document, "form"), "action")

    conn =
      post(conn, login_action,
        session: %{
          email: email,
          password: password
        }
      )

    assert redirected_to(conn) == "/dashboard"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Successfully logged in"
  end

  defp visit_login_form(conn) do
    home_html = conn |> get(~p"/") |> html_response(200)

    login_link =
      home_html
      |> Floki.parse_document!()
      |> Floki.find("a[href='/login']")
      |> Enum.find(&(Floki.text(&1) =~ "Log In"))

    assert login_link
    [login_path] = Floki.attribute(login_link, "href")

    login_html = conn |> get(login_path) |> html_response(200)
    assert login_html =~ "Log in"

    {conn, Floki.parse_document!(login_html)}
  end
end
