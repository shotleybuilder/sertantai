defmodule Sertantai.Sync.RateLimiter do
  @moduledoc """
  Rate limiter for external API calls and sync operations.
  Prevents abuse and ensures compliance with external API rate limits.
  """

  use GenServer
  require Logger

  @doc """
  Start the rate limiter.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if a request is allowed for the given key and limit.
  Returns {:ok, remaining} or {:error, :rate_limited}.
  """
  def check_rate_limit(key, limit, window_ms \\ 60_000) do
    GenServer.call(__MODULE__, {:check_rate_limit, key, limit, window_ms})
  end

  @doc """
  Check rate limit for external API calls.
  """
  def check_api_rate_limit(provider, user_id) do
    key = "api:#{provider}:#{user_id}"
    
    # Different limits for different providers
    case provider do
      :airtable -> check_rate_limit(key, 5, 60_000)  # 5 calls per minute
      :notion -> check_rate_limit(key, 3, 60_000)    # 3 calls per minute
      :zapier -> check_rate_limit(key, 10, 60_000)   # 10 calls per minute
      _ -> {:error, :unsupported_provider}
    end
  end

  @doc """
  Check rate limit for sync operations.
  """
  def check_sync_rate_limit(user_id) do
    key = "sync:#{user_id}"
    check_rate_limit(key, 10, 300_000)  # 10 sync operations per 5 minutes
  end

  @doc """
  Check rate limit for authentication attempts.
  """
  def check_auth_rate_limit(ip_address) do
    key = "auth:#{ip_address}"
    check_rate_limit(key, 5, 300_000)  # 5 auth attempts per 5 minutes
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    # Clean up old entries every 5 minutes
    :timer.send_interval(300_000, self(), :cleanup)
    {:ok, %{}}
  end

  @impl true
  def handle_call({:check_rate_limit, key, limit, window_ms}, _from, state) do
    now = System.system_time(:millisecond)
    
    # Get current requests for this key
    current_requests = Map.get(state, key, [])
    
    # Filter requests within the window
    recent_requests = Enum.filter(current_requests, fn timestamp ->
      now - timestamp < window_ms
    end)
    
    if length(recent_requests) >= limit do
      # Rate limit exceeded
      {:reply, {:error, :rate_limited}, state}
    else
      # Allow request and record it
      updated_requests = [now | recent_requests]
      updated_state = Map.put(state, key, updated_requests)
      remaining = limit - length(updated_requests)
      
      {:reply, {:ok, remaining}, updated_state}
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:millisecond)
    
    # Clean up entries older than 1 hour
    cleaned_state = Enum.reduce(state, %{}, fn {key, timestamps}, acc ->
      recent_timestamps = Enum.filter(timestamps, fn timestamp ->
        now - timestamp < 3_600_000  # 1 hour
      end)
      
      if length(recent_timestamps) > 0 do
        Map.put(acc, key, recent_timestamps)
      else
        acc
      end
    end)
    
    {:noreply, cleaned_state}
  end
end