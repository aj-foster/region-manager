defmodule RMWeb.EmailLive.Index do
  use RMWeb, :live_view

  alias RM.Email

  #
  # Lifecycle
  #

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  @impl true
  def handle_params(%{"email" => hashed_id}, _uri, socket) do
    case Email.fetch_address_by_hashed_id(hashed_id) do
      {:ok, address} ->
        assign(socket, :address, address)

      :error ->
        socket
        |> put_flash(
          :error,
          "Invalid email management link. If you believe this is an error, please contact support."
        )
        |> redirect(to: ~p"/")
    end
    |> noreply()
  end

  def handle_params(_unsigned_params, _uri, socket) do
    socket
    |> put_flash(
      :error,
      "Invalid email management link. If you believe this is an error, please contact support."
    )
    |> redirect(to: ~p"/")
    |> noreply()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("resubscribe", _params, socket) do
    case RM.Email.resubscribe_address(socket.assigns.address) do
      {:ok, address} ->
        socket
        |> assign(:address, address)
        |> put_flash(
          :info,
          "You have been resubscribed to receiving emails from Region Manager."
        )

      {:error, _changeset} ->
        socket
        |> put_flash(
          :error,
          "There was an error resubscribing your email address. Please contact support"
        )
    end
    |> noreply()
  end

  def handle_event("unsubscribe", _params, socket) do
    case RM.Email.mark_email_undeliverable(socket.assigns.address.email, :unsubscribe) do
      {:ok, address} ->
        socket
        |> assign(:address, address)
        |> put_flash(
          :info,
          "You have been unsubscribed from receiving any emails from Region Manager."
        )

      {:error, _changeset} ->
        socket
        |> put_flash(
          :error,
          "There was an error unsubscribing your email address. Please contact support"
        )
    end
    |> noreply()
  end

  #
  # Template
  #

  @impl true
  def render(assigns) do
    ~H"""
    <.title class="mb-4">Manage Emails</.title>

    <.warning :if={@address.unsubscribed_at} class="mb-4">
      This email address has been unsubscribed from receiving any emails from Region Manager.
      This includes messages from region, league, and event administrators.
    </.warning>

    <.warning :if={not @address.sendable and is_nil(@address.unsubscribed_at)} class="mb-4">
      This email address cannot receive messages due to previous bounced emails.
      If you believe this is in error, please contact support.
    </.warning>

    <.card>
      <.table class="mb-8">
        <:row title="Address">
          {redact_email_address(@address.email)}
        </:row>
        <:row title="Status">
          <%= cond do %>
            <% @address.complained_at -> %>
              <span class="text-orange-600">Email Sending Disabled (Reported as Spam)</span>
            <% @address.permanently_bounced_at -> %>
              <span class="text-orange-600">Email Sending Disabled (Permanently Bounced)</span>
            <% @address.unsubscribed_at -> %>
              <span class="text-orange-600">
                Unsubscribed {format_date(@address.unsubscribed_at, :date)}
              </span>
            <% not @address.sendable -> %>
              <span class="text-orange-600">Email Sending Disabled (Bounced Messages)</span>
            <% :else -> %>
              <span class="text-green-600">Able to Receive Messages</span>
          <% end %>
        </:row>
      </.table>

      <div :if={is_nil(@address.unsubscribed_at)}>
        <p class="mb-4 text-sm">
          If you no longer wish to receive any emails from Region Manager, including messages from
          region, league, and event administrators, you can unsubscribe here:
        </p>
        <p>
          <.button
            phx-click="unsubscribe"
            phx-disable-with="Unsubscribing..."
          >
            Unsubscribe from Emails
          </.button>
        </p>
      </div>
      <div :if={@address.unsubscribed_at}>
        <p class="mb-4 text-sm">
          If you wish to allow emails from Region Manager to be sent to this address again, you can
          resubscribe here:
        </p>
        <p>
          <.button
            phx-click="resubscribe"
            phx-disable-with="Resubscribing..."
          >
            Resubscribe to Emails
          </.button>
        </p>
      </div>
    </.card>
    """
  end

  defp redact_email_address(address) do
    case String.split(address, "@") do
      [<<_local_part::binary-size(1)>>, domain] ->
        "•@" <> domain

      [<<local_part::binary-size(2)>>, domain] ->
        local_part_first = String.at(local_part, 0)
        local_part_first <> "•@" <> domain

      [<<local_part::binary>>, domain] ->
        local_length = String.length(local_part)

        redacted_local =
          local_part
          |> String.graphemes()
          |> Enum.with_index()
          |> Enum.map(fn {char, index} ->
            if index == 0 or index == local_length - 1 do
              char
            else
              "•"
            end
          end)

        Enum.join([redacted_local, "@", domain])

      _ ->
        "Unknown Address"
    end
  end
end
