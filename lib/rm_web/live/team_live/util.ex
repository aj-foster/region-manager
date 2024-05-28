defmodule RMWeb.TeamLive.Util do
  use RMWeb, :html

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias RM.Account.User
  alias RM.Local.Team
  alias RM.Repo

  @doc """
  Navigation component for team views
  """
  attr :class, :string, default: nil, doc: "Additional classes for the navigation wrapper"
  attr :team, :any, required: true, doc: "`@team`"
  attr :view, :any, required: true, doc: "`@socket.view`"

  def nav(assigns) do
    ~H"""
    <div class={["flex font-title italic small-caps", @class]}>
      <div class="border-b border-gray-400 w-4"></div>

      <%= if @view == RMWeb.TeamLive.Show do %>
        <div
          class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
          style="background-image: linear-gradient(to bottom, white, transparent)"
        >
          Overview
        </div>
      <% else %>
        <.link
          class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
          navigate={~p"/team/#{@team}"}
        >
          Overview
        </.link>
      <% end %>

      <%= if @view == RMWeb.TeamLive.Events do %>
        <div
          class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
          style="background-image: linear-gradient(to bottom, white, transparent)"
        >
          Events
        </div>
      <% else %>
        <.link
          class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
          navigate={~p"/team/#{@team}/events"}
        >
          Events
        </.link>
      <% end %>

      <div class="border-b border-gray-400 grow"></div>
    </div>
    """
  end

  @doc """
  Load events related to the current team
  """
  @spec load_events(Socket.t()) :: Socket.t()
  def load_events(socket) do
    team =
      socket.assigns[:team]
      |> Repo.preload(:events)
      |> Map.update!(:events, &Enum.sort(&1, RM.FIRST.Event))
      |> Map.update!(:event_registrations, &Enum.sort(&1, RM.Local.EventRegistration))

    assign(socket, team: team)
  end

  @doc """
  Refresh the current team
  """
  @spec refresh_team(Socket.t()) :: Socket.t()
  @spec refresh_team(Socket.t(), keyword) :: Socket.t()
  def refresh_team(socket, opts \\ []) do
    case socket.assigns[:team] do
      %{number: team_number} ->
        case RM.Local.fetch_team_by_number(team_number, preload: [:league, :region]) do
          {:ok, team} ->
            socket
            |> assign(team: team)
            |> then(fn socket -> if opts[:events], do: load_events(socket), else: socket end)

          {:error, :team, :not_found} ->
            socket
        end

      nil ->
        socket
    end
  end

  @doc false
  @spec on_mount(term, map, map, Socket.t()) :: {:cont, Socket.t()}
  def on_mount(name, params, session, socket)

  def on_mount(:preload_team, %{"team" => team_number_str}, _session, socket) do
    case Integer.parse(team_number_str) do
      {team_number, ""} ->
        case RM.Local.fetch_team_by_number(team_number, preload: [:league, :region]) do
          {:ok, team} ->
            {:cont, assign(socket, team: team)}

          {:error, :team, :not_found} ->
            socket =
              socket
              |> LiveView.put_flash(:error, "Team not found")
              |> LiveView.redirect(to: ~p"/dashboard")

            {:halt, socket}
        end

      :error ->
        socket =
          socket
          |> LiveView.put_flash(:error, "Invalid team number")
          |> LiveView.redirect(to: ~p"/dashboard")

        {:halt, socket}
    end
  end

  def on_mount(:require_team_manager, _params, _session, socket) do
    team = socket.assigns[:team]
    user = socket.assigns[:current_user]

    if is_nil(team) or is_nil(user) or not team_owner?(user, team) do
      socket =
        socket
        |> LiveView.put_flash(:error, "You do not have permission to perform this action")
        |> LiveView.redirect(to: ~p"/dashboard")

      {:halt, socket}
    else
      {:cont, socket}
    end
  end

  @spec team_owner?(User.t(), Team.t()) :: boolean
  defp team_owner?(%User{teams: teams}, %Team{id: team_id}) do
    is_list(teams) and Enum.any?(teams, &(&1.id == team_id))
  end
end
