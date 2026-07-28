defmodule RMWeb.EmailLive.New do
  use RMWeb, :live_view

  alias RM.Email

  @impl true
  def mount(_params, _session, socket) do
    with :ok <- require_permission(socket) do
      socket
      |> assign_area_name()
      |> assign_project()
      |> assign_segments()
      |> assign_subject_prefix()
      |> new_email_form()
      |> ok()
    end
  end

  @spec require_permission(Socket.t()) :: :ok | Socket.t()
  defp require_permission(socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    user = socket.assigns[:current_user]

    redirect_target = url_for([season, region, league])

    cond do
      season > region.current_season ->
        socket
        |> put_flash(:error, "Messaging for #{season} is not yet available.")
        |> push_navigate(to: redirect_target)
        |> ok()

      season < region.current_season ->
        socket
        |> put_flash(:error, "Messaging for #{season} is no longer available.")
        |> push_navigate(to: redirect_target)
        |> ok()

      can?(user, :email_message_send, league || region) ->
        :ok

      :else ->
        socket
        |> put_flash(
          :error,
          "You do not have permission to send messages for this #{if league, do: "league", else: "region"}."
        )
        |> push_navigate(to: redirect_target)
        |> ok()
    end
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("validate_email", %{"campaign" => params}, socket) do
    socket
    |> new_email_form(params)
    |> noreply()
  end

  def handle_event("create_email", %{"campaign" => params}, socket) do
    socket
    |> create_email(params)
    |> noreply()
  end

  #
  # Helpers
  #

  @spec assign_area_name(Socket.t()) :: Socket.t()
  defp assign_area_name(socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]

    area_name =
      if league do
        "#{league.name} League"
      else
        "#{region.name} Region"
      end

    assign(socket, :area_name, area_name)
  end

  @spec assign_project(Socket.t()) :: Socket.t()
  defp assign_project(socket) do
    season = socket.assigns[:season]
    region = socket.assigns[:region]

    if keila_project = Email.get_keila_project(region) do
      assign(socket, :keila_project, keila_project)
    else
      socket
      |> put_flash(
        :error,
        "No email project found for this region. Please contact an administrator."
      )
      |> push_navigate(to: url_for([season, region]))
    end
  end

  @spec assign_segments(Socket.t()) :: Socket.t()
  defp assign_segments(socket) do
    keila_segments =
      %{
        all: get_segment(socket, :all),
        coach: get_segment(socket, :coach),
        coach_ext: get_segment(socket, :coach_ext)
      }
      |> Map.reject(fn {_key, value} -> is_nil(value) end)

    if map_size(keila_segments) == 3 do
      assign(socket, :keila_segments, keila_segments)
    else
      season = socket.assigns[:season]
      region = socket.assigns[:region]
      area_name = socket.assigns[:area_name]

      socket
      |> put_flash(
        :error,
        "One or more email segments are missing for #{area_name}. Please contact an administrator."
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
        name: segment_name(socket.assigns[:area_name], segment_type),
        segment: segment
      }
    end
  end

  @spec segment_id(RM.Local.League.t() | RM.FIRST.Region.t(), atom) :: String.t() | nil
  defp segment_id(league_or_region, segment_type) do
    case {league_or_region, segment_type} do
      {%RM.Local.League{metadata: %{keila_segment_id: id}}, :all} -> id
      {%RM.Local.League{metadata: %{keila_coach_segment_id: id}}, :coach} -> id
      {%RM.Local.League{metadata: %{keila_extended_coach_segment_id: id}}, :coach_ext} -> id
      {%RM.FIRST.Region{metadata: %{keila_segment_id: id}}, :all} -> id
      {%RM.FIRST.Region{metadata: %{keila_coach_segment_id: id}}, :coach} -> id
      {%RM.FIRST.Region{metadata: %{keila_extended_coach_segment_id: id}}, :coach_ext} -> id
    end
  end

  @spec segment_name(String.t(), atom) :: String.t()
  defp segment_name(area_name, :all), do: "Everyone subscribed to #{area_name} news"
  defp segment_name(area_name, :coach), do: "Registered #{area_name} coaches"

  defp segment_name(area_name, :coach_ext) do
    "Registered #{area_name} coaches from this season and last season"
  end

  @spec assign_subject_prefix(Socket.t()) :: Socket.t()
  defp assign_subject_prefix(socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]
    prefix = prefix(league || region)

    assign(socket, :subject_prefix, prefix)
  end

  @spec create_email(Socket.t(), map) :: Socket.t()
  defp create_email(socket, params) do
    params = validate_params(socket, params)
    project_id = socket.assigns[:keila_project].id

    case Keila.Mailings.create_campaign(project_id, params) do
      {:ok, campaign} ->
        season = socket.assigns[:season]
        region = socket.assigns[:region]
        league = socket.assigns[:local_league]

        socket
        |> put_flash(:info, "Email created successfully.")
        |> push_navigate(to: url_for([season, region, league, campaign, :edit]))

      {:error, changeset} ->
        assign(socket, new_email_form: to_form(changeset))
    end
  end

  @spec new_email_form(Socket.t()) :: Socket.t()
  @spec new_email_form(Socket.t(), map) :: Socket.t()
  defp new_email_form(socket, params \\ %{}) do
    socket
    |> validate_params(params)
    |> Keila.Mailings.Campaign.creation_changeset()
    |> to_form()
    |> then(&assign(socket, new_email_form: &1))
  end

  @spec prefix(RM.FIRST.Region.t() | RM.Local.League.t()) :: String.t() | nil
  defp prefix(%RM.FIRST.Region{metadata: %{email_prefix: ""}}), do: nil
  defp prefix(%RM.FIRST.Region{metadata: %{email_prefix: nil}}), do: nil
  defp prefix(%RM.FIRST.Region{metadata: %{email_prefix: prefix}}), do: "[#{prefix}] "
  defp prefix(%RM.Local.League{metadata: %{email_prefix: ""}}), do: nil
  defp prefix(%RM.Local.League{metadata: %{email_prefix: nil}}), do: nil
  defp prefix(%RM.Local.League{metadata: %{email_prefix: prefix}}), do: "[#{prefix}] "

  @spec validate_params(Socket.t(), map) :: map
  defp validate_params(socket, params) do
    project_id = socket.assigns[:keila_project].id
    segment_ids = Enum.map(socket.assigns[:keila_segments], fn {_, info} -> info.segment.id end)
    params = Map.put_new(params, "segment_id", List.first(segment_ids))

    if params["segment_id"] not in segment_ids do
      raise ArgumentError, "Invalid segment ID"
    end

    params
    |> Map.merge(%{
      "project_id" => project_id,
      "public_link_enabled" => true,
      "settings" => %{"type" => "markdown", "do_not_track" => true}
    })
  end

  #
  # Template Helpers
  #

  @spec segment_options(map) :: [{String.t(), String.t()}]
  defp segment_options(%{all: all_info, coach: coach_info, coach_ext: coach_ext_info}) do
    [
      {all_info.name <> " (#{all_info.count})", all_info.segment.id},
      {coach_info.name <> " (#{coach_info.count})", coach_info.segment.id},
      {coach_ext_info.name <> " (#{coach_ext_info.count})", coach_ext_info.segment.id}
    ]
  end

  @spec text_or_placeholder(String.t() | nil) :: String.t()
  defp text_or_placeholder(""), do: "_"
  defp text_or_placeholder(nil), do: "_"
  defp text_or_placeholder(text), do: text
end
