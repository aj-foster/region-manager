defmodule RMWeb.EmailLive.New do
  use RMWeb, :live_view
  import RMWeb.EmailLive.Util

  alias RM.Email

  #
  # Lifecycle
  #

  on_mount {RMWeb.EmailLive.Util, :require_current_season}
  on_mount {RMWeb.EmailLive.Util, :require_permission}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_project()
    |> assign_segments()
    |> assign_sender_id()
    |> assign_subject_prefix()
    |> new_email_form()
    |> ok()
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

  @spec assign_sender_id(Socket.t()) :: Socket.t()
  defp assign_sender_id(socket) do
    league = socket.assigns[:local_league]
    region = socket.assigns[:region]

    if keila_sender_id = (league || region).metadata.keila_sender_id do
      assign(socket, :keila_sender_id, keila_sender_id)
    else
      season = socket.assigns[:season]

      socket
      |> put_flash(
        :error,
        "No email sender found. Please contact an administrator."
      )
      |> push_navigate(to: url_for([season, region]))
    end
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
    sender_id = socket.assigns[:keila_sender_id]
    template_id = socket.assigns[:region].metadata.keila_template_id

    params = Map.put_new(params, "segment_id", List.first(segment_ids))

    if params["segment_id"] not in segment_ids do
      raise ArgumentError, "Invalid segment ID"
    end

    params
    |> Map.merge(%{
      "project_id" => project_id,
      "public_link_enabled" => true,
      "sender_id" => sender_id,
      "template_id" => template_id,
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
