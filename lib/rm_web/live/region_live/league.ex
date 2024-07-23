defmodule RMWeb.RegionLive.League do
  use RMWeb, :live_view
  import RMWeb.RegionLive.Util

  #
  # Lifecycle
  #

  on_mount {RMWeb.RegionLive.Util, :preload_region}
  on_mount {RMWeb.RegionLive.Util, :require_region_manager}
  on_mount {__MODULE__, :preload_league}

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(remove_user: nil)
    |> add_user_form()
    |> ok()
  end

  def on_mount(:preload_league, %{"league" => league_code}, _session, socket) do
    region = socket.assigns[:region]

    case RM.FIRST.fetch_league_by_code(region.abbreviation, league_code, preload: [:region]) do
      {:ok, league} ->
        league =
          league
          |> RM.Repo.preload([:events, :teams, users: [:profile]])
          |> Map.update!(:events, &Enum.sort(&1, RM.FIRST.Event))
          |> Map.update!(:teams, &Enum.sort(&1, RM.Local.Team))

        {:cont, assign(socket, league: league)}

      {:error, :league, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "League not found")
          |> redirect(to: ~p"/dashboard")

        {:halt, socket}
    end
  end

  #
  # Events
  #

  @impl true
  def handle_event(event, unsigned_params, socket)

  def handle_event("add_user_change", %{"league" => params}, socket) do
    socket
    |> add_user_form(params)
    |> noreply()
  end

  def handle_event("add_user_submit", %{"league" => params}, socket) do
    socket
    |> add_user_submit(params)
    |> noreply()
  end

  def handle_event("remove_user_cancel", _params, socket) do
    socket
    |> remove_user_cancel()
    |> noreply()
  end

  def handle_event("remove_user_init", %{"assignment" => assignment_id}, socket) do
    socket
    |> remove_user_init(assignment_id)
    |> noreply()
  end

  def handle_event("remove_user_submit", _params, socket) do
    socket
    |> remove_user_submit()
    |> noreply()
  end

  #
  # Helpers
  #

  @spec add_user_form(Socket.t()) :: Socket.t()
  defp add_user_form(socket, params \\ %{"permissions" => %{"users" => true}}) do
    league = socket.assigns[:league]
    form = RM.Account.League.create_changeset(league, params) |> to_form()
    assign(socket, add_user_form: form)
  end

  @spec add_user_submit(Socket.t(), map) :: Socket.t()
  defp add_user_submit(socket, params) do
    league = socket.assigns[:league]

    case RM.Account.add_league_user(league, params) do
      {:ok, _assignment} ->
        league = RM.Repo.preload(league, [users: [:profile]], force: true)

        socket
        |> assign(league: league)
        |> put_flash(:info, "League administrator added successfully")
        |> push_js("#league-add-user-modal", "data-cancel")
        |> add_user_form()

      {:error, changeset} ->
        assign(socket, add_user_form: to_form(changeset))
    end
  end

  @spec remove_user_cancel(Socket.t()) :: Socket.t()
  defp remove_user_cancel(socket) do
    socket
    |> assign(remove_user: nil)
    |> push_js("#league-remove-user-modal", "data-cancel")
  end

  @spec remove_user_init(Socket.t(), Ecto.UUID.t()) :: Socket.t()
  defp remove_user_init(socket, assignment_id) do
    league = socket.assigns[:league]

    if assignment = Enum.find(league.user_assignments, &(&1.id == assignment_id)) do
      socket
      |> assign(remove_user: assignment)
      |> push_js("#league-remove-user-modal", "data-show")
    else
      league = RM.Repo.preload(league, [users: [:profile]], force: true)

      socket
      |> assign(league: league)
      |> put_flash(:error, "An error occurred; please try again")
    end
  end

  @spec remove_user_submit(Socket.t()) :: Socket.t()
  defp remove_user_submit(socket) do
    assignment = socket.assigns[:remove_user]
    league = socket.assigns[:league]

    case RM.Repo.delete(assignment) do
      {:ok, _assignment} ->
        league = RM.Repo.preload(league, [users: [:profile]], force: true)

        socket
        |> assign(league: league, remove_user: nil)
        |> put_flash(:info, "League administrator removed successfully")
        |> push_js("#league-remove-user-modal", "data-cancel")

      {:error, _changeset} ->
        league = RM.Repo.preload(league, [users: [:profile]], force: true)

        socket
        |> assign(league: league, remove_user: nil)
        |> put_flash(:error, "An error occurred; please try again")
        |> push_js("#league-remove-user-modal", "data-cancel")
    end
  end
end
