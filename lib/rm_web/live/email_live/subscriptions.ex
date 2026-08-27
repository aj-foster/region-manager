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

  #
  # Helpers
  #

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

  @spec invalid_email?(String.t()) :: boolean
  defp invalid_email?(email) do
    not Regex.match?(~r/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/, email)
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
end
