defmodule RMWeb.LeagueLive.Util do
  use RMWeb, :html

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias RM.Account.User
  alias RM.FIRST.League
  alias RM.Repo

  @doc """
  Navigation component for league views
  """
  attr :class, :string, default: nil, doc: "Additional classes for the navigation wrapper"
  attr :league, :any, required: true, doc: "`@league`"
  attr :view, :any, required: true, doc: "`@socket.view`"

  def nav(assigns) do
    ~H"""
    <div class={["flex font-title italic small-caps", @class]}>
      <div class="border-b border-gray-400 w-4"></div>

      <%= if @view == RMWeb.LeagueLive.Show do %>
        <div
          class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
          style="background-image: linear-gradient(to bottom, white, transparent)"
        >
          Overview
        </div>
      <% else %>
        <.link
          class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
          navigate={~p"/league/#{@league}"}
        >
          Overview
        </.link>
      <% end %>

      <%= if @view == RMWeb.LeagueLive.Events do %>
        <div
          class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
          style="background-image: linear-gradient(to bottom, white, transparent)"
        >
          Events
        </div>
      <% else %>
        <.link
          class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
          navigate={~p"/league/#{@league}/events"}
        >
          Events
        </.link>
      <% end %>

      <%= if @view == RMWeb.LeagueLive.Teams do %>
        <div
          class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
          style="background-image: linear-gradient(to bottom, white, transparent)"
        >
          Teams
        </div>
      <% else %>
        <.link
          class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
          navigate={~p"/league/#{@league}/teams"}
        >
          Teams
        </.link>
      <% end %>

      <div class="border-b border-gray-400 grow"></div>
    </div>
    """
  end

  @doc """
  Load events related to the current league
  """
  @spec load_events(Socket.t()) :: Socket.t()
  def load_events(socket) do
    league =
      socket.assigns[:league]
      |> Repo.preload(:events)
      |> Map.update!(:events, &sort_events/1)

    assign(socket, league: league)
  end

  @doc """
  Refresh the current league
  """
  @spec refresh_league(Socket.t()) :: Socket.t()
  @spec refresh_league(Socket.t(), keyword) :: Socket.t()
  def refresh_league(socket, opts \\ []) do
    case socket.assigns[:league] do
      %{code: league_code} ->
        case get_league(league_code) do
          {:ok, league} ->
            socket
            |> assign(league: league)
            |> then(fn socket -> if opts[:events], do: load_events(socket), else: socket end)

          {:error, :league, :not_found} ->
            socket
        end

      nil ->
        socket
    end
  end

  @doc false
  @spec on_mount(term, map, map, Socket.t()) :: {:cont, Socket.t()}
  def on_mount(name, params, session, socket)

  def on_mount(:preload_league, %{"league" => league_code}, _session, socket) do
    case get_league(league_code) do
      {:ok, league} ->
        {:cont, assign(socket, league: league)}

      {:error, :league, :not_found} ->
        socket =
          socket
          |> LiveView.put_flash(:error, "League not found")
          |> LiveView.redirect(to: ~p"/dashboard")

        {:halt, socket}
    end
  end

  def on_mount(:require_league_manager, _params, _session, socket) do
    league = socket.assigns[:league]
    user = socket.assigns[:current_user]

    if is_nil(league) or is_nil(user) or not league_owner?(user, league) do
      socket =
        socket
        |> LiveView.put_flash(:error, "You do not have permission to perform this action")
        |> LiveView.redirect(to: ~p"/dashboard")

      {:halt, socket}
    else
      {:cont, socket}
    end
  end

  @spec get_league(Ecto.UUID.t()) :: {:ok, League.t()} | {:error, :league, :not_found}
  defp get_league(league_code) do
    case RM.FIRST.get_league_by_code(league_code, preload: [:region, :settings, :teams]) do
      nil -> {:error, :league, :not_found}
      league -> {:ok, Map.update!(league, :teams, &sort_teams/1)}
    end
  end

  @spec league_owner?(User.t(), League.t()) :: boolean
  defp league_owner?(%User{leagues: leagues}, %League{id: league_id}) do
    is_list(leagues) and Enum.any?(leagues, &(&1.id == league_id))
  end

  @spec sort_events([RM.FIRST.Event.t()]) :: [RM.FIRST.Event.t()]
  defp sort_events(events) do
    Enum.sort_by(events, & &1.date_start, Date)
  end

  @spec sort_teams([RM.Local.Team.t()]) :: [RM.Local.Team.t()]
  defp sort_teams(teams) do
    Enum.sort_by(teams, & &1.number)
  end
end
