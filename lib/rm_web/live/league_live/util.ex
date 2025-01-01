defmodule RMWeb.LeagueLive.Util do
  use RMWeb, :html
  import RMWeb.Live.Util

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias RM.Account.User
  alias RM.FIRST.League
  alias RM.Repo

  alias RMWeb.EventLive
  alias RMWeb.LeagueLive
  alias RMWeb.ProposalLive
  alias RMWeb.TeamLive
  alias RMWeb.VenueLive

  @doc """
  Unified navigation component for league-level views
  """
  attr :class, :string, default: nil, doc: "Additional classes for the navigation wrapper"
  attr :league, :any, required: true, doc: "current league, `@local_league`"
  attr :region, RM.FIRST.Region, required: true, doc: "current region, `@region`"
  attr :season, :integer, required: true, doc: "current season, `@season`"
  attr :user, RM.Account.User, default: nil, doc: "current user, `@current_user`"
  attr :view, :any, required: true, doc: "`@socket.view`"

  def league_nav(assigns) do
    ~H"""
    <.top_nav class="mb-8">
      <.nav_item
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/l/#{@league}"}
        target={LeagueLive.Show}
      >
        Overview
      </.nav_item>
      <.nav_item
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/l/#{@league}/events"}
        target={EventLive.Index}
      >
        Events
      </.nav_item>
      <%!-- <.nav_item
        :if={@region.has_leagues}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/l/#{@league}/leagues"}
        target={LeagueLive.Index}
      >
        Leagues
      </.nav_item> --%>
      <.nav_item
        children={[TeamLive.Show]}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/l/#{@league}/teams"}
        target={TeamLive.Index}
      >
        Teams
      </.nav_item>
      <.nav_item
        :if={@season == @region.current_season and can?(@user, :proposal_index, @league)}
        children={[ProposalLive.New, ProposalLive.Show, ProposalLive.Edit]}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/l/#{@league}/proposals"}
        target={ProposalLive.Index}
      >
        Proposals
      </.nav_item>
      <.nav_item
        :if={@season == @region.current_season and can?(@user, :venue_index, @league)}
        children={[VenueLive.New, VenueLive.Show, VenueLive.Edit]}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/l/#{@league}/venues"}
        target={VenueLive.Index}
      >
        Venues
      </.nav_item>
    </.top_nav>
    """
  end

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

      <%= if @view == LeagueLive.Show do %>
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

      <%= cond do %>
        <% @view == LeagueLive.Event.Index -> %>
          <div
            class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
            style="background-image: linear-gradient(to bottom, white, transparent)"
          >
            Events
          </div>
        <% @view in [LeagueLive.Event.Show] -> %>
          <.link
            class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
            navigate={~p"/league/#{@league.region}/#{@league}/events"}
            style="background-image: linear-gradient(to bottom, white, transparent)"
          >
            Events
          </.link>
        <% :else -> %>
          <.link
            class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
            navigate={~p"/league/#{@league.region}/#{@league}/events"}
          >
            Events
          </.link>
      <% end %>

      <%= cond do %>
        <% @view == LeagueLive.Team.Index -> %>
          <div
            class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
            style="background-image: linear-gradient(to bottom, white, transparent)"
          >
            Teams
          </div>
        <% @view in [LeagueLive.Team.Show] -> %>
          <.link
            class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
            navigate={~p"/league/#{@league.region}/#{@league}/teams"}
            style="background-image: linear-gradient(to bottom, white, transparent)"
          >
            Teams
          </.link>
        <% :else -> %>
          <.link
            class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
            navigate={~p"/league/#{@league.region}/#{@league}/teams"}
          >
            Teams
          </.link>
      <% end %>

      <%= cond do %>
        <% @view == LeagueLive.Venue.Index -> %>
          <div
            class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
            style="background-image: linear-gradient(to bottom, white, transparent)"
          >
            Venues
          </div>
        <% @view in [LeagueLive.Venue.Show, LeagueLive.Venue.New, LeagueLive.Venue.Edit] -> %>
          <.link
            class="border border-b-slate-100 border-gray-400 px-4 py-2 rounded-t"
            navigate={~p"/league/#{@league.region}/#{@league}/venues"}
            style="background-image: linear-gradient(to bottom, white, transparent)"
          >
            Venues
          </.link>
        <% :else -> %>
          <.link
            class="border-b border-b-gray-400 border-t border-t-slate-100 px-4 py-2 transition-colors hover:text-gray-500"
            navigate={~p"/league/#{@league.region}/#{@league}/venues"}
          >
            Venues
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
    season = socket.assigns[:league].region.current_season

    league =
      socket.assigns[:league]
      |> Repo.preload(events: RM.FIRST.Event.season_query(season))
      |> Repo.preload(:event_proposals)
      |> Map.update!(:events, &Enum.sort(&1, RM.FIRST.Event))
      |> Map.update!(:event_proposals, &Enum.sort(&1, RM.Local.EventProposal))

    assign(socket, league: league, page_title: "#{league.name} Events")
  end

  @doc """
  Load venues related to the current league
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
      %RM.Local.League{code: league_code, region: %RM.FIRST.Region{abbreviation: region_abbr}} ->
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

  @doc """
  Require certain permission to continue; otherwise see a flash error
  """
  @spec require_permission(Socket.t(), atom) :: :ok | {:noreply, Socket.t()}
  def require_permission(socket, permission) do
    if Map.get(socket.assigns[:assignment].permissions, permission, false) do
      :ok
    else
      socket
      |> LiveView.put_flash(:error, "You are not authorized to perform this action")
      |> noreply()
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

  def on_mount({:require_league_manager, permission}, _params, _session, socket) do
    league = socket.assigns[:league]
    user = socket.assigns[:current_user]
    assignment = get_assignment(league, user)

    if assignment && Map.get(assignment.permissions, permission, false) do
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
        |> RM.Repo.preload([:teams, users: [:profile]])
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
