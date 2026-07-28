defmodule RMWeb.EmailLive.Edit do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  on_mount {__MODULE__, :require_current_season}
  on_mount {__MODULE__, :preload_message}
  on_mount {__MODULE__, :require_correct_segment}
  on_mount {__MODULE__, :require_permission}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> ok()
  end

  def on_mount(:require_current_season, _params, _session, socket) do
    season = socket.assigns[:season]
    region = socket.assigns[:region]
    league = socket.assigns[:local_league]

    redirect_target = url_for([season, region, league])

    cond do
      season > region.current_season ->
        socket
        |> put_flash(:error, "Messaging for #{season} is not yet available.")
        |> push_navigate(to: redirect_target)
        |> halt()

      season < region.current_season ->
        socket
        |> put_flash(:error, "Messaging for #{season} is no longer available.")
        |> push_navigate(to: redirect_target)
        |> halt()

      :else ->
        {:cont, socket}
    end
  end

  def on_mount(:preload_message, %{"message" => campaign_id}, _session, socket) do
    season = socket.assigns[:season]
    region = socket.assigns[:region]
    league = socket.assigns[:local_league]
    project_id = socket.assigns[:region].metadata.keila_project_id

    case Keila.Mailings.get_project_campaign(project_id, campaign_id) do
      %Keila.Mailings.Campaign{sent_at: nil} = campaign ->
        socket
        |> assign(campaign: campaign)
        |> cont()

      %Keila.Mailings.Campaign{} = campaign ->
        socket
        |> put_flash(:error, "This email has already been sent and cannot be edited.")
        |> push_navigate(to: url_for([season, region, league, campaign]))
        |> halt()

      nil ->
        socket
        |> put_flash(:error, "Could not load email message.")
        |> push_navigate(to: ~p"/dashboard")
        |> halt()
    end
  end

  def on_mount(:require_correct_segment, _params, _session, socket) do
    season = socket.assigns[:season]
    region = socket.assigns[:region]
    league = socket.assigns[:local_league]
    campaign = socket.assigns[:campaign]

    segment_ids = [
      (league || region).metadata.keila_segment_id,
      (league || region).metadata.keila_coach_segment_id,
      (league || region).metadata.keila_extended_coach_segment_id
    ]

    if campaign.segment_id in segment_ids do
      {:cont, socket}
    else
      socket
      |> put_flash(:error, "An error occurred. Please contact support (incorrect_segment).")
      |> push_navigate(to: url_for([season, region, league, campaign]))
      |> halt()
    end
  end

  def on_mount(:require_permission, _params, _session, socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    user = socket.assigns[:current_user]

    if can?(user, :email_message_send, league || region) do
      {:cont, socket}
    else
      socket
      |> put_flash(
        :error,
        "You do not have permission to send messages for this #{if league, do: "league", else: "region"}."
      )
      |> push_navigate(to: url_for([season, region, league]))
      |> halt()
    end
  end

  #
  # Events
  #

  # @impl true
  # def handle_event(event, unsigned_params, socket)
end
