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

  pipeline :hook do
    plug :accepts, ["json"]
  end

  #
  # Browser Traffic
  #

  scope "/", RMWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :ambiguous,
      on_mount: [
        {Identity.LiveView, :fetch_identity},
        {RMWeb.Live.Util, :preload_user},
        {RMWeb.Live.Util, :check_season},
        {RMWeb.Live.Util, :check_region},
        {RMWeb.Live.Util, :check_league}
      ] do
      live "/seasons", SeasonLive.Index
      live "/s/new", SeasonLive.New
      live "/s/:season", SeasonLive.Show
      live "/s/:season/r/:region", RegionLive.Show
      live "/s/:season/r/:region/events", EventLive.Index
      live "/s/:season/r/:region/e/:event", EventLive.Show
      live "/s/:season/r/:region/e/:event/awards", EventLive.Awards
      live "/s/:season/r/:region/e/:event/registration", EventLive.Registration
      live "/s/:season/r/:region/e/:event/settings", EventLive.Settings
      live "/s/:season/r/:region/proposals", ProposalLive.Index
      live "/s/:season/r/:region/proposals/new", ProposalLive.New
      live "/s/:season/r/:region/p/:proposal", ProposalLive.Show
      live "/s/:season/r/:region/p/:proposal/edit", ProposalLive.Edit
      live "/s/:season/r/:region/teams", TeamLive.Index
      live "/s/:season/r/:region/t/:team", TeamLive.Show
      live "/s/:season/r/:region/venues", VenueLive.Index
      live "/s/:season/r/:region/venues/new", VenueLive.New
      live "/s/:season/r/:region/v/:venue", VenueLive.Show
      live "/s/:season/r/:region/v/:venue/edit", VenueLive.Edit
      live "/s/:season/r/:region/leagues", LeagueLive.Index
      live "/s/:season/r/:region/l/:league", LeagueLive.Show
      live "/s/:season/r/:region/l/:league/events", EventLive.Index
      live "/s/:season/r/:region/l/:league/e/:event", EventLive.Show
      live "/s/:season/r/:region/l/:league/e/:event/awards", EventLive.Awards
      live "/s/:season/r/:region/l/:league/e/:event/registration", EventLive.Registration
      live "/s/:season/r/:region/l/:league/e/:event/settings", EventLive.Settings
      live "/s/:season/r/:region/l/:league/proposals", ProposalLive.Index
      live "/s/:season/r/:region/l/:league/proposals/new", ProposalLive.New
      live "/s/:season/r/:region/l/:league/p/:proposal", ProposalLive.Show
      live "/s/:season/r/:region/l/:league/p/:proposal/edit", ProposalLive.Edit
      live "/s/:season/r/:region/l/:league/settings", LeagueLive.Settings
      live "/s/:season/r/:region/l/:league/teams", TeamLive.Index
      live "/s/:season/r/:region/l/:league/t/:team", TeamLive.Show
      live "/s/:season/r/:region/l/:league/venues", VenueLive.Index
      live "/s/:season/r/:region/l/:league/venues/new", VenueLive.New
      live "/s/:season/r/:region/l/:league/v/:venue", VenueLive.Show
      live "/s/:season/r/:region/l/:league/v/:venue/edit", VenueLive.Edit
    end

    live_session :authenticated,
      on_mount: [
        {Identity.LiveView, {:redirect_if_unauthenticated, to: "/login"}},
        {RMWeb.Live.Util, :preload_user}
      ] do
      live "/dashboard", DashboardLive.Home
      live "/feedback", DashboardLive.Feedback

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
    get "/r/:region/videos", RegionController, :videos

    # Specific-season endpoints
    get "/s/:season/r/:region", RegionController, :show
    get "/s/:season/r/:region/events", RegionController, :events
    get "/s/:season/r/:region/leagues", RegionController, :leagues
    get "/s/:season/r/:region/teams", RegionController, :teams
    get "/s/:season/r/:region/videos", RegionController, :videos
  end

  #
  # Webhooks
  #

  scope "/hook", RMWeb do
    pipe_through :hook

    post "/ses-delivery", SESController, :delivery
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
