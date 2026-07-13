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
  def handle_params(%{"email" => hashed_id}, _uri, socket) do
    socket
    |> assign_address(hashed_id)
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

  @spec assign_address(Socket.t(), String.t()) :: Socket.t()
  defp assign_address(socket, hashed_id) do
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
  end

  @spec assign_subscriptions(Socket.t()) :: Socket.t()
  defp assign_subscriptions(socket) do
    email = socket.assigns.address.email

    # Future: If region count grows, refactor this.
    regions =
      RM.FIRST.list_regions()
      |> Enum.reject(fn region -> is_nil(region.metadata.keila_project_id) end)
      |> RM.Repo.preload(:leagues)

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
