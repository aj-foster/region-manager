defmodule RMWeb.LeagueLive.Show do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    %{
      season: season,
      region: region,
      local_league: local_league,
      first_league: first_league
    } = socket.assigns

    league =
      cond do
        is_nil(local_league) -> first_league
        is_nil(first_league) -> local_league
        season == region.current_season -> local_league
        :else -> first_league
      end

    socket
    |> assign(league: league, page_title: "#{league.name} League")
    |> assign_latest_news()
    |> ok()
  end

  #
  # Helpers
  #

  @spec assign_latest_news(Socket.t()) :: Socket.t()
  defp assign_latest_news(socket) do
    league = socket.assigns[:local_league]

    if league && league.settings && league.settings.enable_email do
      latest_news = RM.Email.list_campaigns_for_region_or_league(league, page_size: 3)
      assign(socket, :latest_news, latest_news)
    else
      assign(socket, :latest_news, [])
    end
  end
end
