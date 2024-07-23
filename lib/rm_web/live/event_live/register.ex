defmodule RMWeb.EventLive.Register do
  use RMWeb, :live_view

  alias RM.FIRST.Event

  on_mount {RMWeb.Live.Util, :require_season}
  on_mount {__MODULE__, :preload_event}

  def mount(_params, _session, socket) do
    socket
    |> assign_event_metadata()
    |> validate_team_eligibility()
    |> ok()
  end

  def on_mount(:preload_event, %{"event" => event_code}, _session, socket) do
    season = socket.assigns[:season]

    case RM.FIRST.fetch_event_by_code(season, event_code, preload: [:league, :region, :settings]) do
      {:ok, event} ->
        event = RM.Repo.preload(event, registrations: [:team])
        {:cont, assign(socket, event: event)}

      {:error, :event, :not_found} ->
        {:cont, assign(socket, event: nil)}
    end
  end

  #
  # Helpers
  #

  defp assign_event_metadata(socket) do
    event = socket.assigns[:event]

    assign(socket,
      registration_enabled: get_in(event.settings.registration.enabled),
      registration_pool: get_in(event.settings.registration.pool),
      registration_pool_target:
        case get_in(event.settings.registration.pool) do
          :league -> get_in(event.league)
          :region -> get_in(event.region)
          _else -> nil
        end,
      registrations:
        (get_in(event.registrations) || [])
        |> Map.new(fn
          %{team: team, rescinded: true} -> {team.number, :rescinded}
          %{team: team, waitlisted: true} -> {team.number, :waitlisted}
          %{team: team} -> {team.number, :attending}
        end)
    )
  end

  defp validate_team_eligibility(socket) do
    if event = socket.assigns[:event] do
      teams =
        socket.assigns[:current_user].teams
        |> Enum.map(fn team ->
          eligibility =
            case RM.Local.verify_eligibility(event, team) do
              :ok -> :ok
              {:error, reason} -> reason
            end

          {team, eligibility}
        end)

      eligible_teams =
        teams
        |> Enum.filter(fn {_team, eligibility} -> eligibility == :ok end)
        |> Enum.map(fn {team, _} -> team end)

      assign(socket, eligible_teams: eligible_teams, teams: teams)
    else
      assign(socket, eligible_teams: [], teams: [])
    end
  end
end
