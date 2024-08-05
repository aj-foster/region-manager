defmodule RMWeb.RegionLive.Events do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util
  require Logger

  alias RM.FIRST.Event

  #
  # Lifecycle
  #

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_events()
    |> assign_proposals()
    |> ok()
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("event_proposal_submit", %{"event-proposal-include" => params}, socket) do
    socket
    |> event_proposal_submit(params)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_events(Socket.t()) :: Socket.t()
  defp assign_events(socket) do
    region =
      socket.assigns[:region]
      |> RM.Repo.preload(:events)
      |> Map.update!(:events, &Enum.sort(&1, Event))

    {past_events, upcoming_events} =
      Enum.split_with(region.events, &RM.FIRST.Event.event_passed?/1)

    assign(socket,
      past_events: past_events,
      past_events_count: length(past_events),
      region: region,
      upcoming_events: upcoming_events,
      upcoming_events_count: length(upcoming_events)
    )
  end

  @spec assign_proposals(Socket.t()) :: Socket.t()
  defp assign_proposals(socket) do
    region = socket.assigns[:region]

    preloads = [:event, :league, :region, :venue]
    proposals = RM.Local.list_event_proposals_by_region(region, preload: preloads)
    pending_proposals = Enum.filter(proposals, &RM.Local.EventProposal.pending?/1)

    assign(socket,
      pending_proposals: pending_proposals,
      pending_proposals_count: length(pending_proposals),
      proposals: proposals
    )
  end

  @spec event_proposal_submit(Socket.t(), map) :: Socket.t()
  defp event_proposal_submit(socket, params) do
    region = socket.assigns[:region]
    user = socket.assigns[:current_user]

    proposal_ids =
      params
      |> Map.filter(fn {_key, value} -> value == "true" end)
      |> Map.keys()

    proposals =
      socket.assigns[:pending_proposals]
      |> Enum.filter(&(&1.id in proposal_ids))

    case RM.Local.create_batch_submission(region, proposals, user) do
      {:ok, url} ->
        socket
        |> push_event("window-open", %{url: url})
        |> put_flash(
          :info,
          "Batch Create file generated successfully. If a download doesn't start immediately, please allow popups."
        )
        |> assign_proposals()

      {:error, reason} ->
        Logger.warning("Error while generating Batch Create file: #{inspect(reason)}")
        put_flash(socket, :error, "An error occurred while generating file")
    end
  end
end
