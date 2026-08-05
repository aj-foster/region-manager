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

    redirect_target = url_for([season, region, league, :messages])

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

  @doc "Assign available segments for the current league (if present) or region to the socket"
  @spec assign_segments(Socket.t()) :: Socket.t()
  def assign_segments(socket) do
    keila_segments =
      %{
        all: get_segment(socket, :all),
        coach: get_segment(socket, :coach),
        coach_ext: get_segment(socket, :coach_ext)
      }
      |> Map.reject(fn {_key, value} -> is_nil(value) end)

    if map_size(keila_segments) == 3 do
      assign(socket, keila_segments: keila_segments)
    else
      season = socket.assigns[:season]
      region = socket.assigns[:region]

      socket
      |> put_flash(
        :error,
        "One or more email segments are missing. Please contact an administrator."
      )
      |> push_navigate(to: url_for([season, region]))
    end
  end

  @spec get_segment(Socket.t(), atom) :: {Keila.Contacts.Segment.t(), integer} | nil
  defp get_segment(socket, segment_type) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    project_id = socket.assigns[:keila_project].id
    segment_id = segment_id(league || region, segment_type)

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

  @doc "Extract the segment ID for a given segment type from a league or region"
  @spec segment_id(RM.Local.League.t() | RM.FIRST.Region.t(), atom) :: String.t() | nil
  def segment_id(league_or_region, segment_type) do
    case {league_or_region, segment_type} do
      {%RM.Local.League{metadata: %{keila_segment_id: id}}, :all} -> id
      {%RM.Local.League{metadata: %{keila_coach_segment_id: id}}, :coach} -> id
      {%RM.Local.League{metadata: %{keila_extended_coach_segment_id: id}}, :coach_ext} -> id
      {%RM.FIRST.Region{metadata: %{keila_segment_id: id}}, :all} -> id
      {%RM.FIRST.Region{metadata: %{keila_coach_segment_id: id}}, :coach} -> id
      {%RM.FIRST.Region{metadata: %{keila_extended_coach_segment_id: id}}, :coach_ext} -> id
    end
  end

  @doc "Get a human-readable description for a given segment type"
  @spec segment_description(atom) :: String.t()
  def segment_description(:all), do: "Everyone subscribed to news"
  def segment_description(:coach), do: "Registered coaches"
  def segment_description(:coach_ext), do: "Registered coaches from this season and last season"
end
