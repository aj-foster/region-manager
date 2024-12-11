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
    |> assign(league: league)
    |> ok()
  end
end
