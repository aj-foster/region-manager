defmodule RMWeb.RegionLive.Events do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

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

    proposals = RM.Local.list_event_proposals_by_region(region, preload: [:event, :venue])
    pending_proposals = Enum.filter(proposals, &RM.Local.EventProposal.pending?/1)

    assign(socket,
      pending_proposals: pending_proposals,
      pending_proposals_count: length(pending_proposals),
      proposals: proposals
    )
  end
end
