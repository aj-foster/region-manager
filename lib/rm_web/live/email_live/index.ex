defmodule RMWeb.EmailLive.Index do
  use RMWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_drafts()
    |> assign_sent()
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

  @spec assign_sent(Socket.t()) :: Socket.t()
  defp assign_sent(socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]

    sent = RM.Email.list_campaigns_for_region_or_league(league || region, draft: false)
    assign(socket, sent: sent)
  end

  #
  # Template Helpers
  #

  @spec messages_page_title(
          RM.Local.League.t() | nil,
          RM.FIRST.League.t() | nil,
          RM.FIRST.Region.t()
        ) :: String.t()
  defp messages_page_title(local_league, first_league, region)
  defp messages_page_title(%RM.Local.League{name: name}, _, _), do: name
  defp messages_page_title(_, %RM.FIRST.League{name: name}, _), do: name
  defp messages_page_title(_, _, %RM.FIRST.Region{name: name}), do: name
end
