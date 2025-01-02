defmodule RMWeb.ProposalLive.Show do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  on_mount {__MODULE__, :preload_proposal}

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def on_mount(:preload_proposal, %{"proposal" => proposal_id}, _session, socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    user = socket.assigns[:current_user]
    preloads = [:attachments, :event, :league, :venue]

    redirect_target = url_for([season, region, league, :proposals])

    case RM.Local.fetch_event_proposal_by_id(proposal_id,
           league: league,
           region: region,
           season: season,
           preload: preloads
         ) do
      {:ok, proposal} ->
        if can?(user, :proposal_show, proposal) do
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
end
