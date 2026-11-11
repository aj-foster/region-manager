defmodule RMWeb.ProposalLive.Edit do
  use RMWeb, :live_view

  import RMWeb.ProposalLive.Util, only: [upload_error_to_string: 1]

  alias RM.Local.Venue
  alias RMWeb.ProposalLive.Util

  #
  # Lifecycle
  #

  on_mount {__MODULE__, :preload_proposal}

  @impl true
  def mount(_params, _session, socket) do
    proposal = socket.assigns[:proposal]

    socket
    |> assign(venue: proposal.venue, page_title: "Update Event Proposal")
    |> assign_venues()
    |> add_venue_form()
    |> proposal_form()
    |> Util.configure_attachment_upload()
    |> ok()
  end

  def on_mount(:preload_proposal, %{"proposal" => proposal_id}, _session, socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    preloads = [:attachments, :event, :venue]
    redirect_target = url_for([season, region, league, :proposals])

    case RM.Local.fetch_event_proposal_by_id(proposal_id,
           league: league,
           region: region,
           season: season,
           preload: preloads
         ) do
      {:ok, proposal} ->
        proposal = RM.Repo.preload(proposal, [:league, first_event: :league])
        user = socket.assigns[:current_user]

        if can?(user, :proposal_update, proposal) do
          {:cont, assign(socket, proposal: proposal, page_title: proposal.name)}
        else
          socket =
            socket
            |> put_flash(:error, "You are not authorized to perform this action")
            |> redirect(to: redirect_target)

          {:halt, socket}
        end

      {:error, :proposal, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Event proposal not found")
          |> redirect(to: redirect_target)

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

  def handle_event("attachment_remove", %{"attachment" => attachment_id}, socket) do
    socket
    |> attachment_remove(attachment_id)
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

  def handle_event("upload_cancel", %{"ref" => ref}, socket) do
    socket
    |> cancel_upload(:attachment, ref)
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

    form = Venue.create_changeset(params) |> to_form()

    assign(socket, add_venue_form: form)
  end

  @spec add_venue_submit(Socket.t(), map) :: Socket.t()
  defp add_venue_submit(socket, params) do
    params =
      Map.put(params, "by", socket.assigns[:current_user])
      |> Map.put("league", socket.assigns[:local_league])
      |> Map.put("region", socket.assigns[:region])

    case RM.Local.create_venue(params) do
      {:ok, venue} ->
        socket
        |> push_js("#add-venue-modal", "data-cancel")
        |> put_flash(:info, "Venue added successfully")
        |> assign_venues()
        |> assign(venue: venue)

      {:error, changeset} ->
        assign(socket, add_venue_form: to_form(changeset))
    end
  end

  @spec assign_venues(Socket.t()) :: Socket.t()
  defp assign_venues(socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]

    if league do
      league =
        league
        |> RM.Repo.preload(:venues, force: true)
        |> Map.update!(:venues, &Enum.sort(&1, RM.Local.Venue))

      assign(socket, venues: league.venues)
    else
      region =
        region
        |> RM.Repo.preload(:venues, force: true)
        |> Map.update!(:venues, &Enum.sort(&1, RM.Local.Venue))

      assign(socket, venues: region.venues)
    end
  end

  @spec attachment_remove(Socket.t(), Ecto.UUID.t()) :: Socket.t()
  defp attachment_remove(socket, attachment_id) do
    proposal = socket.assigns[:proposal]

    if attachment = Enum.find(proposal.attachments, &(&1.id == attachment_id)) do
      case RM.Local.delete_attachment(attachment) do
        {:ok, _attachment} ->
          proposal = RM.Repo.preload(proposal, :attachments, force: true)
          assign(socket, proposal: proposal)

        {:error, _changeset} ->
          put_flash(socket, :error, "An error occurred while removing attachment")
      end
    else
      put_flash(socket, :error, "Attachment not found; please refresh and try again")
    end
  end

  @spec proposal_form(Socket.t()) :: Socket.t()
  @spec proposal_form(Socket.t(), map) :: Socket.t()
  defp proposal_form(socket, params \\ %{}) do
    proposal = socket.assigns[:proposal]
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]

    params =
      params
      |> Map.put("by", socket.assigns[:current_user])
      |> Map.put("league", league)
      |> Map.put("region", region)
      |> Map.put("season", region.current_season)
      |> Map.put("venue", socket.assigns[:venue])
      |> Map.put_new("registration_settings", %{})
      |> proposal_normalize_date_end()
      |> proposal_normalize_format()
      |> registration_settings_normalize_pool()
      |> registration_settings_normalize_team_limit()
      |> registration_settings_normalize_waitlist_limit()

    form = RM.Local.EventProposal.update_changeset(proposal, params) |> to_form()
    assign(socket, proposal_form: form)
  end

  @spec proposal_submit(Socket.t(), map) :: Socket.t()
  def proposal_submit(socket, params) do
    if Util.upload_pending_or_error?(socket.assigns.uploads) do
      put_flash(socket, :error, "Please resolve attachment errors and wait for uploads to finish")
    else
      update_proposal(socket, params)
    end
  end

  defp update_proposal(socket, params) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]

    proposal = socket.assigns[:proposal]

    params =
      params
      |> Map.put("by", socket.assigns[:current_user])
      |> Map.delete(["league", "region", "season"])
      |> Map.put("venue", socket.assigns[:venue])
      |> Map.put_new("registration_settings", %{"enabled" => "true"})
      |> registration_settings_normalize_pool()
      |> registration_settings_normalize_team_limit()
      |> registration_settings_normalize_waitlist_limit()

    case RM.Local.update_event(proposal, params) do
      {:ok, proposal} ->
        failures = Util.save_attachments(socket, proposal)

        after_success_target = url_for([season, region, league, proposal.first_event || proposal])

        socket =
          if failures == [] do
            put_flash(socket, :info, "Event proposal updated successfully")
          else
            put_flash(
              socket,
              :error,
              "Event proposal updated, but these attachments could not be saved: #{Enum.join(failures, ", ")}. Please add them by editing the proposal."
            )
          end

        push_navigate(socket, to: after_success_target)

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

  @spec proposal_normalize_format(map) :: map
  defp proposal_normalize_format(params) do
    cond do
      params["type"] in ["kickoff", "league_meet", "demo", "workshop"] ->
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
    venue = Enum.find(socket.assigns[:venues], &(&1.id == venue_id))
    assign(socket, venue: venue)
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

  @spec event_type_options(RM.Local.EventProposal.t()) :: [{String.t(), String.t()}]
  defp event_type_options(%RM.Local.EventProposal{first_event: %RM.FIRST.Event{league_id: nil}}) do
    [
      :kickoff,
      :non_advancement,
      :qualifier,
      :super_qualifier,
      :regional_championship,
      :demo_workshop
    ]
    |> Enum.map(fn type ->
      {RM.FIRST.Event.type_name(type), to_string(type)}
    end)
  end

  defp event_type_options(%RM.Local.EventProposal{first_event: nil, league_id: nil}) do
    [
      :kickoff,
      :non_advancement,
      :qualifier,
      :super_qualifier,
      :regional_championship,
      :demo_workshop
    ]
    |> Enum.map(fn type ->
      {RM.FIRST.Event.type_name(type), to_string(type)}
    end)
  end

  defp event_type_options(_proposal) do
    [
      :kickoff,
      :non_advancement,
      :league_meet,
      :league_tournament,
      :demo_workshop
    ]
    |> Enum.map(fn type ->
      {RM.FIRST.Event.type_name(type), to_string(type)}
    end)
  end

  @spec registration_pool_options(RM.FIRST.Region.t(), RM.Local.EventProposal.t()) ::
          [{String.t(), String.t()}]
  defp registration_pool_options(region, %RM.Local.EventProposal{
         first_event: %RM.FIRST.Event{league_id: nil}
       }) do
    [
      {"Teams in #{region.name}", "region"},
      {"Any Team", "all"}
    ]
  end

  defp registration_pool_options(region, %RM.Local.EventProposal{first_event: nil, league_id: nil}) do
    [
      {"Teams in #{region.name}", "region"},
      {"Any Team", "all"}
    ]
  end

  defp registration_pool_options(region, %RM.Local.EventProposal{
         first_event: %RM.FIRST.Event{league: league}
       }) do
    [
      {"Teams in #{league.name} League", "league"},
      {"Teams in #{region.name}", "region"},
      {"Any Team", "all"}
    ]
  end

  defp registration_pool_options(region, %RM.Local.EventProposal{first_event: nil, league: league}) do
    [
      {"Teams in #{league.name} League", "league"},
      {"Teams in #{region.name}", "region"},
      {"Any Team", "all"}
    ]
  end

  @spec state_province_options(String.t()) :: [{String.t(), String.t()}]
  defp state_province_options(country_name) do
    RM.Util.Location.state_provinces(country_name)
    |> Enum.map(fn {name, _abbreviation} -> {name, name} end)
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
