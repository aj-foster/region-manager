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
          navigate={~p"/league/#{@league.region}/#{@league}"}
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
          navigate={~p"/league/#{@league.region}/#{@league}/events"}
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
          navigate={~p"/league/#{@league.region}/#{@league}/teams"}
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
      |> Repo.preload(:event_proposals)
      |> Map.update!(:events, &Enum.sort(&1, RM.FIRST.Event))
      |> Map.update!(:event_proposals, &Enum.sort(&1, RM.Local.EventProposal))

    assign(socket, league: league)
  end

  @doc """
  Load events related to the current team
  """
  @spec load_venues(Socket.t()) :: Socket.t()
  def load_venues(socket) do
    league =
      socket.assigns[:league]
      |> Repo.preload(:venues, force: true)
      |> Map.update!(:venues, &Enum.sort(&1, RM.Local.Venue))

    assign(socket, league: league)
  end

  @doc """
  Refresh the current league
  """
  @spec refresh_league(Socket.t()) :: Socket.t()
  @spec refresh_league(Socket.t(), keyword) :: Socket.t()
  def refresh_league(socket, opts \\ []) do
    case socket.assigns[:league] do
      %RM.FIRST.League{code: league_code, region: %RM.FIRST.Region{abbreviation: region_abbr}} ->
        case get_league(region_abbr, league_code) do
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

  def on_mount(
        :preload_league,
        %{"region" => region_abbr, "league" => league_code},
        _session,
        socket
      ) do
    case get_league(region_abbr, league_code) do
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

    if assignment = get_assignment(league, user) do
      {:cont, assign(socket, assignment: assignment)}
    else
      socket =
        socket
        |> LiveView.put_flash(:error, "You do not have permission to perform this action")
        |> LiveView.redirect(to: ~p"/dashboard")

      {:halt, socket}
    end
  end

  @spec get_league(String.t(), String.t()) :: {:ok, League.t()} | {:error, :league, :not_found}
  defp get_league(region_abbr, league_code) do
    preloads = [:region, :settings]

    with {:ok, league} <-
           RM.Local.fetch_league_by_code(region_abbr, league_code, preload: preloads) do
      league =
        league
        |> RM.Repo.preload(teams: RM.Local.Team.active_query(), users: [:profile])
        |> Map.update!(:teams, &Enum.sort(&1, RM.Local.Team))
        |> Map.update!(:users, &Enum.sort(&1, RM.Account.User))

      {:ok, league}
    end
  end

  @spec get_assignment(League.t() | nil, User.t() | nil) :: RM.Account.League.t() | nil
  defp get_assignment(league, user)
  defp get_assignment(nil, _user), do: nil
  defp get_assignment(_league, nil), do: nil

  defp get_assignment(league, user) do
    if is_list(league.user_assignments) do
      Enum.find(league.user_assignments, &(&1.user_id == user.id))
    end
  end
end
