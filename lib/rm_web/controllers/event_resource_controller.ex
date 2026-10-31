defmodule RMWeb.EventResourceController do
  use RMWeb, :controller
  import RMWeb.Controller.Util, only: [assign_season: 2, assign_region: 2, assign_event: 2]

  plug :assign_season
  plug :assign_region
  plug :assign_event, preload: [:league, :local_league, :proposal]
  plug :authorize_event_resources_show

  import Ecto.Query
  require Logger

  alias RM.Account
  alias RM.Account.Event, as: UserEvent
  alias RM.Local.EventTeamList
  alias RM.Repo

  @doc """
  GET `/s/:season/r/:region/e/:event/resources/team_list.pdf`

  Prepare a check-in list for registered teams at an event. If the event is a league event,
  unregistered league teams are included in a separate section.
  """
  def team_list(conn, params) do
    event = conn.assigns.event
    region = conn.assigns.region

    render_team_list(conn, event, region, canonical_timezone(params["timezone"]))
  end

  defp render_team_list(conn, event, region, timezone) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{registered: registered_teams, unregistered: unregistered_teams} =
      EventTeamList.list_teams(event)

    variables = %{
      event_name: event.name,
      generated_at: RMWeb.CoreComponents.format_date(now, :full, timezone),
      last_team_import:
        RMWeb.CoreComponents.format_date(
          region.stats && region.stats.teams_imported_at,
          :full,
          timezone
        ),
      registered: Enum.map(registered_teams, &format_team/1),
      unregistered: Enum.map(unregistered_teams, &format_team/1)
    }

    template_path = Application.app_dir(:rm, "priv/templates/event_team_list.typ")

    with {:ok, template} <- File.read(template_path),
         {:ok, pdf} <- RM.Util.Typst.render_pdf(template, variables) do
      send_download(conn, {:binary, pdf},
        filename: "event-teams-#{String.downcase(event.code)}.pdf",
        content_type: "application/pdf"
      )
    else
      {:error, reason} ->
        Logger.error("Failed to render event team list PDF: #{inspect(reason)}")
        send_resp(conn, :internal_server_error, "Unable to generate the event team list")
    end
  end

  defp format_team(team) do
    %{event_ready: team.event_ready == true, name: team.name || "", number: team.number}
  end

  defp canonical_timezone(timezone) when is_binary(timezone) do
    case TzExtra.canonical_time_zone_id(timezone) do
      {:ok, canonical} -> canonical
      _ -> "Etc/UTC"
    end
  end

  defp canonical_timezone(_timezone), do: "Etc/UTC"

  #
  # Plugs
  #

  defp authorize_event_resources_show(conn, _opts) do
    user = load_user(conn.assigns[:current_user])
    event = conn.assigns.event

    if RM.Account.Auth.can?(user, :event_resources_show, event) do
      conn
    else
      event_path =
        case conn.path_params do
          %{"league" => league} ->
            ~p"/s/#{event.season}/r/#{conn.assigns.region}/l/#{league}/e/#{event}"

          _path_params ->
            ~p"/s/#{event.season}/r/#{conn.assigns.region}/e/#{event}"
        end

      conn
      |> put_flash(:error, "You are not authorized to perform this action")
      |> redirect(to: event_path)
      |> halt()
    end
  end

  defp load_user(%{id: user_id}) do
    event_assignments =
      from(assignment in UserEvent,
        join: proposal in assoc(assignment, :proposal),
        join: region in assoc(proposal, :region),
        where: proposal.season == region.current_season
      )

    Account.get_user_by_id!(user_id, preload: [:regions, :leagues])
    |> Repo.preload(event_assignments: event_assignments)
  end

  defp load_user(_user), do: nil
end
