defmodule RMWeb.Integration.RegistrationTest do
  use RMWeb.ConnCase

  test "denies registration for an unrecognized email address", %{conn: conn} do
    {conn, registration_form} = visit_registration_form(conn)
    [registration_action] = Floki.attribute(registration_form, "action")

    conn =
      post(conn, registration_action,
        user: %{
          name: "Test User",
          email: "unknown@example.com",
          password: "correct-horse-battery"
        }
      )

    assert redirected_to(conn) == "/register/error"

    conn = get(conn, redirected_to(conn))
    assert html_response(conn, 200) =~ "Email not recognized"
    assert html_response(conn, 200) =~ "we did not recognize the email address"
  end

  test "registers a user with a recognized email address", %{conn: conn} do
    email = "known@example.com"
    Factory.insert(:address, email: email)

    assert_registration_allowed(conn, email)
  end

  test "allows event directors to register", %{conn: conn} do
    email = "director@example.com"
    region = Factory.insert(:region)
    venue = Factory.insert(:venue, region: region, league: nil)

    assert {:ok, _proposal} =
             RM.Local.create_event(%{
               "contact" => %{
                 "email" => email,
                 "name" => "Event Director",
                 "phone" => "123-456-7890"
               },
               "date_end" => Date.utc_today(),
               "date_start" => Date.utc_today(),
               "format" => "traditional",
               "name" => "Proposed Event",
               "region" => region,
               "season" => region.current_season,
               "type" => "scrimmage",
               "venue" => venue
             })

    assert RM.Email.known_address?(email)
    assert_registration_allowed(conn, email)
  end

  defp assert_registration_allowed(conn, email) do
    {conn, registration_form} = visit_registration_form(conn)
    [registration_action] = Floki.attribute(registration_form, "action")

    conn =
      post(conn, registration_action,
        user: %{
          name: "Test User",
          email: email,
          password: "correct-horse-battery"
        }
      )

    assert redirected_to(conn) == "/register/post"

    conn = get(conn, redirected_to(conn))

    assert html_response(conn, 200) =~
             "A link to confirm your email has been sent to your address."
  end

  defp visit_registration_form(conn) do
    registration_html = conn |> get(~p"/register") |> html_response(200)
    assert registration_html =~ "Create an account"

    {conn, Floki.parse_document!(registration_html) |> Floki.find("form")}
  end
end
