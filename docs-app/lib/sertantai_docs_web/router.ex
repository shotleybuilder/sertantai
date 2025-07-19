defmodule SertantaiDocsWeb.Router do
  use SertantaiDocsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SertantaiDocsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Enable development routes and tools
  # These must come BEFORE catch-all routes to avoid being captured
  if Application.compile_env(:sertantai_docs, :dev_routes) || Mix.env() == :test do
    import Phoenix.LiveDashboard.Router
    
    scope "/dev" do
      pipe_through :browser

      # Swoosh mailbox preview
      forward "/mailbox", Plug.Swoosh.MailboxPreview
      
      # LiveDashboard for debugging
      live_dashboard "/dashboard", metrics: SertantaiDocsWeb.Telemetry
    end
    
    # Development API routes for integration testing
    scope "/dev-api", SertantaiDocsWeb do
      pipe_through :api
      
      # Integration status endpoint
      get "/integration/status", DevController, :integration_status
      post "/integration/sync", DevController, :trigger_sync
      get "/navigation", DevController, :navigation
      get "/content/*path", DevController, :content_info
    end
  end

  scope "/", SertantaiDocsWeb do
    pipe_through :browser

    # Documentation routes
    get "/", DocController, :index
    get "/:category/:page", DocController, :show
    get "/:category", DocController, :category_index
  end

  # Other scopes may use custom stacks.
  # scope "/api", SertantaiDocsWeb do
  #   pipe_through :api
  # end
end
