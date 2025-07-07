defmodule SertantaiWeb.Router do
  use SertantaiWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SertantaiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end
  
  pipeline :graphql do
    plug :accepts, ["json"]
  end

  scope "/", SertantaiWeb do
    pipe_through :browser

    get "/", PageController, :home
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
