defmodule RMWeb.TeamLive.Events do
  use RMWeb, :live_view
  import RMWeb.TeamLive.Util

  alias RM.FIRST.Event

  on_mount {RMWeb.TeamLive.Util, :preload_team}
  on_mount {RMWeb.TeamLive.Util, :require_team_manager}

  def mount(_params, _session, socket) do
    socket
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

    assign_async(socket, :eligible_events, fn ->
      events =
        RM.FIRST.list_eligible_events_by_team(team)

      # |> Enum.reject(&Date.before?(&1.date_end, Date.utc_today()))

      {:ok, %{eligible_events: events}}
    end)
  end
end
