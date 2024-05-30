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

  #
  # Template Helpers
  #

  @spec event_format(Event.t()) :: String.t()
  defp event_format(%Event{remote: true}), do: "Remote"
  defp event_format(%Event{hybrid: true}), do: "Hybrid"
  defp event_format(_event), do: "Traditional"

  @spec multi_day?(Event.t()) :: boolean
  defp multi_day?(%Event{date_start: start, date_end: finish}) do
    Date.diff(start, finish) != 0
  end
end
