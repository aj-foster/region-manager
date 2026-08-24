defmodule RMWeb.EmailLive.Util do
  @moduledoc """
  Utility functions for email live views.
  """
  use RMWeb, :html
  import Phoenix.Component
  import Phoenix.LiveView
  import RMWeb.Live.Util

  alias Phoenix.LiveView.Socket

  @doc false
  @spec on_mount(term, map, map, Socket.t()) :: {:cont, Socket.t()}
  def on_mount(name, params, session, socket)

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

  def on_mount(:require_permission, _params, _session, socket) do
    season = socket.assigns[:season]
    region = socket.assigns[:region]
    league = socket.assigns[:local_league]
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

  def on_mount(:require_keila_records, _params, _session, socket) do
    season = socket.assigns[:season]
    region = socket.assigns[:region]
    league = socket.assigns[:local_league]

    with <<project_id::binary>> <- region.metadata.keila_project_id,
         %{} = project <- RM.Email.get_keila_project(region),
         <<segment_id::binary>> <- (league || region).metadata.keila_segment_id,
         %{} = all_segment <- get_segment(project_id, segment_id, :all),
         <<segment_id::binary>> <- (league || region).metadata.keila_coach_segment_id,
         %{} = coach_segment <- get_segment(project_id, segment_id, :coach),
         <<segment_id::binary>> <- (league || region).metadata.keila_extended_coach_segment_id,
         %{} = extended_segment <- get_segment(project_id, segment_id, :coach_ext),
         <<template_id::binary>> <- region.metadata.keila_template_id,
         %{} = template <- Keila.Templates.get_project_template(project_id, template_id),
         <<sender_id::binary>> <- (league || region).metadata.keila_sender_id,
         %{} = sender <- Keila.Mailings.get_project_sender(project_id, sender_id) do
      socket
      |> assign(
        keila_project: project,
        keila_segments: %{
          all: all_segment,
          coach: coach_segment,
          coach_ext: extended_segment
        },
        keila_sender: sender,
        keila_template: template
      )
      |> cont()
    else
      _ ->
        socket
        |> put_flash(
          :error,
          "Email setup is incomplete for this #{if league, do: "league", else: "region"}. Please contact an administrator."
        )
        |> push_navigate(to: url_for([season, region, league]))
        |> halt()
    end
  end

  @spec get_segment(Keila.Projects.Project.id(), Keila.Contacts.Segment.id(), atom) ::
          {Keila.Contacts.Segment.t(), integer} | nil
  defp get_segment(project_id, segment_id, segment_type) do
    if segment = Keila.Contacts.get_project_segment(project_id, segment_id) do
      segment_filter = segment.filter || %{}
      filter = %{"$and" => [segment_filter, %{"status" => "active"}]}
      contact_count = Keila.Contacts.get_project_contacts_count(project_id, filter: filter)

      %{
        count: contact_count,
        name: segment_description(segment_type),
        segment: segment
      }
    end
  end

  @doc "Get a human-readable description for a given segment type"
  @spec segment_description(atom) :: String.t()
  def segment_description(:all), do: "Everyone subscribed to news"
  def segment_description(:coach), do: "Registered coaches"
  def segment_description(:coach_ext), do: "Registered coaches from this season and last season"

  @doc "Validate campaign options and merge them with required fields"
  @spec validate_params(Socket.t(), map) :: map
  def validate_params(socket, params) do
    segment_ids = Enum.map(socket.assigns[:keila_segments], fn {_, info} -> info.segment.id end)
    params = Map.put_new(params, "segment_id", List.first(segment_ids))

    if params["segment_id"] not in segment_ids do
      raise ArgumentError, "Invalid segment ID"
    end

    params
    |> Map.merge(%{
      "project_id" => socket.assigns[:keila_project].id,
      "public_link_enabled" => true,
      "sender_id" => socket.assigns[:keila_sender].id,
      "template_id" => socket.assigns[:keila_template].id,
      "settings" => %{"type" => "markdown", "do_not_track" => true}
    })
  end

  #
  # Template Helpers
  #

  @doc "Create a list of options for a select input based on the given segments"
  @spec segment_options(map) :: [{String.t(), String.t()}]
  def segment_options(%{all: all_info, coach: coach_info, coach_ext: coach_ext_info}) do
    [
      {all_info.name <> " (#{all_info.count})", all_info.segment.id},
      {coach_info.name <> " (#{coach_info.count})", coach_info.segment.id},
      {coach_ext_info.name <> " (#{coach_ext_info.count})", coach_ext_info.segment.id}
    ]
  end
end
