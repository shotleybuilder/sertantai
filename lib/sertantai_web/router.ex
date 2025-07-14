defmodule SertantaiWeb.Router do
  use SertantaiWeb, :router
  use AshAuthentication.Phoenix.Router
  import AshAdmin.Router

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

  pipeline :require_admin_authentication do
    plug :require_admin_authentication
  end

  # Custom authentication plug for LiveView - pass through, auth handled in LiveView mount
  def skip_authentication_for_liveview(conn, _opts) do
    conn
  end

  # Authentication plug for API routes (bearer token based)
  def require_authenticated_user(conn, _opts) do
    case AshAuthentication.Plug.Helpers.retrieve_from_bearer(conn, Sertantai.Accounts.User) do
      {:ok, user} when not is_nil(user) ->
        # User is authenticated via bearer token
        conn
        |> Plug.Conn.assign(:current_user, user)
        |> AshAuthentication.Plug.Helpers.set_actor(user)

      _ ->
        # User is not authenticated, return 401
        conn
        |> Plug.Conn.put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Authentication required"})
        |> Plug.Conn.halt()
    end
  end

  # Authentication plug for admin routes (session based with role check)
  def require_admin_authentication(conn, _opts) do
    case AshAuthentication.Plug.Helpers.retrieve_from_session(conn, Sertantai.Accounts.User) do
      {:ok, user} when not is_nil(user) ->
        # Check if user has admin or support role
        case user.role do
          role when role in [:admin, :support] ->
            # User has admin access, continue
            conn
            |> Plug.Conn.assign(:current_user, user)
            |> AshAuthentication.Plug.Helpers.set_actor(user)

          _ ->
            # User doesn't have admin privileges
            conn
            |> Phoenix.Controller.put_flash(:error, "You don't have permission to access the admin area.")
            |> Phoenix.Controller.redirect(to: "/dashboard")
            |> Plug.Conn.halt()
        end

      _ ->
        # User is not authenticated, redirect to login
        conn
        |> Phoenix.Controller.put_flash(:error, "You must be logged in to access this page.")
        |> Phoenix.Controller.redirect(to: "/login")
        |> Plug.Conn.halt()
    end
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

    live_session :authenticated, 
      on_mount: AshAuthentication.Phoenix.LiveSession,
      session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []} do
      
      live "/dashboard", DashboardLive
      live "/profile", AuthLive, :profile
      live "/change-password", AuthLive, :change_password
      live "/sync-configs", SyncConfigLive.Index
      live "/sync-configs/new", SyncConfigLive.New
      live "/sync-configs/:id/edit", SyncConfigLive.Edit
      live "/records", RecordSelectionLive, :index
    
    # Phase 1 Organization Registration and Screening  
    live "/organizations", Organization.ProfileLive
    live "/organizations/register", Organization.RegistrationLive
    
    # Multi-location Management (Phase 2)
    live "/organizations/locations", Organization.LocationManagementLive
    live "/organizations/locations/new", Organization.LocationManagementLive, :new
    live "/organizations/locations/:id/edit", Organization.LocationManagementLive, :edit
    
    # Phase 2 Progressive Applicability Screening
    live "/applicability/progressive", Applicability.ProgressiveScreeningLive
    
    # Location-specific screening routes
    live "/applicability/location/:location_id", Applicability.LocationScreeningLive
    live "/applicability/location/:location_id/progressive", Applicability.LocationScreeningLive, :progressive
    
    # Organization-wide aggregate screening
    live "/applicability/organization/aggregate", Applicability.OrganizationAggregateScreeningLive
    
    # Smart routing based on single vs multi-location
    live "/applicability/smart", Applicability.SmartScreeningRouteLive
    end
  end

  # GraphQL API
  scope "/api" do
    pipe_through :graphql
    
    forward "/graphql", Absinthe.Plug, schema: Sertantai.Schema
    
    if Mix.env() == :dev do
      forward "/graphiql", Absinthe.Plug.GraphiQL, schema: Sertantai.Schema
    end
  end
  
  # Sync API endpoints for external tools
  scope "/api/sync", SertantaiWeb do
    pipe_through [:api, :require_authenticated_user]
    
    get "/selected_ids", SyncController, :selected_ids
    get "/selected_records", SyncController, :selected_records
    get "/export/:format", SyncController, :export
  end
  
  # JSON API endpoints will be defined by the resource directly

  # Ash Admin routes - DISABLED due to fundamental memory exhaustion issue
  # AshAdmin triggers OOM killer even with minimal data (5 users)
  # See: /docs/dev/admin_page_error.md for full investigation
  # scope "/admin" do
  #   pipe_through [:browser, :require_admin_authentication]
  #   ash_admin("/", domains: [Sertantai.Accounts])
  # end

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
