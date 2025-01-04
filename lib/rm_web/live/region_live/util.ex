defmodule RMWeb.RegionLive.Util do
  use RMWeb, :html

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
    <.top_nav class="mb-8">
      <.nav_item current={@view} navigate={~p"/s/#{@season}/r/#{@region}"} target={RegionLive.Show}>
        Overview
      </.nav_item>
      <.nav_item
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/events"}
        target={EventLive.Index}
      >
        Events
      </.nav_item>
      <.nav_item
        :if={@region.has_leagues}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/leagues"}
        target={LeagueLive.Index}
      >
        Leagues
      </.nav_item>
      <.nav_item
        children={[TeamLive.Show]}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/teams"}
        target={TeamLive.Index}
      >
        Teams
      </.nav_item>
      <.nav_item
        :if={@season == @region.current_season and can?(@user, :proposal_index, @region)}
        children={[ProposalLive.New, ProposalLive.Show, ProposalLive.Edit]}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/proposals"}
        target={ProposalLive.Index}
      >
        Proposals
      </.nav_item>
      <.nav_item
        :if={@season == @region.current_season and can?(@user, :venue_index, @region)}
        children={[VenueLive.New, VenueLive.Show, VenueLive.Edit]}
        current={@view}
        navigate={~p"/s/#{@season}/r/#{@region}/venues"}
        target={VenueLive.Index}
      >
        Venues
      </.nav_item>
    </.top_nav>
    """
  end
end
