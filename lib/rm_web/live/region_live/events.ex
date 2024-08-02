defmodule RMWeb.RegionLive.Events do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  alias RM.FIRST.Event

  #
  # Lifecycle
  #

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}
  on_mount {__MODULE__, :preload_events}
  on_mount {__MODULE__, :preload_proposals}

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  @doc false
  def on_mount(event, params, session, socket)

  def on_mount(:preload_events, _params, _session, socket) do
    region =
      socket.assigns[:region]
      |> RM.Repo.preload(:events)
      |> Map.update!(:events, &Enum.sort(&1, Event))

    {past_events, upcoming_events} =
      Enum.split_with(region.events, &RM.FIRST.Event.event_passed?/1)

    socket =
      assign(socket,
        past_events: past_events,
        past_events_count: length(past_events),
        region: region,
        upcoming_events: upcoming_events,
        upcoming_events_count: length(upcoming_events)
      )

    {:cont, socket}
  end

  def on_mount(:preload_proposals, _params, _session, socket) do
    region = socket.assigns[:region]

    proposals = RM.Local.list_event_proposals_by_region(region, preload: [:event, :venue])
    pending_proposals = Enum.filter(proposals, &proposal_pending?/1)

    socket =
      assign(socket,
        pending_proposals: pending_proposals,
        pending_proposals_count: length(pending_proposals),
        proposals: proposals
      )

    {:cont, socket}
  end

  #
  # Helpers
  #

  @spec proposal_pending?(RM.Local.EventProposal.t()) :: boolean
  defp proposal_pending?(event_proposal)

  defp proposal_pending?(%RM.Local.EventProposal{first_event: %RM.FIRST.Event{}}), do: false
  defp proposal_pending?(%RM.Local.EventProposal{submitted_at: %DateTime{}}), do: false

  defp proposal_pending?(event_proposal) do
    not RM.Local.EventProposal.event_passed?(event_proposal)
  end
end
