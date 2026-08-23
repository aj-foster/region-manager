defmodule RMWeb.EmailLive.Manage do
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
  def handle_params(%{"email" => email}, _uri, socket) do
    email = email |> String.trim() |> String.downcase()
    user = socket.assigns[:current_user]
    connected_email_records = if user, do: user.emails, else: []
    confirmed_email_records = Enum.filter(connected_email_records, & &1.confirmed_at)
    connected_emails = Enum.map(connected_email_records, & &1.email)
    confirmed_emails = Enum.map(confirmed_email_records, & &1.email)

    cond do
      is_nil(user) ->
        socket
        |> put_flash(:error, "You must be logged in to manage emails.")
        |> redirect(to: ~p"/login")
        |> noreply()

      email in confirmed_emails ->
        socket
        |> assign_address_by_email(email)
        |> assign_subscriptions()
        |> noreply()

      email in connected_emails ->
        socket
        |> put_flash(:error, "Please confirm your email address before managing subscriptions.")
        |> redirect(to: ~p"/user/settings")
        |> noreply()

      :else ->
        socket
        |> put_flash(:error, "You do not have permission to manage this email address.")
        |> redirect(to: ~p"/user/settings")
        |> noreply()
    end
  end

  def handle_params(%{"hash" => hash}, _uri, socket) do
    socket
    |> assign_address_by_hash(hash)
    |> assign_subscriptions()
    |> noreply()
  end

  def handle_params(%{"project" => prj_id, "message" => msg_id, "token" => token}, _uri, socket) do
    socket
    |> assign_address_by_message(prj_id, msg_id, token)
    |> assign_subscriptions()
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

  def handle_event("subscribe_region", %{"code" => region_code}, socket) do
    email = socket.assigns.address.email

    with {:ok, region} <- Map.fetch(socket.assigns.regions_by_code, String.downcase(region_code)),
         {:ok, _contact} <- RM.Email.subscribe_email(email, "", region) do
      socket
      |> assign_subscriptions()
      |> put_flash(:info, "You have been subscribed to emails from #{region.name} Region.")
    else
      :error ->
        socket
        |> put_flash(
          :error,
          "There was an error subscribing your email address. Please contact support"
        )
    end
    |> noreply()
  end

  def handle_event("subscribe_league", %{"code" => league_code}, socket) do
    email = socket.assigns.address.email

    with {:ok, league} <- Map.fetch(socket.assigns.leagues_by_code, String.downcase(league_code)),
         {:ok, _contact} <- RM.Email.subscribe_email(email, "", league) do
      socket
      |> assign_subscriptions()
      |> put_flash(:info, "You have been subscribed to emails from #{league.name} League.")
    else
      :error ->
        socket
        |> put_flash(
          :error,
          "There was an error subscribing your email address. Please contact support"
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

  def handle_event("unsubscribe_region", %{"code" => region_code} = params, socket) do
    email = socket.assigns.address.email

    with {:ok, region} <- Map.fetch(socket.assigns.regions_by_code, String.downcase(region_code)),
         {:ok, _contact} <- RM.Email.unsubscribe_email(email, region) do
      socket = assign_subscriptions(socket)

      if params["coach"] == "true" do
        push_js(socket, "#unsubscribe-coach", "data-show")
      else
        put_flash(
          socket,
          :info,
          "You have been unsubscribed from emails for #{region.name} Region."
        )
      end
    else
      :error ->
        socket
        |> put_flash(
          :error,
          "There was an error unsubscribing your email address. Please contact support"
        )
    end
    |> noreply()
  end

  def handle_event("unsubscribe_league", %{"code" => league_code} = params, socket) do
    email = socket.assigns.address.email

    with {:ok, league} <- Map.fetch(socket.assigns.leagues_by_code, String.downcase(league_code)),
         {:ok, _contact} <- RM.Email.unsubscribe_email(email, league) do
      socket = assign_subscriptions(socket)

      if params["coach"] == "true" do
        push_js(socket, "#unsubscribe-coach", "data-show")
      else
        put_flash(
          socket,
          :info,
          "You have been unsubscribed from emails for #{league.name} League."
        )
      end
    else
      :error ->
        socket
        |> put_flash(
          :error,
          "There was an error unsubscribing your email address. Please contact support"
        )
    end
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_address_by_email(Socket.t(), String.t()) :: Socket.t()
  defp assign_address_by_email(socket, email) do
    case Email.fetch_address(email) do
      {:ok, address} ->
        assign(socket, :address, address)

      {:error, :not_found} ->
        socket
        |> put_flash(
          :error,
          "Invalid email management link. If you believe this is an error, please contact support."
        )
        |> redirect(to: ~p"/")
    end
  end

  @spec assign_address_by_hash(Socket.t(), String.t()) :: Socket.t()
  defp assign_address_by_hash(socket, hash) do
    case Email.fetch_address_by_hashed_id(hash) do
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
  end

  @spec assign_address_by_message(Socket.t(), String.t(), String.t(), String.t()) :: Socket.t()
  defp assign_address_by_message(socket, project_id, message_id, token) do
    with {:ok, project} <- Email.fetch_keila_project(project_id),
         {:ok, message} <- Email.fetch_keila_message(message_id),
         {:ok, contact} <- Email.fetch_keila_contact(message.contact_id),
         :ok <- Email.validate_unsubscribe_token(project, message, token),
         {:ok, address} <- Email.fetch_address(contact.email) do
      assign(socket, :address, address)
    else
      {:error, _reason} ->
        socket
        |> put_flash(
          :error,
          "The unsubscribe link is invalid or has expired."
        )
        |> redirect(to: ~p"/")
    end
  end

  @spec assign_subscriptions(Socket.t()) :: Socket.t()
  defp assign_subscriptions(%Socket{redirected: nil} = socket) do
    email = socket.assigns.address.email

    # Future: If region count grows, refactor this.
    regions =
      RM.FIRST.list_regions()
      |> Enum.reject(fn region -> is_nil(region.metadata.keila_project_id) end)
      |> RM.Repo.preload(leagues: :settings)

    regions_by_code =
      Map.new(regions, fn region -> {String.downcase(region.code), region} end)

    leagues_by_code =
      regions
      |> Enum.flat_map(fn region ->
        Enum.map(region.leagues, fn league ->
          code = String.downcase(region.code <> String.downcase(league.code))
          league = Map.put(league, :region, region)

          {code, league}
        end)
      end)
      |> Map.new()

    regions_by_keila_project_id =
      Map.new(regions, fn region -> {region.metadata.keila_project_id, region} end)

    subscriptions =
      email
      |> Email.list_contacts_by_email()
      |> Enum.map(fn contact ->
        region = Map.fetch!(regions_by_keila_project_id, contact.project_id)
        region_code = String.downcase(region.code)
        season = to_string(region.current_season)
        last_season = to_string(region.current_season - 1)

        region_subscribed? = contact.data[region_code]["sub"] == "true"
        region_coach? = contact.data[region_code]["coach"][season] == "true"
        region_previous_coach? = contact.data[region_code]["coach"][last_season] == "true"

        leagues =
          region.leagues
          |> Enum.filter(&(&1.settings && &1.settings.enable_email))
          |> Enum.map(fn league ->
            league_code = region_code <> String.downcase(league.code)

            league_subscribed? = contact.data[league_code]["sub"] == "true"
            league_coach? = contact.data[league_code]["coach"][season] == "true"
            league_previous_coach? = contact.data[league_code]["coach"][last_season] == "true"

            %{
              league: league,
              league_subscribed?: league_subscribed?,
              league_coach?: league_coach?,
              league_previous_coach?: league_previous_coach?
            }
          end)
          |> Enum.sort_by(& &1.league.name)

        %{
          contact: contact,
          region: region,
          region_coach?: region_coach?,
          region_previous_coach?: region_previous_coach?,
          region_subscribed?: region_subscribed?,
          leagues: leagues
        }
      end)
      |> Enum.sort_by(& &1.region.name)

    assign(socket,
      leagues_by_code: leagues_by_code,
      regions_by_code: regions_by_code,
      subscriptions: subscriptions
    )
  end

  defp assign_subscriptions(socket), do: socket

  #
  # Template
  #

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
