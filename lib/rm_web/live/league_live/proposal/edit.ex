defmodule RMWeb.LeagueLive.Proposal.Edit do
  use RMWeb, :live_view
  import RMWeb.LeagueLive.Util

  alias RM.Local.Venue

  #
  # Lifecycle
  #

  on_mount {RMWeb.LeagueLive.Util, :preload_league}
  on_mount {RMWeb.LeagueLive.Util, :require_league_manager}
  on_mount {__MODULE__, :preload_proposal}

  @impl true
  def mount(_params, _session, socket) do
    proposal = socket.assigns[:proposal]

    socket
    |> assign(venue: proposal.venue)
    |> add_venue_form()
    |> proposal_form()
    |> load_venues()
    |> ok()
  end

  def on_mount(:preload_proposal, %{"event" => id}, _session, socket) do
    league = socket.assigns[:league]

    case RM.Local.fetch_event_proposal_by_id(id, league: league, preload: [:event, :venue]) do
      {:ok, proposal} ->
        {:cont, assign(socket, proposal: proposal)}

      {:error, :proposal, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Event proposal not found")
          |> redirect(to: ~p"/league/#{league.region}/#{league}/events")

        {:halt, socket}
    end
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

  def handle_event("proposal_change", %{"event_proposal" => params}, socket) do
    socket
    |> proposal_form(params)
    |> noreply()
  end

  def handle_event("proposal_submit", %{"event_proposal" => params}, socket) do
    socket
    |> proposal_submit(params)
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
    league = socket.assigns[:league]

    params =
      params
      |> Map.put("by", socket.assigns[:current_user])
      |> Map.put_new("country", socket.assigns[:league].region.metadata.default_country)
      |> Map.put_new(
        "state_province",
        socket.assigns[:league].region.metadata.default_state_province
      )
      |> Map.put_new("timezone", socket.assigns[:timezone])

    form = Venue.create_changeset(league, params) |> to_form()

    assign(socket, add_venue_form: form)
  end

  @spec add_venue_submit(Socket.t(), map) :: Socket.t()
  defp add_venue_submit(socket, params) do
    league = socket.assigns[:league]
    params = Map.put(params, "by", socket.assigns[:current_user])

    case RM.Local.create_venue(league, params) do
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

  @spec proposal_form(Socket.t()) :: Socket.t()
  @spec proposal_form(Socket.t(), map) :: Socket.t()
  defp proposal_form(socket, params \\ %{}) do
    league = socket.assigns[:league]
    proposal = socket.assigns[:proposal]

    params =
      params
      |> Map.put("by", socket.assigns[:current_user])
      |> Map.put("league", league)
      |> Map.put("region", league.region)
      |> Map.put("season", league.region.current_season)
      |> Map.put("venue", socket.assigns[:venue])
      |> Map.put_new("registration_settings", %{"enabled" => "true"})
      |> proposal_normalize_date_end()
      |> registration_settings_normalize_pool()
      |> registration_settings_normalize_team_limit()
      |> registration_settings_normalize_waitlist_limit()

    form = RM.Local.EventProposal.update_changeset(proposal, params) |> to_form()
    assign(socket, proposal_form: form)
  end

  @spec proposal_submit(Socket.t(), map) :: Socket.t()
  def proposal_submit(socket, params) do
    league = socket.assigns[:league]
    proposal = socket.assigns[:proposal]

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

    case RM.Local.update_event(proposal, params) do
      {:ok, _proposal} ->
        socket
        |> put_flash(:info, "Event proposal updated successfully")
        |> push_navigate(to: ~p"/league/#{league.region}/#{league}/events")

      {:error, changeset} ->
        assign(socket, proposal_form: to_form(changeset))
    end
  end

  @spec proposal_normalize_date_end(map) :: map
  defp proposal_normalize_date_end(params) do
    if (date_start = params["date_start"]) && params["date_end"] in ["", nil] do
      put_in(params, ["date_end"], date_start)
    else
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

  @spec event_format_options :: [{String.t(), String.t()}]
  defp event_format_options do
    [
      {"Traditional", "traditional"},
      {"Hybrid", "hybrid"},
      {"Remote", "remote"}
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
