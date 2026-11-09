defmodule RMWeb.EventLive.Resources do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @impl true
  def mount(%{"event" => event_code}, _session, socket) do
    socket
    |> assign_event(event_code)
    |> require_permission()
    |> ok()
  end

  #
  # Helpers
  #

  @spec assign_event(Socket.t(), String.t()) :: Socket.t()
  defp assign_event(socket, event_code) do
    preloads = [:league, :local_league, :proposal, :settings]
    region = socket.assigns[:region]
    season = socket.assigns[:season]

    case RM.FIRST.fetch_event_by_code(season, event_code, preload: preloads) do
      {:ok, event} ->
        if event.region_id == region.id do
          event = Map.put(event, :region, region)
          assign(socket, event: event, page_title: "#{event.name} Resources")
        else
          socket
          |> put_flash(:error, "Event not found")
          |> redirect(to: ~p"/dashboard")
        end

      {:error, :event, :not_found} ->
        socket
        |> put_flash(:error, "Event not found")
        |> redirect(to: ~p"/dashboard")
    end
  end

  @spec require_permission(Socket.t()) :: Socket.t()
  defp require_permission(socket) do
    event = socket.assigns[:event]
    region = socket.assigns[:region]
    league = socket.assigns[:local_league] || socket.assigns[:first_league]
    season = socket.assigns[:season]

    cond do
      is_nil(event) ->
        socket

      season != region.current_season ->
        socket
        |> put_flash(:error, "Resources are not available for events outside the current season")
        |> redirect(to: url_for([season, region, league, event]))

      can?(socket.assigns[:current_user], :event_resources_show, event) ->
        socket

      :else ->
        socket
        |> put_flash(:error, "You are not authorized to perform this action")
        |> redirect(to: url_for([season, region, league, event]))
    end
  end
end
