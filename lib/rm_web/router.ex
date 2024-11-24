defmodule RMWeb.Router do
  use RMWeb, :router
  import Identity.Plug
  import RMWeb.Version, only: [fetch_version: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :fetch_identity
    plug :put_root_layout, html: {RMWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :app_layout do
    plug :put_layout, html: {RMWeb.Layouts, :app}
  end

  pipeline :identity_html do
    plug :put_view, RMWeb.IdentityHTML
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_version
  end

  #
  # Browser Traffic
  #

  scope "/", RMWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :ambiguous,
      on_mount: [{Identity.LiveView, :fetch_identity}, {RMWeb.Live.Util, :preload_user}] do
      live "/s", SeasonLive.Index
      live "/s/:season", SeasonLive.Show
      live "/s/:season/r/:region/events", EventLive.Index
      live "/s/:season/r/:region/e/:event", EventLive.Show
    end

    live_session :authenticated,
      on_mount: [
        {Identity.LiveView, {:redirect_if_unauthenticated, to: "/login"}},
        {RMWeb.Live.Util, :preload_user}
      ] do
      live "/dashboard", DashboardLive.Home
      live "/feedback", DashboardLive.Feedback

      live "/league/:region/:league", LeagueLive.Show
      live "/league/:region/:league/events", LeagueLive.Event.Index
      live "/league/:region/:league/events/new", LeagueLive.Proposal.New
      live "/league/:region/:league/events/:event", LeagueLive.Event.Show
      live "/league/:region/:league/events/proposal/:event", LeagueLive.Proposal.Show
      live "/league/:region/:league/events/proposal/:event/edit", LeagueLive.Proposal.Edit
      live "/league/:region/:league/teams", LeagueLive.Team.Index
      live "/league/:region/:league/teams/:team", LeagueLive.Team.Show
      live "/league/:region/:league/venues", LeagueLive.Venue.Index
      live "/league/:region/:league/venues/new", LeagueLive.Venue.New
      live "/league/:region/:league/venues/:venue", LeagueLive.Venue.Show
      live "/league/:region/:league/venues/:venue/edit", LeagueLive.Venue.Edit

      live "/region/:region", RegionLive.Overview
      live "/region/:region/events", RegionLive.Event.Index
      live "/region/:region/events/:event", RegionLive.Event.Show
      live "/region/:region/leagues", RegionLive.League.Index
      live "/region/:region/leagues/:league", RegionLive.League.Show
      live "/region/:region/teams", RegionLive.Team.Index
      live "/region/:region/teams/:team", RegionLive.Team.Show
      live "/region/:region/setup", RegionLive.Setup

      live "/team/:team", TeamLive.Show
      live "/team/:team/events", TeamLive.Events
      live "/team/:team/events/:event", TeamLive.Event

      live "/user/settings", UserLive.Settings
    end
  end

  scope "/" do
    pipe_through [:browser, :app_layout]

    scope "/" do
      pipe_through [:identity_html]

      # Session
      get "/login", Identity.Controller, :new_session, as: :identity
    end

    # Session
    post "/login", Identity.Controller, :create_session,
      as: :identity,
      private: %{after_login: "/dashboard"}

    get "/login/2fa", Identity.Controller, :pending_2fa, as: :identity

    post "/login/2fa", Identity.Controller, :validate_2fa,
      as: :identity,
      private: %{after_validate: "/dashboard"}

    delete "/logout", Identity.Controller, :delete_session, as: :identity

    # Password Reset
    get "/password/new", Identity.Controller, :new_password_token, as: :identity
    post "/password/new", Identity.Controller, :create_password_token, as: :identity

    get "/password/:token", Identity.Controller, :new_password, as: :identity
    put "/password/:token", Identity.Controller, :create_password, as: :identity

    # Email Addresses
    get "/user/email/new", Identity.Controller, :new_email, as: :identity
    post "/user/email/new", Identity.Controller, :create_email, as: :identity
    get "/user/email/:token", RMWeb.IdentityController, :confirm_email, as: :identity

    delete "/user/email", Identity.Controller, :delete_email, as: :identity

    # User Registration
    get "/register", RMWeb.IdentityController, :new_user, as: :identity
    post "/register", RMWeb.IdentityController, :create_user, as: :identity
    get "/register/post", RMWeb.IdentityController, :after_create_user
    get "/register/error", RMWeb.IdentityController, :deny_create_user

    # User Settings
    get "/user/password", Identity.Controller, :edit_password, as: :identity
    put "/user/password", Identity.Controller, :update_password, as: :identity

    get "/user/2fa/new", Identity.Controller, :new_2fa, as: :identity
    post "/user/2fa/new", Identity.Controller, :create_2fa, as: :identity
    get "/user/2fa", Identity.Controller, :show_2fa, as: :identity
    delete "/user/2fa", Identity.Controller, :delete_2fa, as: :identity
    put "/user/2fa/backup", Identity.Controller, :regenerate_2fa, as: :identity
  end

  #
  # JSON API
  #

  scope "/api", RMWeb do
    pipe_through :api

    # # Metadata
    get "/", MetaController, :index
    get "/meta/regions", MetaController, :regions
    get "/meta/seasons", MetaController, :seasons

    # Current-season endpoints
    get "/r/:region", RegionController, :show
    get "/r/:region/events", RegionController, :events
    get "/r/:region/leagues", RegionController, :leagues
    get "/r/:region/teams", RegionController, :teams

    # Specific-season endpoints
    get "/s/:season/r/:region", RegionController, :show
    get "/s/:season/r/:region/events", RegionController, :events
    get "/s/:season/r/:region/leagues", RegionController, :leagues
    get "/s/:season/r/:region/teams", RegionController, :teams
  end

  #
  # Development
  #

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:rm, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: RMWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
