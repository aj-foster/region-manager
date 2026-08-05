defmodule RMWeb.EmailLive.New do
  use RMWeb, :live_view
  import RMWeb.EmailLive.Util, only: [segment_options: 1, validate_params: 2]

  #
  # Lifecycle
  #

  on_mount {RMWeb.EmailLive.Util, :require_current_season}
  on_mount {RMWeb.EmailLive.Util, :require_permission}
  on_mount {RMWeb.EmailLive.Util, :require_keila_records}

  @impl true
  def mount(_params, _session, socket) do
    socket
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

  #
  # Template Helpers
  #

  @spec text_or_placeholder(String.t() | nil) :: String.t()
  defp text_or_placeholder(""), do: "_"
  defp text_or_placeholder(nil), do: "_"
  defp text_or_placeholder(text), do: text
end
