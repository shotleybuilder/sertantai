defmodule Sertantai.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SertantaiWeb.Telemetry,
      Sertantai.Repo,
      {DNSCluster, query: Application.get_env(:sertantai, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Sertantai.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Sertantai.Finch},
      # Start the sync worker for background operations
      Sertantai.Sync.SyncWorker,
      # Start the rate limiter for API and sync throttling
      Sertantai.Sync.RateLimiter,
      # Start user selections manager for session persistence
      Sertantai.UserSelections,
      # Start Phase 2 applicability cache for high-performance screening
      {Cachex, name: :applicability_cache, limit: 10_000},
      # Start AI services supervisor for Phase 3 functionality
      Sertantai.AI.Supervisor,
      # Start to serve requests, typically the last entry
      SertantaiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Sertantai.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Start AI session recovery process after supervisor is ready
        # Skip in test environment to avoid database ownership issues
        unless Mix.env() == :test do
          Sertantai.AI.Supervisor.start_recovery_process()
        end
        {:ok, pid}
      
      error ->
        error
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SertantaiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
