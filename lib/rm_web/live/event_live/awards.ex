defmodule RMWeb.EventLive.Awards do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(%{"event" => event_code}, _session, socket) do
    socket
    |> assign_event(event_code)
    |> assign_teams()
    |> video_add_form()
    |> video_edit_form()
    |> assign(video_add_team: nil, video_edit_submission: nil)
    |> ok()
  end

  #
  # Events
  #

  @doc false
  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("video_add_init", %{"team" => team_id}, socket) do
    event = socket.assigns[:event]

    cond do
      not event.settings.video_submission ->
        socket
        |> put_flash(:error, "Video submission is not enabled")
        |> noreply()

      RM.FIRST.Event.video_submission_deadline_passed?(event) ->
        socket
        |> put_flash(:error, "Video submission deadline has passed")
        |> noreply()

      :else ->
        socket
        |> video_add_init(team_id)
        |> noreply()
    end
  end

  def handle_event("video_add_submit", %{"event_video" => params}, socket) do
    event = socket.assigns[:event]

    cond do
      not event.settings.video_submission ->
        socket
        |> put_flash(:error, "Video submission is not enabled")
        |> noreply()

      RM.FIRST.Event.video_submission_deadline_passed?(event) ->
        socket
        |> put_flash(:error, "Video submission deadline has passed")
        |> noreply()

      :else ->
        socket
        |> video_add_submit(params)
        |> noreply()
    end
  end

  def handle_event("video_edit_init", %{"team" => team_id}, socket) do
    event = socket.assigns[:event]

    cond do
      not event.settings.video_submission ->
        socket
        |> put_flash(:error, "Video submission is not enabled")
        |> noreply()

      RM.FIRST.Event.video_submission_deadline_passed?(event) ->
        socket
        |> put_flash(:error, "Video submission deadline has passed")
        |> noreply()

      :else ->
        socket
        |> video_edit_init(team_id)
        |> noreply()
    end
  end

  def handle_event("video_edit_submit", %{"event_video" => params}, socket) do
    event = socket.assigns[:event]

    cond do
      not event.settings.video_submission ->
        socket
        |> put_flash(:error, "Video submission is not enabled")
        |> noreply()

      RM.FIRST.Event.video_submission_deadline_passed?(event) ->
        socket
        |> put_flash(:error, "Video submission deadline has passed")
        |> noreply()

      :else ->
        socket
        |> video_edit_submit(params)
        |> noreply()
    end
  end

  #
  # Helpers
  #

  @spec assign_event(Socket.t(), String.t()) :: Socket.t()
  defp assign_event(socket, event_code) do
    preloads = [:league, :settings]
    region = socket.assigns[:region]
    season = socket.assigns[:season]

    case RM.FIRST.fetch_event_by_code(season, event_code, preload: preloads) do
      {:ok, event} ->
        if event.region_id == region.id do
          event =
            RM.Repo.preload(event, registrations: :team, videos: [team: [:league, :region]])
            |> Map.put(:region, region)

          assign(socket, event: event, page_title: event.name)
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

  @spec assign_teams(Socket.t()) :: Socket.t()
  defp assign_teams(socket) do
    event = socket.assigns[:event]
    user = socket.assigns[:current_user]

    if event.settings.video_submission && user && length(user.teams) > 0 do
      teams =
        user.teams
        |> Enum.filter(& &1.active)
        |> Enum.map(&%{team: &1})
        |> Enum.map(fn %{team: team} = info ->
          case event.settings.video_submission_pool do
            :registered ->
              Map.put(info, :eligible?, team.id in Enum.map(event.registrations, & &1.team_id))

            :league ->
              Map.put(info, :eligible?, team.league_id == event.league_id)

            :region ->
              Map.put(info, :eligible?, team.region_id == event.region_id)

            :all ->
              Map.put(info, :eligible?, true)
          end
        end)
        |> Enum.map(fn %{team: team} = info ->
          if submission = Enum.find(event.videos, &(&1.team_id == team.id)) do
            Map.merge(info, %{submitted?: true, submission: submission})
          else
            Map.merge(info, %{submitted?: false, submission: nil})
          end
        end)

      assign(socket, teams: teams, teams_count: length(teams))
    else
      assign(socket, teams: [], teams_count: 0)
    end
  end

  @spec video_add_form(Socket.t()) :: Socket.t()
  defp video_add_form(socket) do
    if info = socket.assigns[:video_add_team] do
      event = socket.assigns[:event]

      form =
        RM.Local.EventVideo.create_changeset(event, info.team, %{"award" => "compass"})
        |> to_form()

      assign(socket, video_add_form: form)
    else
      assign(socket, video_add_form: to_form(%{}))
    end
  end

  @spec video_add_init(Socket.t(), String.t()) :: Socket.t()
  defp video_add_init(socket, team_id) do
    teams = socket.assigns[:teams]

    if info = Enum.find(teams, &(&1.team.id == team_id)) do
      socket
      |> assign(video_add_team: info)
      |> video_add_form()
      |> push_js("#video-add-modal", "data-show")
    else
      put_flash(socket, :error, "An error occurred; please contact support")
    end
  end

  @spec video_add_submit(Socket.t(), map) :: Socket.t()
  defp video_add_submit(socket, params) do
    event = socket.assigns[:event]
    user = socket.assigns[:current_user]
    params = Map.put(params, "by", user)

    case socket.assigns[:video_add_team] do
      %{eligible?: true, submitted?: false, team: team} ->
        case RM.Local.create_event_video(event, team, params) do
          {:ok, _video} ->
            event = RM.Repo.preload(event, :videos, force: true)

            socket
            |> put_flash(:info, "Video submitted successfully")
            |> push_js("#video-add-modal", "data-cancel")
            |> assign(event: event, video_add_team: nil)
            |> assign_teams()
            |> video_add_form()

          {:error, changeset} ->
            assign(socket, video_add_form: to_form(changeset))
        end

      %{eligible?: false} ->
        socket
        |> put_flash(:error, "Team is not eligible to submit a video")
        |> push_js("#video-add-modal", "data-cancel")
        |> assign(video_add_team: nil)

      %{submitted?: true} ->
        socket
        |> put_flash(:error, "Team has already submitted for this award")
        |> push_js("#video-add-modal", "data-cancel")
        |> assign(video_add_team: nil)

      nil ->
        socket
        |> put_flash(:error, "An error occurred; please contact support")
        |> push_js("#video-add-modal", "data-cancel")
        |> assign(video_add_team: nil)
    end
  end

  @spec video_edit_form(Socket.t()) :: Socket.t()
  defp video_edit_form(socket) do
    if submission = socket.assigns[:video_edit_submission] do
      form = RM.Local.EventVideo.update_changeset(submission, %{}) |> to_form()
      assign(socket, video_edit_form: form)
    else
      assign(socket, video_edit_form: to_form(%{}))
    end
  end

  @spec video_edit_init(Socket.t(), String.t()) :: Socket.t()
  defp video_edit_init(socket, team_id) do
    event = socket.assigns[:event]

    if submission = Enum.find(event.videos, &(&1.team_id == team_id)) do
      socket
      |> assign(video_edit_submission: submission)
      |> video_edit_form()
      |> push_js("#video-edit-modal", "data-show")
    else
      put_flash(socket, :error, "An error occurred; please contact support")
    end
  end

  @spec video_edit_submit(Socket.t(), map) :: Socket.t()
  defp video_edit_submit(socket, params) do
    event = socket.assigns[:event]
    submission = socket.assigns[:video_edit_submission]
    teams = socket.assigns[:teams]
    user = socket.assigns[:current_user]

    params = Map.put(params, "by", user)

    case Enum.find(teams, &(&1.team.id == submission.team_id)) do
      %{submitted?: true} ->
        case RM.Local.update_event_video(submission, params) do
          {:ok, _video} ->
            event = RM.Repo.preload(event, :videos, force: true)

            socket
            |> put_flash(:info, "Video submitted successfully")
            |> push_js("#video-edit-modal", "data-cancel")
            |> assign(event: event, video_edit_submission: nil)
            |> assign_teams()
            |> video_edit_form()

          {:error, changeset} ->
            assign(socket, video_edit_form: to_form(changeset))
        end

      %{submitted?: false} ->
        socket
        |> put_flash(:error, "Team has not submitted for this award")
        |> push_js("#video-edit-modal", "data-cancel")
        |> assign(video_edit_submission: nil)

      nil ->
        socket
        |> put_flash(:error, "An error occurred; please contact support")
        |> push_js("#video-edit-modal", "data-cancel")
        |> assign(video_edit_submission: nil)
    end
  end

  #
  # Template Helpers
  #

  @spec format_video_due_date(RM.FIRST.Event.t()) :: String.t()
  defp format_video_due_date(event) do
    %RM.FIRST.Event{
      date_timezone: timezone,
      settings: %RM.Local.EventSettings{video_submission_date: date}
    } = event

    DateTime.new!(date, Time.new!(23, 59, 0), timezone)
    |> format_date(:full)
  end
end
