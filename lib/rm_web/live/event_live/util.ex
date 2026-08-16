defmodule RMWeb.EventLive.Util do
  use RMWeb, :html

  @doc """
  Second-level navigation for event index views
  """
  attr :class, :string, default: nil, doc: "Additional classes for the navigation wrapper"
  attr :league, :any, required: true, doc: "current league, `@local_league`"
  attr :region, RM.FIRST.Region, required: true, doc: "current region, `@region`"
  attr :season, :integer, required: true, doc: "current season, `@season`"
  attr :user, RM.Account.User, default: nil, doc: "current user, `@current_user`"
  attr :view, :any, required: true, doc: "`@socket.view`"

  def event_index_nav(assigns) do
    ~H"""
    <div
      :if={
        @season == @region.current_season and
          (can?(@user, :proposal_index, @region) or can?(@user, :venue_index, @region))
      }
      class={["flex font-title italic overflow-x-auto px-4 small-caps", @class]}
    >
      <.sub_nav_item
        current={@view}
        navigate={
          if @league,
            do: ~p"/s/#{@season}/r/#{@region}/l/#{@league}/events",
            else: ~p"/s/#{@season}/r/#{@region}/events"
        }
        target={RMWeb.EventLive.Index}
      >
        Published
      </.sub_nav_item>
      <.sub_nav_item
        :if={@season == @region.current_season and can?(@user, :proposal_index, @region)}
        children={[RMWeb.ProposalLive.New, RMWeb.ProposalLive.Show, RMWeb.ProposalLive.Edit]}
        current={@view}
        navigate={
          if @league,
            do: ~p"/s/#{@season}/r/#{@region}/l/#{@league}/proposals",
            else: ~p"/s/#{@season}/r/#{@region}/proposals"
        }
        target={RMWeb.ProposalLive.Index}
      >
        Proposals
      </.sub_nav_item>
      <.sub_nav_item
        :if={@season == @region.current_season and can?(@user, :venue_index, @region)}
        children={[RMWeb.VenueLive.New, RMWeb.VenueLive.Show, RMWeb.VenueLive.Edit]}
        current={@view}
        navigate={
          if @league,
            do: ~p"/s/#{@season}/r/#{@region}/l/#{@league}/venues",
            else: ~p"/s/#{@season}/r/#{@region}/venues"
        }
        target={RMWeb.VenueLive.Index}
      >
        Venues
      </.sub_nav_item>
    </div>
    """
  end

  @doc """
  Unified navigation component for event-level views
  """
  attr :class, :string, default: nil, doc: "Additional classes for the navigation wrapper"
  attr :event, RM.FIRST.Event, required: true, doc: "current event, `@event`"
  attr :league, :any, required: true, doc: "current league, `@local_league`"
  attr :region, RM.FIRST.Region, required: true, doc: "current region, `@region`"
  attr :season, :integer, required: true, doc: "current season, `@season`"
  attr :user, RM.Account.User, default: nil, doc: "current user, `@current_user`"
  attr :view, :any, required: true, doc: "`@socket.view`"

  def event_nav(assigns) do
    ~H"""
    <.top_nav class={@class}>
      <.nav_item
        current={@view}
        navigate={
          if @league,
            do: ~p"/s/#{@season}/r/#{@region}/l/#{@league}/e/#{@event}",
            else: ~p"/s/#{@season}/r/#{@region}/e/#{@event}"
        }
        target={RMWeb.EventLive.Show}
      >
        Overview
      </.nav_item>
      <.nav_item
        current={@view}
        navigate={
          if @league,
            do: ~p"/s/#{@season}/r/#{@region}/l/#{@league}/e/#{@event}/registration",
            else: ~p"/s/#{@season}/r/#{@region}/e/#{@event}/registration"
        }
        target={RMWeb.EventLive.Registration}
      >
        Registration
      </.nav_item>
      <.nav_item
        :if={
          (@user || @event.settings.video_submission) &&
            @event.type not in [:league_meet, :kickoff, :workshop, :demo, :volunteer]
        }
        current={@view}
        navigate={
          if @league,
            do: ~p"/s/#{@season}/r/#{@region}/l/#{@league}/e/#{@event}/awards",
            else: ~p"/s/#{@season}/r/#{@region}/e/#{@event}/awards"
        }
        target={RMWeb.EventLive.Awards}
      >
        Awards
      </.nav_item>
      <.nav_item
        :if={can?(@user, :registration_settings_update, @event)}
        current={@view}
        navigate={
          if @league,
            do: ~p"/s/#{@season}/r/#{@region}/l/#{@league}/e/#{@event}/settings",
            else: ~p"/s/#{@season}/r/#{@region}/e/#{@event}/settings"
        }
        target={RMWeb.EventLive.Settings}
      >
        Settings
      </.nav_item>
    </.top_nav>
    """
  end
end
