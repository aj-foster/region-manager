defmodule RMWeb.SeasonLive.New do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @impl true
  def mount(_params, _session, socket) do
    with :ok <- require_permission(socket) do
      socket
      |> create_season_form()
      |> assign(page_title: "Create a Season")
      |> ok()
    end
  end

  @spec require_permission(Socket.t()) :: :ok | Socket.t()
  defp require_permission(socket) do
    user = socket.assigns[:current_user]

    if can?(user, :season_create) do
      :ok
    else
      socket
      |> put_flash(:error, "You are not authorized to perform this action")
      |> redirect(to: url_for([:seasons]))
      |> ok()
    end
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("create_season", %{"season" => params}, socket) do
    user = socket.assigns[:current_user]

    if can?(user, :season_create) do
      socket
      |> create_season_submit(params)
      |> noreply()
    else
      socket
      |> put_flash(:error, "You do not have permission to perform this action.")
      |> redirect(to: url_for([:seasons]))
      |> noreply()
    end
  end

  #
  # Helpers
  #

  @spec create_season_form(Socket.t()) :: Socket.t()
  @spec create_season_form(Socket.t(), map) :: Socket.t()
  defp create_season_form(socket, params \\ %{}) do
    form = RM.FIRST.Season.create_changeset(params) |> to_form()
    assign(socket, create_season_form: form)
  end

  @spec create_season_submit(Socket.t(), map) :: Socket.t()
  defp create_season_submit(socket, params) do
    case RM.FIRST.create_season(params) do
      {:ok, _season} ->
        socket
        |> put_flash(:info, "Season created successfully.")
        |> redirect(to: url_for([:seasons]))

      {:error, changeset} ->
        socket
        |> assign(create_season_form: to_form(changeset))
        |> put_flash(:error, "Failed to create season. Please check the form for errors.")
    end
  end
end
