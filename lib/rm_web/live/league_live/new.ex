defmodule RMWeb.LeagueLive.New do
  use RMWeb, :live_view

  #
  # Lifecycle
  #

  @doc false
  @impl true
  def mount(_params, _session, socket) do
    with :ok <- require_permission(socket) do
      socket
      |> create_league_form()
      |> ok()
    end
  end

  @spec require_permission(Socket.t()) :: :ok | Socket.t()
  defp require_permission(socket) do
    region = socket.assigns[:region]
    season = socket.assigns[:season]
    user = socket.assigns[:current_user]

    if can?(user, :league_create, region) do
      :ok
    else
      socket
      |> put_flash(:error, "You do not have permission to perform this action.")
      |> redirect(to: url_for([season, region, :leagues]))
      |> ok()
    end
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("create_league_change", %{"league" => params}, socket) do
    region = socket.assigns[:region]
    user = socket.assigns[:current_user]

    if can?(user, :league_create, region) do
      socket
      |> create_league_form(params)
      |> noreply()
    else
      socket
      |> put_flash(:error, "You do not have permission to perform this action.")
      |> noreply()
    end
  end

  def handle_event("create_league_submit", %{"league" => params}, socket) do
    region = socket.assigns[:region]
    user = socket.assigns[:current_user]

    if can?(user, :league_create, region) do
      socket
      |> create_league_submit(params)
      |> noreply()
    else
      socket
      |> put_flash(:error, "You do not have permission to perform this action.")
      |> noreply()
    end
  end

  #
  # Helpers
  #

  @spec create_league_form(Socket.t()) :: Socket.t()
  @spec create_league_form(Socket.t(), map) :: Socket.t()
  defp create_league_form(socket, params \\ %{}) do
    region = socket.assigns[:region]
    form = RM.Local.League.create_changeset(region, params) |> to_form()
    assign(socket, create_league_form: form)
  end

  @spec create_league_submit(Socket.t(), map) :: Socket.t()
  defp create_league_submit(socket, params) do
    region = socket.assigns[:region]
    season = socket.assigns[:season]

    case RM.Local.create_league(region, params) do
      {:ok, new_league} ->
        socket
        |> put_flash(:info, "League created successfully")
        |> push_navigate(to: url_for([season, region, new_league]), replace: true)

      {:error, changeset} ->
        assign(socket, create_league_form: to_form(changeset))
    end
  end

  #
  # Template Helpers
  #

  defp example_full_name(region, league_form) do
    league_name =
      if league_form[:name].value in ["", nil] do
        "_"
      else
        league_form[:name].value
      end

    "#{region.name} #{league_name} League"
  end
end
