defmodule RMWeb.TeamLive.Events do
  use RMWeb, :live_view
  import RMWeb.TeamLive.Util

  alias RM.FIRST.Event

  on_mount {RMWeb.TeamLive.Util, :preload_team}
  on_mount {RMWeb.TeamLive.Util, :require_team_manager}

  def mount(_params, _session, socket) do
    socket
    |> assign(page_title: "Event List")
    |> ok()
  end

  def handle_params(_params, _uri, socket) do
    socket
    |> load_events()
    |> load_eligible_events()
    |> noreply()
  end

  #
  # Helpers
  #

  defp load_eligible_events(socket) do
    team = socket.assigns[:team]
    registered_event_ids = Enum.map(team.event_registrations, & &1.event_id)

    assign_async(socket, [:eligible_events, :past_events], fn ->
      events =
        RM.FIRST.list_eligible_events_by_team(team, season: team.region.current_season)
        |> Enum.reject(&(&1.id in registered_event_ids))

      {past_events, upcoming_events} = Enum.split_with(events, &RM.FIRST.Event.event_passed?/1)
      {:ok, %{eligible_events: upcoming_events, past_events: past_events}}
    end)
  end
end
