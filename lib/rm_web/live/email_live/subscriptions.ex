defmodule RMWeb.EmailLive.Subscriptions do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  on_mount {RMWeb.EmailLive.Util, :require_current_season}
  on_mount {RMWeb.EmailLive.Util, :require_permission}
  on_mount {RMWeb.EmailLive.Util, :require_keila_records}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> subscribe_form()
    |> unsubscribe_form()
    |> ok()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, params, socket)

  def handle_event("subscribe_change", %{"addresses" => addresses}, socket) do
    socket
    |> subscribe_form(addresses: addresses)
    |> noreply()
  end

  def handle_event("subscribe", %{"addresses" => addresses}, socket) do
    socket
    |> subscribe_submit(addresses)
    |> noreply()
  end

  def handle_event("unsubscribe_change", %{"addresses" => addresses}, socket) do
    socket
    |> unsubscribe_form(addresses: addresses)
    |> noreply()
  end

  def handle_event("unsubscribe", %{"addresses" => addresses}, socket) do
    socket
    |> unsubscribe_submit(addresses)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec invalid_email?(String.t()) :: boolean
  defp invalid_email?(email) do
    not Regex.match?(~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/, email)
  end

  @spec subscribe_form(Socket.t()) :: Socket.t()
  @spec subscribe_form(Socket.t(), keyword) :: Socket.t()
  defp subscribe_form(socket, opts \\ []) do
    form = to_form(%{"addresses" => opts[:addresses]}, opts)
    assign(socket, subscribe_form: form, subscribe_success: false)
  end

  @spec subscribe_submit(Socket.t(), String.t()) :: Socket.t()
  defp subscribe_submit(socket, addresses) do
    addresses =
      addresses
      |> String.downcase()
      |> String.split(~r/[\s,]+/, trim: true)

    cond do
      addresses == [] ->
        subscribe_form(socket,
          errors: [addresses: {"Please enter at least one email address.", []}]
        )

      addr = Enum.find(addresses, &invalid_email?/1) ->
        subscribe_form(socket,
          addresses: Enum.join(addresses, "\n"),
          errors: [addresses: {"Invalid address: #{addr}", []}]
        )

      :else ->
        subscribe_emails(socket, addresses)
    end
  end

  @spec subscribe_emails(Socket.t(), [String.t()]) :: Socket.t()
  defp subscribe_emails(socket, []) do
    socket
    |> subscribe_form(addresses: nil)
    |> assign(subscribe_success: true)
    |> put_flash(:info, "Successfully subscribed all email addresses.")
  end

  defp subscribe_emails(socket, [email_string | rest]) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]

    subscription_list =
      if league do
        [league, region]
      else
        [region]
      end

    with {:ok, email} <- RM.Email.get_or_create_address(email_string),
         {:ok, _subscription} <-
           RM.Email.subscribe_email(
             email,
             "",
             region.metadata.keila_project_id,
             subscription_list
           ) do
      subscribe_emails(socket, rest)
    else
      {:error, reason} ->
        subscribe_form(socket,
          addresses: Enum.join([email_string | rest], "\n"),
          errors: [addresses: {"Failed to subscribe #{email_string}: #{inspect(reason)}", []}]
        )
    end
  end

  @spec unsubscribe_form(Socket.t()) :: Socket.t()
  @spec unsubscribe_form(Socket.t(), keyword) :: Socket.t()
  defp unsubscribe_form(socket, opts \\ []) do
    form = to_form(%{"addresses" => opts[:addresses]}, opts)
    assign(socket, unsubscribe_form: form, unsubscribe_success: false)
  end

  @spec unsubscribe_submit(Socket.t(), String.t()) :: Socket.t()
  defp unsubscribe_submit(socket, addresses) do
    addresses =
      addresses
      |> String.downcase()
      |> String.split(~r/[\s,]+/, trim: true)

    cond do
      addresses == [] ->
        unsubscribe_form(socket,
          errors: [addresses: {"Please enter at least one email address.", []}]
        )

      addr = Enum.find(addresses, &invalid_email?/1) ->
        unsubscribe_form(socket,
          addresses: Enum.join(addresses, "\n"),
          errors: [addresses: {"Invalid address: #{addr}", []}]
        )

      :else ->
        unsubscribe_emails(socket, addresses)
    end
  end

  @spec unsubscribe_emails(Socket.t(), [String.t()]) :: Socket.t()
  defp unsubscribe_emails(socket, []) do
    socket
    |> unsubscribe_form(addresses: nil)
    |> assign(unsubscribe_success: true)
    |> put_flash(:info, "Successfully unsubscribed all email addresses.")
  end

  defp unsubscribe_emails(socket, [email | rest]) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]

    case RM.Email.unsubscribe_email(email, league || region) do
      {:ok, _contact} ->
        unsubscribe_emails(socket, rest)

      {:error, :not_found} ->
        unsubscribe_emails(socket, rest)

      {:error, reason} ->
        unsubscribe_form(socket,
          addresses: Enum.join([email | rest], "\n"),
          errors: [addresses: {"Failed to unsubscribe #{email}: #{inspect(reason)}", []}]
        )
    end
  end
end
