defmodule RMWeb.LeagueLive.Proposal.New do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  alias RM.Local.Venue

  #
  # Lifecycle
  #

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}

  @impl true
  def mount(params, _session, socket) do
    socket
    |> assign(venue: nil, page_title: "Propose Event")
    |> assign_retroactive_event(params)
    |> add_venue_form()
    |> event_form()
    |> load_venues()
    |> ok()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("add_venue_change", %{"venue" => params}, socket) do
    socket
    |> add_venue_form(params)
    |> noreply()
  end

  def handle_event("add_venue_submit", %{"venue" => params}, socket) do
    socket
    |> add_venue_submit(params)
    |> noreply()
  end

  def handle_event("event_change", %{"event_proposal" => params}, socket) do
    socket
    |> event_form(params)
    |> noreply()
  end

  def handle_event("event_submit", %{"event_proposal" => params}, socket) do
    socket
    |> event_submit(params)
    |> noreply()
  end

  def handle_event("venue_change", %{"venue" => venue_id}, socket) do
    socket
    |> venue_change(venue_id)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec add_venue_form(Socket.t()) :: Socket.t()
  @spec add_venue_form(Socket.t(), map) :: Socket.t()
  defp add_venue_form(socket, params \\ %{}) do
    params =
      params
      |> Map.put("by", socket.assigns[:current_user])
      |> Map.put("league", socket.assigns[:league])
      |> Map.put("region", socket.assigns[:region])
      |> Map.put_new("country", socket.assigns[:league].region.metadata.default_country)
      |> Map.put_new(
        "state_province",
        socket.assigns[:league].region.metadata.default_state_province
      )
      |> Map.put_new("timezone", socket.assigns[:timezone])

    form =
      if event = socket.assigns[:event] do
        Venue.retroactive_changeset(event, params)
        |> to_form()
      else
        Venue.create_changeset(params)
        |> to_form()
      end

    assign(socket, add_venue_form: form)
  end

  @spec add_venue_submit(Socket.t(), map) :: Socket.t()
  defp add_venue_submit(socket, params) do
    params =
      Map.put(params, "by", socket.assigns[:current_user])
      |> Map.put("league", socket.assigns[:league])
      |> Map.put("region", socket.assigns[:region])

    if event = socket.assigns[:event] do
      RM.Local.create_venue_from_event(event, params)
    else
      RM.Local.create_venue(params)
    end
    |> case do
      {:ok, venue} ->
        socket
        |> push_js("#add-venue-modal", "data-cancel")
        |> put_flash(:info, "Venue added successfully")
        |> load_venues()
        |> assign(venue: venue)

      {:error, changeset} ->
        assign(socket, add_venue_form: to_form(changeset))
    end
  end

  @spec assign_retroactive_event(Socket.t(), map) :: Socket.t()
  defp assign_retroactive_event(socket, %{"event" => event_id}) do
    case RM.FIRST.fetch_event_by_id(event_id, preload: [:local_league, :region, :settings]) do
      {:ok, event} -> assign(socket, event: event)
      {:error, :event, :not_found} -> assign(socket, event: nil)
    end
  end

  defp assign_retroactive_event(socket, _params), do: assign(socket, event: nil)

  @spec event_form(Socket.t()) :: Socket.t()
  @spec event_form(Socket.t(), map) :: Socket.t()
  defp event_form(socket, params \\ %{}) do
    league = socket.assigns[:league]

    params =
      params
      |> Map.put("by", socket.assigns[:current_user])
      |> Map.put("league", league)
      |> Map.put("region", league.region)
      |> Map.put("season", league.region.current_season)
      |> Map.put("venue", socket.assigns[:venue])
      |> Map.put_new("registration_settings", %{"enabled" => "true"})
      |> event_proposal_normalize_date_end()
      |> event_proposal_normalize_format()
      |> registration_settings_normalize_pool()
      |> registration_settings_normalize_team_limit()
      |> registration_settings_normalize_waitlist_limit()

    form =
      if event = socket.assigns[:event] do
        RM.Local.EventProposal.retroactive_changeset(event, params)
        |> to_form()
      else
        RM.Local.EventProposal.create_changeset(params)
        |> to_form()
      end

    assign(socket, event_form: form)
  end

  @spec event_submit(Socket.t(), map) :: Socket.t()
  def event_submit(socket, params) do
    league = socket.assigns[:league]

    params =
      params
      |> Map.put("by", socket.assigns[:current_user])
      |> Map.put("league", league)
      |> Map.put("region", league.region)
      |> Map.put("season", league.region.current_season)
      |> Map.put("venue", socket.assigns[:venue])
      |> Map.put_new("registration_settings", %{"enabled" => "true"})
      |> registration_settings_normalize_pool()
      |> registration_settings_normalize_team_limit()
      |> registration_settings_normalize_waitlist_limit()

    if event = socket.assigns[:event] do
      case RM.Local.create_proposal_from_event(event, params) do
        {:ok, _proposal} ->
          socket
          |> put_flash(:info, "Event proposal created successfully")
          |> push_navigate(to: ~p"/league/#{league.region}/#{league}/events/#{event}")

        {:error, changeset} ->
          assign(socket, event_form: to_form(changeset))
      end
    else
      case RM.Local.create_event(params) do
        {:ok, _proposal} ->
          socket
          |> put_flash(:info, "Event proposal created successfully")
          |> push_navigate(to: ~p"/league/#{league.region}/#{league}/events")

        {:error, changeset} ->
          assign(socket, event_form: to_form(changeset))
      end
    end
  end

  @spec event_proposal_normalize_date_end(map) :: map
  defp event_proposal_normalize_date_end(params) do
    if (date_start = params["date_start"]) && params["date_end"] in ["", nil] do
      put_in(params, ["date_end"], date_start)
    else
      params
    end
  end

  @spec event_proposal_normalize_format(map) :: map
  defp event_proposal_normalize_format(params) do
    cond do
      params["type"] in ["league_meet", "demo", "workshop"] ->
        Map.put(params, "format", "traditional")

      params["format"] in [nil, ""] ->
        Map.put(params, "format", "traditional")

      :else ->
        params
    end
  end

  @spec registration_settings_normalize_pool(map) :: map
  defp registration_settings_normalize_pool(params) do
    if params["type"] in ["league_meet", "league_tournament"] do
      put_in(params, ["registration_settings", "pool"], "league")
    else
      params
    end
  end

  @spec registration_settings_normalize_team_limit(map) :: map
  defp registration_settings_normalize_team_limit(
         %{"registration_settings" => %{"team_limit_enable" => "true"}} = params
       ) do
    put_in(
      params,
      ["registration_settings", "team_limit"],
      params["registration_settings"]["team_limit"] || "50"
    )
  end

  defp registration_settings_normalize_team_limit(params) do
    put_in(params, ["registration_settings", "team_limit"], nil)
  end

  @spec registration_settings_normalize_waitlist_limit(map) :: map
  defp registration_settings_normalize_waitlist_limit(
         %{"registration_settings" => %{"waitlist_limit_enable" => "true"}} = params
       ) do
    params
    |> put_in(
      ["registration_settings", "waitlist_limit"],
      params["registration_settings"]["waitlist_limit"] || "50"
    )
    |> put_in(
      ["registration_settings", "waitlist_deadline_days"],
      params["registration_settings"]["waitlist_deadline_days"] || "7"
    )
  end

  defp registration_settings_normalize_waitlist_limit(params) do
    put_in(params, ["registration_settings", "waitlist_limit"], nil)
  end

  @spec venue_change(Socket.t(), Ecto.UUID.t() | String.t()) :: Socket.t()
  defp venue_change(socket, venue_id) do
    league = socket.assigns[:league]

    if venue = Enum.find(league.venues, &(&1.id == venue_id)) do
      assign(socket, venue: venue)
    else
      assign(socket, venue: nil)
    end
  end

  #
  # Template Helpers
  #

  @spec country_options :: [{String.t(), String.t()}]
  defp country_options do
    RM.Util.Location.countries()
    |> Enum.map(&{&1, &1})
  end

  @spec event_format_options :: [{label :: String.t(), value :: String.t()}]
  defp event_format_options do
    [
      {"Traditional", "traditional"},
      {"Hybrid", "hybrid"}
    ]
  end

  @spec event_type_options :: [{String.t(), String.t()}]
  defp event_type_options do
    [
      :kickoff,
      :scrimmage,
      :league_meet,
      :league_tournament,
      :off_season,
      :workshop,
      :demo
    ]
    |> Enum.map(fn type ->
      {RM.FIRST.Event.type_name(type), to_string(type)}
    end)
  end

  @spec registration_pool_options(RM.FIRST.League.t()) :: [{String.t(), String.t()}]
  defp registration_pool_options(league) do
    [
      {"Teams in #{league.name} League", "league"},
      {"Teams in #{league.region.name}", "region"},
      {"Any Team", "all"}
    ]
  end

  @spec state_province_options(String.t()) :: [{String.t(), String.t()}]
  defp state_province_options(country_name) do
    RM.Util.Location.state_provinces(country_name)
    |> Enum.map(&{&1, &1})
  end

  @spec timezone_options(String.t()) :: [{String.t(), String.t()}]
  defp timezone_options(country_name) do
    RM.Util.Time.zones_for_country(country_name)
  end

  @spec venue_options([Venue.t()]) :: [{String.t(), Ecto.UUID.t()}]
  defp venue_options(venues) do
    for %Venue{id: id, name: name} <- venues do
      {name, id}
    end
  end
end
