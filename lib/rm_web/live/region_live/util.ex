defmodule RMWeb.RegionLive.Util do
  use RMWeb, :html

  alias RMWeb.EmailLive
  alias RMWeb.EventLive
  alias RMWeb.LeagueLive
  alias RMWeb.ProposalLive
  alias RMWeb.RegionLive
  alias RMWeb.TeamLive
  alias RMWeb.VenueLive

  @doc """
  Unified navigation component for region-level views
  """
  attr :class, :string, default: nil, doc: "Additional classes for the navigation wrapper"
  attr :region, RM.FIRST.Region, required: true, doc: "current region, `@region`"
  attr :season, :integer, required: true, doc: "current season, `@season`"
  attr :user, RM.Account.User, default: nil, doc: "current user, `@current_user`"
  attr :view, :any, required: true, doc: "`@socket.view`"

  def region_nav(assigns) do
    ~H"""
    <.top_nav class={@class}>
      <.nav_item current={@view} navigate={~p"/s/#{@season}/r/#{@region}"} target={RegionLive.Show}>
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
        navigate={~p"/s/#{@season}/r/#{@region}/events"}
        target={EventLive.Index}
      >
        Events
      </.nav_item>
      <.nav_item
        :if={@region.has_leagues}
        children={[LeagueLive.New]}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/leagues"}
        target={LeagueLive.Index}
      >
        Leagues
      </.nav_item>
      <.nav_item
        children={[TeamLive.Map, TeamLive.Show]}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/teams"}
        target={TeamLive.Index}
      >
        Teams
      </.nav_item>
      <.nav_item
        :if={@season == @region.current_season}
        children={[EmailLive.New, EmailLive.Show, EmailLive.Edit, EmailLive.Subscriptions]}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/messages"}
        target={EmailLive.Index}
      >
        News
      </.nav_item>
    </.top_nav>
    """
  end

  @doc """
  Second-level navigation for team list and map views
  """
  attr :class, :string, default: nil, doc: "Additional classes for the navigation wrapper"
  attr :region, RM.FIRST.Region, required: true, doc: "current region, `@region`"
  attr :season, :integer, required: true, doc: "current season, `@season`"
  attr :user, RM.Account.User, default: nil, doc: "current user, `@current_user`"
  attr :view, :any, required: true, doc: "`@socket.view`"

  def team_index_nav(assigns) do
    ~H"""
    <div class={["flex font-title italic overflow-x-auto px-4 small-caps", @class]}>
      <.sub_nav_item
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/teams"}
        target={RMWeb.TeamLive.Index}
      >
        List View
      </.sub_nav_item>
      <.sub_nav_item
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/teams/map"}
        target={RMWeb.TeamLive.Map}
      >
        Map View
      </.sub_nav_item>
    </div>
    """
  end
end
