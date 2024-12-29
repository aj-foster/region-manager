defmodule RMWeb.LeagueLive.Index do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_leagues()
    |> ok()
  end

  #
  # Helpers
  #

  @spec assign_leagues(Socket.t()) :: Socket.t()
  defp assign_leagues(socket) do
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    user = socket.assigns[:current_user]

    leagues =
      RM.FIRST.list_leagues_by_region(region, season: season, preload: [:local_league])
      |> Enum.sort(RM.FIRST.League)

    unpublished_leagues =
      if can?(user, :league_update, region) and region.current_season == season do
        published_league_ids = Enum.map(leagues, & &1.local_league_id)

        RM.Local.list_leagues_by_region(region)
        |> Enum.reject(&(&1.id in published_league_ids))
        |> Enum.sort(RM.Local.League)
      else
        []
      end

    assign(socket,
      leagues: leagues,
      leagues_count: length(leagues),
      unpublished_leagues: unpublished_leagues,
      unpublished_leagues_count: length(unpublished_leagues)
    )
  end

  #
  # Template Helpers
  #

  @spec leagues_page_title(
          RM.Local.League.t() | nil,
          RM.FIRST.League.t() | nil,
          RM.FIRST.Region.t()
        ) :: String.t()
  defp leagues_page_title(local_league, first_league, region)
  defp leagues_page_title(%RM.Local.League{name: name}, _, _), do: name <> " League"
  defp leagues_page_title(_, %RM.FIRST.League{name: name}, _), do: name <> " League"
  defp leagues_page_title(_, _, %RM.FIRST.Region{name: name}), do: name
end
