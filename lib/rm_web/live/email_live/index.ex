defmodule RMWeb.EmailLive.Index do
  use RMWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_drafts()
    |> ok()
  end

  #
  # Helpers
  #

  @spec assign_drafts(Socket.t()) :: Socket.t()
  defp assign_drafts(socket) do
    user = socket.assigns[:current_user]
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]

    if can?(user, :email_message_send, league || region) do
      drafts = RM.Email.list_campaigns_for_region_or_league(league || region, draft: true)
      assign(socket, drafts: drafts)
    else
      assign(socket, drafts: [])
    end
  end
end
