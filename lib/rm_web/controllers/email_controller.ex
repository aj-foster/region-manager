defmodule RMWeb.EmailController do
  use RMWeb, :controller

  alias RM.Email

  @doc """
  POST /email/unsub/:project/:message/:token

  Automated unsubscribe endpoint for email messages sent via Keila. This endpoint is used by the
  unsubscribe link in the email headers. The related GET endpoint is a LiveView with additional
  subscription management features.
  """
  def unsubscribe(conn, %{"project" => project_id, "message" => message_id, "token" => token}) do
    conn = assign(conn, success: false, error: nil)

    with {:ok, project} <- Email.fetch_keila_project(project_id),
         {:ok, message} <- Email.fetch_keila_message(message_id),
         {:ok, contact} <- Email.fetch_keila_contact(message.contact_id),
         :ok <- Email.validate_unsubscribe_token(project, message, token),
         {:ok, _address} <- Email.mark_email_undeliverable(contact.email, :unsubscribe) do
      conn
      |> assign(success: true)
      |> render("unsubscribe.html")
    else
      {:error, %Ecto.Changeset{}} ->
        conn
        |> assign(:error, "There was an error unsubscribing your email address.")
        |> render("unsubscribe.html")

      {:error, _reason} ->
        conn
        |> assign(:error, "The unsubscribe link is invalid or has expired.")
        |> render("unsubscribe.html")
    end
  end
end
