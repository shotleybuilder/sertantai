defmodule SertantaiDocs.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SertantaiDocsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:sertantai_docs, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SertantaiDocs.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: SertantaiDocs.Finch},
      # Start content integration and file monitoring
      {SertantaiDocs.Integration, []},
      # Start a worker by calling: SertantaiDocs.Worker.start_link(arg)
      # {SertantaiDocs.Worker, arg},
      # Start to serve requests, typically the last entry
      SertantaiDocsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SertantaiDocs.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SertantaiDocsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
