defmodule RMWeb.RegionLive.Event.Index do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util
  require Logger

  alias Phoenix.LiveView.AsyncResult
  alias RM.FIRST
  alias RM.FIRST.Event
  alias RM.FIRST.Region
  alias RM.Local.EventProposal

  #
  # Lifecycle
  #

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_batches()
    |> assign_events()
    |> assign_proposals()
    |> assign_refresh_disabled()
    |> assign(refresh_events: AsyncResult.ok(nil))
    |> ok()
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("download_batch", %{"batch" => batch_id}, socket) do
    socket
    |> download_batch(batch_id)
    |> noreply()
  end

  def handle_event("event_proposal_submit", %{"event-proposal-include" => params}, socket) do
    socket
    |> event_proposal_submit(params)
    |> noreply()
  end

  def handle_event("refresh_events", _params, socket) do
    region = socket.assigns[:region]

    socket
    |> start_async(:refresh_events, fn -> FIRST.refresh_events(region) end)
    |> assign(refresh_events: AsyncResult.loading())
    |> noreply()
  end

  @doc false
  @impl true
  def handle_async(name, async_fun_result, socket)

  def handle_async(:refresh_events, {:ok, {:ok, _events}}, socket) do
    socket
    |> assign(refresh_events: AsyncResult.ok(true))
    |> refresh_region()
    |> assign_events()
    |> assign_proposals()
    |> assign_refresh_disabled()
    |> noreply()
  end

  def handle_async(:refresh_events, {:ok, {:error, reason}}, socket) do
    Logger.error("Error while refreshing events: #{inspect(reason)}")

    socket
    |> assign(refresh_events: AsyncResult.ok(false))
    |> put_flash(:error, "An error occurred while refreshing events. Please try again later.")
    |> noreply()
  end

  def handle_async(:refresh_events_disabled, {:ok, :done}, socket) do
    socket
    |> assign(refresh_events_disabled: false)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_batches(Socket.t()) :: Socket.t()
  defp assign_batches(socket) do
    region = socket.assigns[:region]
    batches = RM.Local.list_batch_submissions(region, page: 1, per_page: 5)

    assign(socket, event_batches: batches, event_batches_count: length(batches))
  end

  @spec assign_events(Socket.t()) :: Socket.t()
  defp assign_events(socket) do
    region = socket.assigns[:region]
    events = RM.FIRST.list_events_by_region(region)
    {past_events, upcoming_events} = Enum.split_with(events, &RM.FIRST.Event.event_passed?/1)

    assign(socket,
      past_events: past_events,
      past_events_count: length(past_events),
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

  @spec assign_refresh_disabled(Socket.t()) :: Socket.t()
  defp assign_refresh_disabled(socket) do
    %Region{stats: %{events_imported_at: last_refresh}} = socket.assigns[:region]

    if not is_nil(last_refresh) and
         DateTime.after?(last_refresh, DateTime.add(DateTime.utc_now(), -10, :minute)) do
      time_until_enabled_ms =
        DateTime.add(last_refresh, 10, :minute)
        |> DateTime.diff(DateTime.utc_now(), :millisecond)

      socket
      |> assign(refresh_events_disabled: true)
      |> start_async(:refresh_events_disabled, fn ->
        Process.sleep(time_until_enabled_ms)
        :done
      end)
    else
      assign(socket, refresh_events_disabled: false)
    end
  end

  @spec download_batch(Socket.t(), String.t()) :: Socket.t()
  defp download_batch(socket, batch_id) do
    if batch = Enum.find(socket.assigns[:event_batches], &(&1.id == batch_id)) do
      url = RM.Local.EventSubmission.url({"", batch}, signed: true)

      socket
      |> push_event("window-open", %{url: url})
      |> put_flash(
        :info,
        "Download started. If a download doesn't start immediately, please allow popups."
      )
    else
      socket
      |> put_flash(:error, "Event batch not found")
      |> assign_batches()
    end
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
        |> assign_batches()
        |> assign_proposals()

      {:error, reason} ->
        Logger.warning("Error while generating Batch Create file: #{inspect(reason)}")
        put_flash(socket, :error, "An error occurred while generating file")
    end
  end
end
