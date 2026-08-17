defmodule RMWeb.LeagueLive.Util do
  use RMWeb, :html

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
    <.top_nav class={@class}>
      <.nav_item
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/l/#{@league}"}
        target={LeagueLive.Show}
      >
        Overview
      </.nav_item>
      <.nav_item
        children={[
          ProposalLive.Index,
          ProposalLive.New,
          ProposalLive.Show,
          ProposalLive.Edit,
          VenueLive.Index,
          VenueLive.New,
          VenueLive.Show,
          VenueLive.Edit
        ]}
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
        :if={@league.settings && @league.settings.enable_email}
        children={[RMWeb.EmailLive.New, RMWeb.EmailLive.Show, RMWeb.EmailLive.Edit]}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/l/#{@league}/messages"}
        target={RMWeb.EmailLive.Index}
      >
        News
      </.nav_item>
      <.nav_item
        :if={@season == @region.current_season and can?(@user, :league_settings_update, @league)}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/l/#{@league}/settings"}
        target={LeagueLive.Settings}
      >
        Settings
      </.nav_item>
    </.top_nav>
    """
  end
end
