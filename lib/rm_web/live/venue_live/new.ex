defmodule RMWeb.VenueLive.New do
  use RMWeb, :live_view
  import RMWeb.VenueLive.Util

  @impl true
  def mount(_params, _session, socket) do
    with :ok <- require_permission(socket) do
      socket
      |> assign(page_title: "Create Venue")
      |> assign_form()
      |> ok()
    end
  end

  @spec require_permission(Socket.t()) :: :ok | Socket.t()
  defp require_permission(socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    user = socket.assigns[:current_user]

    if can?(user, :venue_create, league || region) do
      :ok
    else
      socket
      |> put_flash(:error, "You are not authorized to perform this action")
      |> redirect(to: url_for([season, region, league, :venues]))
    end
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("venue_cancel", _params, socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]

    socket
    |> push_navigate(to: url_for([season, region, league, :venues]))
    |> noreply()
  end

  def handle_event("venue_change", %{"venue" => params}, socket) do
    socket
    |> assign_form(params)
    |> noreply()
  end

  def handle_event("venue_submit", %{"venue" => params}, socket) do
    socket
    |> venue_submit(params)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_form(Socket.t()) :: Socket.t()
  @spec assign_form(Socket.t(), map) :: Socket.t()
  defp assign_form(socket, params \\ %{}) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]

    params =
      params
      |> Map.put("by", socket.assigns[:current_user])
      |> Map.put("league", league)
      |> Map.put("region", region)
      |> Map.put_new("country", region.metadata.default_country)
      |> Map.put_new("state_province", region.metadata.default_state_province)
      |> Map.put_new("timezone", socket.assigns[:timezone])

    form = RM.Local.Venue.create_changeset(params) |> to_form()

    assign(socket, venue_form: form)
  end

  @spec venue_submit(Socket.t(), map) :: Socket.t()
  defp venue_submit(socket, params) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]

    params =
      Map.put(params, "by", socket.assigns[:current_user])
      |> Map.put("league", league)
      |> Map.put("region", region)

    case RM.Local.create_venue(params) do
      {:ok, _venue} ->
        socket
        |> put_flash(:info, "Venue added successfully")
        |> push_navigate(to: url_for([season, region, league, :venues]))

      {:error, changeset} ->
        assign(socket, venue_form: to_form(changeset))
    end
  end
end
