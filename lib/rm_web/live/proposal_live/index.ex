defmodule RMWeb.ProposalLive.Index do
  use RMWeb, :live_view
  require Logger

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    with :ok <- require_permission(socket) do
      socket
      |> assign_batches()
      |> assign_proposals()
      |> ok()
    end
  end

  @spec require_permission(Socket.t()) :: :ok | Socket.t()
  defp require_permission(socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    user = socket.assigns[:current_user]

    redirect_target = url_for([season, region, league])

    cond do
      not can?(user, :proposal_index, league || region) ->
        socket
        |> put_flash(:error, "You are not authorized to perform this action")
        |> redirect(to: redirect_target)
        |> ok()

      season > region.current_season ->
        message = "Event proposals for #{season} are not yet available in #{region.name}"

        socket
        |> put_flash(:error, message)
        |> redirect(to: redirect_target)
        |> ok()

      season < region.current_season ->
        message = "Event proposals for #{season} are no longer available in #{region.name}"

        socket
        |> put_flash(:error, message)
        |> redirect(to: redirect_target)
        |> ok()

      :else ->
        :ok
    end
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

  def handle_event("generate_submit", %{"proposal-include" => params}, socket) do
    socket
    |> proposal_submit(params)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_batches(Socket.t()) :: Socket.t()
  defp assign_batches(socket) do
    region = socket.assigns[:region]
    user = socket.assigns[:current_user]

    batches =
      cond do
        socket.assigns[:local_league] ->
          []

        can?(user, :proposal_submit, region) ->
          RM.Local.list_batch_submissions(region, page: 1, per_page: 5)

        :else ->
          []
      end

    assign(socket, event_batches: batches, event_batches_count: length(batches))
  end

  @spec assign_proposals(Socket.t()) :: Socket.t()
  defp assign_proposals(socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]

    proposals =
      RM.Local.list_event_proposals_by_region(region,
        league: league,
        season: season,
        preload: [:league, :venue]
      )
      |> Enum.sort(RM.Local.EventProposal)
      |> Enum.group_by(fn proposal ->
        cond do
          proposal.first_event_id -> :matched
          proposal.removed_at -> :removed
          proposal.submitted_at -> :submitted
          :else -> :rest
        end
      end)

    matched_proposals = proposals[:matched] || []
    open_proposals = proposals[:rest] || []
    removed_proposals = proposals[:removed] || []
    submitted_proposals = proposals[:submitted] || []

    assign(socket,
      matched_proposals: matched_proposals,
      matched_proposals_count: length(matched_proposals),
      proposals: open_proposals,
      proposals_count: length(open_proposals),
      removed_proposals: removed_proposals,
      removed_proposals_count: length(removed_proposals),
      submitted_proposals: submitted_proposals,
      submitted_proposals_count: length(submitted_proposals)
    )
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

  @spec proposal_submit(Socket.t(), map) :: Socket.t()
  defp proposal_submit(socket, params) do
    region = socket.assigns[:region]
    user = socket.assigns[:current_user]

    proposal_ids =
      params
      |> Map.filter(fn {_key, value} -> value == "true" end)
      |> Map.keys()

    proposals =
      socket.assigns[:proposals]
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
