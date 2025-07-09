defmodule SertantaiWeb.Router do
  use SertantaiWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SertantaiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end
  
  pipeline :graphql do
    plug :accepts, ["json"]
  end

  pipeline :require_authenticated_user do
    plug :require_authenticated_user
  end

  pipeline :require_authenticated_user_liveview do
    plug :skip_authentication_for_liveview
  end

  # Custom authentication plug for LiveView - just pass through for now
  def skip_authentication_for_liveview(conn, _opts) do
    conn
  end


  scope "/", SertantaiWeb do
    pipe_through :browser

    get "/", PageController, :home
    
    # Authentication routes
    live "/login", AuthLive, :login
    live "/register", AuthLive, :register
    live "/reset-password", AuthLive, :reset_password
    
    # Keep existing Ash authentication routes for API/fallback
    sign_in_route()
    sign_out_route AuthController
    auth_routes_for Sertantai.Accounts.User, to: AuthController
    reset_route []
  end

  # Protected routes
  scope "/", SertantaiWeb do
    pipe_through [:browser, :require_authenticated_user_liveview]

    live "/dashboard", DashboardLive
    live "/profile", AuthLive, :profile
    live "/change-password", AuthLive, :change_password
    live "/sync-configs", SyncConfigLive.Index
    live "/sync-configs/new", SyncConfigLive.New
    live "/sync-configs/:id/edit", SyncConfigLive.Edit
    live "/records", RecordSelectionLive, :index
  end

  # GraphQL API
  scope "/api" do
    pipe_through :graphql
    
    forward "/graphql", Absinthe.Plug, schema: Sertantai.Schema
    
    if Mix.env() == :dev do
      forward "/graphiql", Absinthe.Plug.GraphiQL, schema: Sertantai.Schema
    end
  end
  
  # JSON API endpoints will be defined by the resource directly

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:sertantai, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SertantaiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
