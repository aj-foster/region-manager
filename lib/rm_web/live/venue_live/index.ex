defmodule RMWeb.VenueLive.Index do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    with :ok <- require_permission(socket) do
      socket
      |> assign_venues()
      |> ok()
    end
  end

  @spec require_permission(Socket.t()) :: :ok | Socket.t()
  defp require_permission(socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    user = socket.assigns[:current_user]

    cond do
      not can?(user, :proposal_index, league || region) ->
        socket
        |> put_flash(:error, "You are not authorized to perform this action")
        |> redirect(to: ~p"/")

      season > region.current_season ->
        message = "Event venues for #{season} are not yet available in #{region.name}"

        socket
        |> put_flash(:error, message)
        |> redirect(to: ~p"/")

      season < region.current_season ->
        message = "Event venues for #{season} are no longer available in #{region.name}"

        socket
        |> put_flash(:error, message)
        |> redirect(to: ~p"/")

      :else ->
        :ok
    end
  end

  #
  # Helpers
  #

  @spec assign_venues(Socket.t()) :: Socket.t()
  defp assign_venues(socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]

    venues =
      if league do
        league
        |> RM.Repo.preload(:venues, force: true)
        |> Map.fetch!(:venues)
        |> Enum.sort(RM.Local.Venue)
      else
        region
        |> RM.Repo.preload(:venues, force: true)
        |> Map.fetch!(:venues)
        |> Enum.sort(RM.Local.Venue)
      end

    {active_venues, archived_venues} = Enum.split_with(venues, &is_nil(&1.hidden_at))

    assign(socket,
      page_title: "#{if league, do: league.name, else: region.name} Venues",
      active_venues: active_venues,
      active_venue_count: length(active_venues),
      archived_venues: archived_venues,
      archived_venue_count: length(archived_venues)
    )
  end
end
