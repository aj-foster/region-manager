defmodule RMWeb.UserLive.Settings do
  use RMWeb, :live_view
  require Logger

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns[:current_user]

    socket
    |> assign(
      add_email_changeset: Identity.create_email_changeset(),
      delete_email_error: nil,
      delete_email_param: nil,
      resend_email_param: nil,
      email_count: length(user.emails),
      email_confirmed_count: Enum.count(user.emails, fn e -> not is_nil(e.confirmed_at) end)
    )
    |> ok()
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

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

  def handle_event("resend_email_init", %{"email" => email}, socket) do
    user = socket.assigns[:current_user]

    if email_struct = Enum.find(user.emails, &(&1.email == email)) do
      socket
      |> assign(resend_email_param: email_struct)
      |> push_js("#user-settings-resend-email-modal", "data-show")
      |> noreply()
    else
      socket
      |> assign(resend_email_param: nil)
      |> put_flash(:error, "Unable to find the requested email; please try again.")
      |> refresh_user()
      |> noreply()
    end
  end

  def handle_event("resend_email_submit", _unsigned_params, socket) do
    socket
    |> resend_email()
    |> noreply()
  end

  #
  # Helpers
  #

  @spec add_email(Socket.t(), map) :: Socket.t()
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

  @spec delete_email(Socket.t(), String.t()) :: Socket.t()
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

  @spec resend_email(Socket.t()) :: Socket.t()
  defp resend_email(socket) do
    email = socket.assigns[:resend_email_param]
    token_url = fn token -> ~p"/user/email/#{token}" end

    case Identity.regenerate_email(email, token_url: token_url) do
      :ok ->
        socket
        |> push_js("#user-settings-resend-email-modal", "data-cancel")
        |> put_flash(:info, "Please check your inbox for a confirmation email")
        |> refresh_user()

      {:error, reason} ->
        Logger.error("Error while resending confirmation email: #{inspect(reason)}")

        socket
        |> push_js("#user-settings-resend-email-modal", "data-cancel")
        |> put_flash(:error, "An unexpected error occurred. Please try again.")
    end
  end
end
