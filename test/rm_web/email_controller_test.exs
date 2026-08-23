defmodule RMWeb.EmailControllerTest do
  use RMWeb.ConnCase, async: true

  alias RM.Email

  describe "unsubscribe/2" do
    test "unsubscribes and renders message for unknown address record", %{conn: conn} do
      region = Factory.insert(:region) |> Factory.with_keila()
      project = Email.get_keila_project(region)
      contact = Factory.insert_keila_contact(project, "test-unsub@example.com")
      campaign = Factory.insert_keila_campaign(region)
      message = Factory.insert_keila_message(campaign, contact)
      token = Email.unsubscribe_token(project, message)

      conn = post(conn, ~p"/email/unsub/#{project.id}/#{message.id}/#{token}")
      assert html_response(conn, 200) =~ "You have been unsubscribed"

      assert address = Email.get_address("test-unsub@example.com")
      assert address.unsubscribed_at
      refute address.sendable
    end

    test "unsubscribes and renders message for known address record", %{conn: conn} do
      address = Factory.insert(:address, email: "test-unsub@example.com")

      region = Factory.insert(:region) |> Factory.with_keila()
      project = Email.get_keila_project(region)
      contact = Factory.insert_keila_contact(project, "test-unsub@example.com")
      campaign = Factory.insert_keila_campaign(region)
      message = Factory.insert_keila_message(campaign, contact)
      token = Email.unsubscribe_token(project, message)

      conn = post(conn, ~p"/email/unsub/#{project.id}/#{message.id}/#{token}")
      assert html_response(conn, 200) =~ "You have been unsubscribed"

      assert address = RM.Repo.reload!(address)
      assert address.unsubscribed_at
      refute address.sendable
    end
  end
end
