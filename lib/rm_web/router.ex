defmodule RMWeb.Router do
  use RMWeb, :router
  import Identity.Plug

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :fetch_identity
    plug :put_root_layout, html: {RMWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RMWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/demo", RMWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: [{Identity.LiveView, {:redirect_if_unauthenticated, to: "/login"}}] do
      live "/region/import", RegionLive.Import
    end
  end

  scope "/" do
    pipe_through :browser

    # Session
    get "/login", Identity.Controller, :new_session, as: :identity
    post "/login", Identity.Controller, :create_session, as: :identity

    get "/login/2fa", Identity.Controller, :pending_2fa, as: :identity
    post "/login/2fa", Identity.Controller, :validate_2fa, as: :identity

    delete "/logout", Identity.Controller, :delete_session, as: :identity

    # Password Reset
    get "/password/new", Identity.Controller, :new_password_token, as: :identity
    post "/password/new", Identity.Controller, :create_password_token, as: :identity

    get "/password/:token", Identity.Controller, :new_password, as: :identity
    put "/password/:token", Identity.Controller, :create_password, as: :identity

    # Email Addresses
    get "/user/email/new", Identity.Controller, :new_email, as: :identity
    post "/user/email/new", Identity.Controller, :create_email, as: :identity
    get "/user/email/:token", Identity.Controller, :confirm_email, as: :identity
    delete "/user/email", Identity.Controller, :delete_email, as: :identity

    # User Registration
    get "/register", Identity.Controller, :new_user, as: :identity
    post "/register", Identity.Controller, :create_user, as: :identity

    # User Settings
    get "/user/password", Identity.Controller, :edit_password, as: :identity
    put "/user/password", Identity.Controller, :update_password, as: :identity

    get "/user/2fa/new", Identity.Controller, :new_2fa, as: :identity
    post "/user/2fa/new", Identity.Controller, :create_2fa, as: :identity
    get "/user/2fa", Identity.Controller, :show_2fa, as: :identity
    delete "/user/2fa", Identity.Controller, :delete_2fa, as: :identity
    put "/user/2fa/backup", Identity.Controller, :regenerate_2fa, as: :identity
  end

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