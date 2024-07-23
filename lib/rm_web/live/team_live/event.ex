defmodule RMWeb.TeamLive.Event do
  use RMWeb, :live_view
  import RMWeb.TeamLive.Util
  require Logger

  alias RM.FIRST.Event

  on_mount {RMWeb.TeamLive.Util, :preload_team}
  on_mount {RMWeb.TeamLive.Util, :require_team_manager}
  on_mount {__MODULE__, :preload_event}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> set_registration()
    |> set_registered_teams()
    |> assign(registration_error: nil)
    |> ok()
  end

  def on_mount(:preload_event, %{"event" => event_code}, _session, socket) do
    team = socket.assigns[:team]
    season = team.region.current_season

    case RM.FIRST.fetch_event_by_code(season, event_code, preload: [:league, :region, :settings]) do
      {:ok, event} ->
        {:cont, assign(socket, event: event)}

      {:error, :event, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Event not found")
          |> redirect(to: ~p"/dashboard")

        {:halt, socket}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket
    |> noreply()
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("registration_submit", _params, socket) do
    event = socket.assigns[:event]
    team = socket.assigns[:team]

    case RM.Local.verify_eligibility(event, team) do
      :ok ->
        socket
        |> registration_submit()
        |> push_js("#create-registration-modal", "data-cancel")
        |> set_registration()
        |> set_registered_teams()
        |> noreply()

      {:error, _reason} ->
        socket
        |> put_flash(:error, "This team is not eligible to register for this event")
        |> push_js("#create-registration-modal", "data-cancel")
        |> refresh_team()
        |> noreply()
    end
  end

  def handle_event("rescind_submit", _params, socket) do
    socket
    |> rescind_submit()
    |> push_js("#change-registration-modal", "data-cancel")
    |> set_registration()
    |> set_registered_teams()
    |> noreply()
  end

  #
  # Helpers
  #

  @spec registration_submit(Socket.t()) :: Socket.t()
  defp registration_submit(socket) do
    event = socket.assigns[:event]
    team = socket.assigns[:team]
    user = socket.assigns[:current_user]

    case RM.Local.create_event_registration(event, team, %{by: user, waitlisted: false}) do
      {:ok, registration} ->
        assign(socket,
          eligible: false,
          eligibility_reason: nil,
          registration: registration,
          registration_error: nil
        )

      {:error, changeset} ->
        Logger.error("Failed to register for event: #{inspect(changeset)}")
        assign(socket, registration_error: "An error occurred; please contact support.")
    end
  end

  @spec rescind_submit(Socket.t()) :: Socket.t()
  defp rescind_submit(socket) do
    registration = socket.assigns[:registration]
    user = socket.assigns[:current_user]

    case RM.Local.rescind_event_registration(registration, %{by: user}) do
      {:ok, registration} ->
        assign(socket,
          eligible: false,
          eligibility_reason: nil,
          registration: registration,
          registration_error: nil
        )

      {:error, changeset} ->
        Logger.error("Failed to rescind registration for event: #{inspect(changeset)}")
        assign(socket, registration_error: "An error occurred; please contact support.")
    end
  end

  @spec set_registration(Socket.t()) :: Socket.t()
  defp set_registration(socket) do
    event = socket.assigns[:event]
    team = socket.assigns[:team]

    case RM.Local.fetch_event_registration(event, team) do
      {:ok, registration} ->
        assign(socket, eligible: false, eligibility_reason: nil, registration: registration)

      {:error, :registration, :not_found} ->
        case RM.Local.verify_eligibility(event, team) do
          :ok ->
            assign(socket, eligible: true, eligibility_reason: nil, registration: nil)

          {:error, reason} ->
            assign(socket, eligible: false, eligibility_reason: reason, registration: nil)
        end
    end
  end

  @spec set_registered_teams(Socket.t()) :: Socket.t()
  defp set_registered_teams(socket) do
    event = socket.assigns[:event]

    assign_async(socket, :registered_teams, fn ->
      teams =
        RM.Local.list_registered_teams_by_event(event, rescinded: false, waitlisted: false)
        |> Enum.map(& &1.team)

      {:ok, %{registered_teams: teams}}
    end)
  end
end
