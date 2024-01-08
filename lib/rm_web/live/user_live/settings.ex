defmodule RMWeb.UserLive.Settings do
  use RMWeb, :live_view

  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]

    socket
    |> assign(
      add_email_changeset: Identity.create_email_changeset(),
      delete_email_error: nil,
      delete_email_param: nil,
      email_count: length(user.emails),
      email_confirmed_count: Enum.count(user.emails, fn e -> not is_nil(e.confirmed_at) end)
    )
    |> ok()
  end

  def handle_event("add_email_submit", unsigned_params, socket) do
    socket
    |> add_email(unsigned_params)
    |> noreply()
  end

  def handle_event("delete_email_init", %{"email" => email}, socket) do
    socket
    |> assign(delete_email_param: email)
    |> push_js("#user-settings-delete-email-modal", "data-show")
    |> noreply()
  end

  def handle_event("delete_email_submit", _unsigned_params, socket) do
    socket
    |> delete_email(socket.assigns[:delete_email_param])
    |> noreply()
  end

  defp add_email(socket, %{"email" => %{"email" => email, "password" => password}}) do
    user = socket.assigns[:current_user]
    token_url = fn token -> ~p"/user/email/#{token}" end

    case Identity.create_email_with_password(user, email, password, token_url: token_url) do
      :ok ->
        socket
        |> push_js("#user-settings-add-email-modal", "data-cancel")
        |> put_flash(:info, "A link to confirm your email has been sent to the new address.")
        |> refresh_user()

      {:error, changeset} ->
        assign(socket, add_email_changeset: changeset)
    end
  end

  defp delete_email(socket, email) do
    user = socket.assigns[:current_user]

    case Identity.delete_email(user, email) do
      :ok ->
        socket
        |> push_js("#user-settings-delete-email-modal", "data-cancel")
        |> put_flash(:info, "Email address successfully removed")
        |> refresh_user()

      {:error, :only_email} ->
        socket
        |> push_js("#user-settings-delete-email-modal", "data-cancel")
        |> put_flash(
          :error,
          "Unable to remove email address. Please confirm another address first."
        )

      {:error, :not_found} ->
        socket
        |> push_js("#user-settings-delete-email-modal", "data-cancel")
        |> put_flash(:error, "Email address not found")
    end
  end
end
