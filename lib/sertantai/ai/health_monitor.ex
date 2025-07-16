defmodule Sertantai.AI.HealthMonitor do
  @moduledoc """
  Health monitoring system for AI services and conversation sessions.
  
  Provides real-time monitoring, alerting, and automatic recovery
  for AI service health and session reliability.
  """

  use GenServer
  require Logger

  alias Sertantai.AI.ConversationSession

  @default_check_interval 30_000  # 30 seconds
  @default_session_timeout 30     # 30 minutes
  @service_health_table :ai_service_health

  defstruct [
    :check_interval,
    :session_timeout_minutes,
    :last_health_check,
    :service_statuses,
    :monitored_services,
    :alert_subscribers
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_service_status(service_name) do
    GenServer.call(__MODULE__, {:get_service_status, service_name})
  end

  def get_all_service_statuses do
    GenServer.call(__MODULE__, :get_all_service_statuses)
  end

  def register_service(service_name, health_check_fn, opts \\ []) do
    GenServer.call(__MODULE__, {:register_service, service_name, health_check_fn, opts})
  end

  def unregister_service(service_name) do
    GenServer.call(__MODULE__, {:unregister_service, service_name})
  end

  def subscribe_to_alerts(subscriber_pid) do
    GenServer.call(__MODULE__, {:subscribe_alerts, subscriber_pid})
  end

  def force_health_check do
    GenServer.call(__MODULE__, :force_health_check)
  end

  def get_health_summary do
    GenServer.call(__MODULE__, :get_health_summary)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    # Create ETS table for service health data
    :ets.new(@service_health_table, [:named_table, :public, :set])
    
    state = %__MODULE__{
      check_interval: Keyword.get(opts, :check_interval, @default_check_interval),
      session_timeout_minutes: Keyword.get(opts, :session_timeout_minutes, @default_session_timeout),
      last_health_check: DateTime.utc_now(),
      service_statuses: %{},
      monitored_services: %{},
      alert_subscribers: []
    }
    
    # Schedule initial health check
    schedule_health_check(state.check_interval)
    
    # Schedule session cleanup
    schedule_session_cleanup(60_000)  # Check sessions every minute
    
    Logger.info("AI Health Monitor started with check interval: #{state.check_interval}ms")
    
    {:ok, state}
  end

  @impl true
  def handle_call({:get_service_status, service_name}, _from, state) do
    status = Map.get(state.service_statuses, service_name, :unknown)
    {:reply, status, state}
  end

  @impl true
  def handle_call(:get_all_service_statuses, _from, state) do
    {:reply, state.service_statuses, state}
  end

  @impl true
  def handle_call({:register_service, service_name, health_check_fn, opts}, _from, state) do
    service_config = %{
      health_check_fn: health_check_fn,
      enabled: Keyword.get(opts, :enabled, true),
      timeout: Keyword.get(opts, :timeout, 5000),
      critical: Keyword.get(opts, :critical, false),
      last_check: nil,
      consecutive_failures: 0
    }
    
    new_services = Map.put(state.monitored_services, service_name, service_config)
    new_statuses = Map.put(state.service_statuses, service_name, :unknown)
    
    Logger.info("Registered AI service for monitoring: #{service_name}")
    
    {:reply, :ok, %{state | monitored_services: new_services, service_statuses: new_statuses}}
  end

  @impl true
  def handle_call({:unregister_service, service_name}, _from, state) do
    new_services = Map.delete(state.monitored_services, service_name)
    new_statuses = Map.delete(state.service_statuses, service_name)
    
    Logger.info("Unregistered AI service from monitoring: #{service_name}")
    
    {:reply, :ok, %{state | monitored_services: new_services, service_statuses: new_statuses}}
  end

  @impl true
  def handle_call({:subscribe_alerts, subscriber_pid}, _from, state) do
    new_subscribers = [subscriber_pid | state.alert_subscribers]
    {:reply, :ok, %{state | alert_subscribers: new_subscribers}}
  end

  @impl true
  def handle_call(:force_health_check, _from, state) do
    {results, new_state} = perform_health_checks(state)
    {:reply, results, new_state}
  end

  @impl true
  def handle_call(:get_health_summary, _from, state) do
    summary = generate_health_summary(state)
    {:reply, summary, state}
  end

  @impl true
  def handle_info(:perform_health_check, state) do
    {_results, new_state} = perform_health_checks(state)
    
    # Schedule next health check
    schedule_health_check(state.check_interval)
    
    {:noreply, %{new_state | last_health_check: DateTime.utc_now()}}
  end

  @impl true
  def handle_info(:cleanup_sessions, state) do
    cleanup_stale_sessions(state.session_timeout_minutes)
    
    # Schedule next cleanup
    schedule_session_cleanup(60_000)
    
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove crashed subscriber
    new_subscribers = List.delete(state.alert_subscribers, pid)
    {:noreply, %{state | alert_subscribers: new_subscribers}}
  end

  ## Private Functions

  defp schedule_health_check(interval) do
    Process.send_after(self(), :perform_health_check, interval)
  end

  defp schedule_session_cleanup(interval) do
    Process.send_after(self(), :cleanup_sessions, interval)
  end

  defp perform_health_checks(state) do
    results = %{}
    new_statuses = %{}
    new_services = %{}
    
    {results, new_statuses, new_services} = 
      Enum.reduce(state.monitored_services, {results, new_statuses, new_services}, 
        fn {service_name, config}, {acc_results, acc_statuses, acc_services} ->
          if config.enabled do
            {result, new_config} = check_service_health(service_name, config)
            
            {
              Map.put(acc_results, service_name, result),
              Map.put(acc_statuses, service_name, result.status),
              Map.put(acc_services, service_name, new_config)
            }
          else
            {
              Map.put(acc_results, service_name, %{status: :disabled}),
              Map.put(acc_statuses, service_name, :disabled),
              Map.put(acc_services, service_name, config)
            }
          end
        end)
    
    # Check for critical service failures and send alerts
    critical_failures = find_critical_failures(results, state.monitored_services)
    if length(critical_failures) > 0 do
      send_health_alerts(critical_failures, state.alert_subscribers)
    end
    
    # Update ETS table with latest health data
    update_health_ets(results)
    
    new_state = %{state | 
      service_statuses: new_statuses,
      monitored_services: new_services
    }
    
    {results, new_state}
  end

  defp check_service_health(service_name, config) do
    start_time = System.monotonic_time(:millisecond)
    
    result = try do
      # Run health check with timeout
      task = Task.async(fn -> config.health_check_fn.() end)
      
      case Task.await(task, config.timeout) do
        :ok ->
          %{
            status: :healthy,
            response_time: System.monotonic_time(:millisecond) - start_time,
            checked_at: DateTime.utc_now(),
            error: nil
          }
        
        {:ok, details} ->
          %{
            status: :healthy,
            response_time: System.monotonic_time(:millisecond) - start_time,
            checked_at: DateTime.utc_now(),
            details: details,
            error: nil
          }
        
        {:error, reason} ->
          %{
            status: :unhealthy,
            response_time: System.monotonic_time(:millisecond) - start_time,
            checked_at: DateTime.utc_now(),
            error: reason
          }
        
        other ->
          %{
            status: :unknown,
            response_time: System.monotonic_time(:millisecond) - start_time,
            checked_at: DateTime.utc_now(),
            error: "Unexpected health check response: #{inspect(other)}"
          }
      end
    rescue
      exception ->
        %{
          status: :error,
          response_time: System.monotonic_time(:millisecond) - start_time,
          checked_at: DateTime.utc_now(),
          error: "Health check exception: #{inspect(exception)}"
        }
    catch
      :exit, {:timeout, _} ->
        %{
          status: :timeout,
          response_time: config.timeout,
          checked_at: DateTime.utc_now(),
          error: "Health check timed out after #{config.timeout}ms"
        }
    end
    
    # Update service config with check results
    consecutive_failures = if result.status in [:healthy] do
      0
    else
      config.consecutive_failures + 1
    end
    
    new_config = %{config | 
      last_check: result.checked_at,
      consecutive_failures: consecutive_failures
    }
    
    Logger.debug("Health check for #{service_name}: #{result.status} (#{result.response_time}ms)")
    
    {result, new_config}
  end

  defp find_critical_failures(results, monitored_services) do
    Enum.filter(results, fn {service_name, result} ->
      service_config = Map.get(monitored_services, service_name)
      service_config && service_config.critical && result.status not in [:healthy, :disabled]
    end)
  end

  defp send_health_alerts(critical_failures, subscribers) do
    alert_message = %{
      type: :critical_service_failure,
      timestamp: DateTime.utc_now(),
      failures: critical_failures,
      severity: :critical
    }
    
    Enum.each(subscribers, fn subscriber_pid ->
      send(subscriber_pid, {:health_alert, alert_message})
    end)
    
    Logger.error("Critical AI service failures detected: #{inspect(Enum.map(critical_failures, &elem(&1, 0)))}")
  end

  defp update_health_ets(results) do
    Enum.each(results, fn {service_name, result} ->
      :ets.insert(@service_health_table, {service_name, result})
    end)
  end

  defp cleanup_stale_sessions(timeout_minutes) do
    try do
      case ConversationSession.stale_sessions(timeout_minutes) do
        {:ok, stale_sessions} ->
          stale_count = length(stale_sessions)
          
          if stale_count > 0 do
            Logger.info("Found #{stale_count} stale AI conversation sessions")
            
            Enum.each(stale_sessions, fn session ->
              case ConversationSession.check_timeout(session) do
                {:ok, updated_session} ->
                  if updated_session.session_status == :abandoned do
                    Logger.info("Session #{session.id} marked as abandoned due to timeout")
                  end
                
                {:error, reason} ->
                  Logger.error("Failed to check timeout for session #{session.id}: #{inspect(reason)}")
              end
            end)
          end
        
        {:error, reason} ->
          Logger.error("Failed to fetch stale sessions: #{inspect(reason)}")
      end
    rescue
      exception ->
        Logger.error("Exception during session cleanup: #{inspect(exception)}")
    end
  end

  defp generate_health_summary(state) do
    total_services = map_size(state.monitored_services)
    
    status_counts = Enum.reduce(state.service_statuses, %{}, fn {_name, status}, acc ->
      Map.update(acc, status, 1, &(&1 + 1))
    end)
    
    healthy_count = Map.get(status_counts, :healthy, 0)
    unhealthy_count = total_services - healthy_count
    
    overall_status = cond do
      total_services == 0 -> :no_services
      healthy_count == total_services -> :all_healthy
      healthy_count > unhealthy_count -> :mostly_healthy
      healthy_count > 0 -> :partially_healthy
      true -> :all_unhealthy
    end
    
    %{
      overall_status: overall_status,
      total_services: total_services,
      healthy_services: healthy_count,
      unhealthy_services: unhealthy_count,
      status_breakdown: status_counts,
      last_check: state.last_health_check,
      check_interval_ms: state.check_interval
    }
  end

  ## Public utility functions for service registration

  def register_openai_service(api_key) when is_binary(api_key) do
    health_check_fn = fn ->
      # Simple OpenAI API health check
      case make_openai_health_request(api_key) do
        {:ok, _response} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
    
    register_service(:openai, health_check_fn, [critical: true, timeout: 10_000])
  end

  def register_conversation_session_service do
    health_check_fn = fn ->
      # Check if we can query conversation sessions
      case ConversationSession.active_sessions() do
        {:ok, _sessions} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
    
    register_service(:conversation_sessions, health_check_fn, [critical: true, timeout: 5_000])
  end

  def register_database_service do
    health_check_fn = fn ->
      # Simple database connectivity check
      case Sertantai.Repo.query("SELECT 1") do
        {:ok, _result} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
    
    register_service(:database, health_check_fn, [critical: true, timeout: 5_000])
  end

  defp make_openai_health_request(api_key) do
    # Minimal OpenAI API request to check service health
    # In a real implementation, you'd use the actual OpenAI client
    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]
    
    # Simple model list request as health check
    url = "https://api.openai.com/v1/models"
    
    case HTTPoison.get(url, headers, timeout: 5000) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        {:ok, "OpenAI API accessible"}
      
      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "OpenAI API returned status #{status_code}"}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "OpenAI API request failed: #{reason}"}
    end
  end
end