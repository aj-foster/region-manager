defmodule RMWeb.ProposalLive.Show do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  on_mount {__MODULE__, :preload_proposal}

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    with :ok <- require_permission(socket) do
      {:ok, socket}
    end
  end

  def on_mount(:preload_proposal, %{"proposal" => proposal_id}, _session, socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    preloads = [:attachments, :event, :venue]

    case RM.Local.fetch_event_proposal_by_id(proposal_id, league: league, preload: preloads) do
      {:ok, proposal} ->
        {:cont, assign(socket, proposal: proposal, page_title: proposal.name)}

      {:error, :proposal, :not_found} ->
        redirect_target =
          if league do
            ~p"/s/#{season}/r/#{region}/l/#{league}/proposals"
          else
            ~p"/s/#{season}/r/#{region}/proposals"
          end

        socket =
          socket
          |> put_flash(:error, "Event proposal not found")
          |> redirect(to: redirect_target)

        {:halt, socket}
    end
  end

  @spec require_permission(Socket.t()) :: :ok | Socket.t()
  defp require_permission(socket) do
    proposal = socket.assigns[:proposal]
    user = socket.assigns[:current_user]

    if can?(user, :proposal_show, proposal) do
      :ok
    else
      socket
      |> put_flash(:error, "You are not authorized to perform this action")
      |> redirect(to: ~p"/")
    end
  end
end
