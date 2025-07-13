defmodule Sertantai.AI.SessionManager do
  @moduledoc """
  Background session management system for AI conversations.
  
  Handles conversation timeouts, cleanup, and session lifecycle management
  with automatic recovery and maintenance operations.
  """

  use GenServer
  require Logger

  alias Sertantai.AI.{ConversationSession, HealthMonitor, ErrorHandler}

  @default_cleanup_interval 60_000      # 1 minute
  @default_session_timeout 30           # 30 minutes  
  @default_abandoned_cleanup_hours 24   # 24 hours
  @default_max_history_size 100         # messages

  defstruct [
    :cleanup_interval,
    :session_timeout_minutes,
    :abandoned_cleanup_hours,
    :max_history_size,
    :last_cleanup,
    :cleanup_stats
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def force_cleanup do
    GenServer.call(__MODULE__, :force_cleanup)
  end

  def get_cleanup_stats do
    GenServer.call(__MODULE__, :get_cleanup_stats)
  end

  def update_config(new_config) do
    GenServer.call(__MODULE__, {:update_config, new_config})
  end

  def pause_cleanup do
    GenServer.call(__MODULE__, :pause_cleanup)
  end

  def resume_cleanup do
    GenServer.call(__MODULE__, :resume_cleanup)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      cleanup_interval: Keyword.get(opts, :cleanup_interval, @default_cleanup_interval),
      session_timeout_minutes: Keyword.get(opts, :session_timeout_minutes, @default_session_timeout),
      abandoned_cleanup_hours: Keyword.get(opts, :abandoned_cleanup_hours, @default_abandoned_cleanup_hours),
      max_history_size: Keyword.get(opts, :max_history_size, @default_max_history_size),
      last_cleanup: DateTime.utc_now(),
      cleanup_stats: initialize_cleanup_stats()
    }
    
    # Schedule initial cleanup
    schedule_cleanup(state.cleanup_interval)
    
    Logger.info("AI Session Manager started - cleanup interval: #{state.cleanup_interval}ms, session timeout: #{state.session_timeout_minutes}min")
    
    {:ok, state}
  end

  @impl true
  def handle_call(:force_cleanup, _from, state) do
    {results, new_state} = perform_cleanup_cycle(state)
    {:reply, results, new_state}
  end

  @impl true
  def handle_call(:get_cleanup_stats, _from, state) do
    {:reply, state.cleanup_stats, state}
  end

  @impl true
  def handle_call({:update_config, new_config}, _from, state) do
    updated_state = %{state |
      cleanup_interval: Map.get(new_config, :cleanup_interval, state.cleanup_interval),
      session_timeout_minutes: Map.get(new_config, :session_timeout_minutes, state.session_timeout_minutes),
      abandoned_cleanup_hours: Map.get(new_config, :abandoned_cleanup_hours, state.abandoned_cleanup_hours),
      max_history_size: Map.get(new_config, :max_history_size, state.max_history_size)
    }
    
    Logger.info("Session Manager config updated")
    {:reply, :ok, updated_state}
  end

  @impl true
  def handle_call(:pause_cleanup, _from, state) do
    Logger.info("Session Manager cleanup paused")
    {:reply, :ok, Map.put(state, :cleanup_paused, true)}
  end

  @impl true
  def handle_call(:resume_cleanup, _from, state) do
    Logger.info("Session Manager cleanup resumed")
    schedule_cleanup(state.cleanup_interval)
    {:reply, :ok, Map.delete(state, :cleanup_paused)}
  end

  @impl true
  def handle_info(:perform_cleanup, state) do
    if Map.get(state, :cleanup_paused, false) do
      # Skip cleanup if paused, but schedule next one
      schedule_cleanup(state.cleanup_interval)
      {:noreply, state}
    else
      {_results, new_state} = perform_cleanup_cycle(state)
      
      # Schedule next cleanup
      schedule_cleanup(state.cleanup_interval)
      
      {:noreply, %{new_state | last_cleanup: DateTime.utc_now()}}
    end
  end

  ## Private Functions

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :perform_cleanup, interval)
  end

  defp perform_cleanup_cycle(state) do
    start_time = System.monotonic_time(:millisecond)
    
    Logger.debug("Starting AI session cleanup cycle")
    
    results = %{
      timeout_checks: 0,
      timeouts_processed: 0,
      abandoned_cleaned: 0,
      history_trimmed: 0,
      interruption_recoveries: 0,
      errors: []
    }
    
    # Step 1: Check for timed out sessions
    {timeout_results, step1_results} = check_session_timeouts(state, results)
    
    # Step 2: Clean up old abandoned sessions
    {abandoned_results, step2_results} = cleanup_abandoned_sessions(state, step1_results)
    
    # Step 3: Trim oversized conversation histories
    {history_results, step3_results} = trim_conversation_histories(state, step2_results)
    
    # Step 4: Attempt recovery of interrupted sessions
    {recovery_results, final_results} = attempt_session_recoveries(state, step3_results)
    
    # Update cleanup statistics
    cleanup_duration = System.monotonic_time(:millisecond) - start_time
    new_stats = update_cleanup_stats(state.cleanup_stats, final_results, cleanup_duration)
    
    Logger.info("Session cleanup completed in #{cleanup_duration}ms - timeouts: #{final_results.timeouts_processed}, abandoned: #{final_results.abandoned_cleaned}, recoveries: #{final_results.interruption_recoveries}")
    
    new_state = %{state | cleanup_stats: new_stats}
    
    {final_results, new_state}
  end

  defp check_session_timeouts(state, results) do
    try do
      case ConversationSession.stale_sessions(state.session_timeout_minutes) do
        {:ok, stale_sessions} ->
          stale_count = length(stale_sessions)
          
          timeout_results = Enum.reduce(stale_sessions, 0, fn session, acc ->
            case ConversationSession.check_timeout(session) do
              {:ok, updated_session} ->
                if updated_session.session_status == :abandoned do
                  acc + 1
                else
                  acc
                end
              
              {:error, reason} ->
                Logger.error("Failed to check timeout for session #{session.id}: #{inspect(reason)}")
                acc
            end
          end)
          
          new_results = %{results | 
            timeout_checks: stale_count,
            timeouts_processed: timeout_results
          }
          
          {:ok, new_results}
        
        {:error, reason} ->
          error_msg = "Failed to fetch stale sessions: #{inspect(reason)}"
          Logger.error(error_msg)
          
          new_results = %{results | errors: [error_msg | results.errors]}
          {:error, new_results}
      end
    rescue
      exception ->
        error_msg = "Exception during timeout checks: #{inspect(exception)}"
        Logger.error(error_msg)
        
        new_results = %{results | errors: [error_msg | results.errors]}
        {:error, new_results}
    end
  end

  defp cleanup_abandoned_sessions(state, results) do
    try do
      abandoned_cutoff = DateTime.add(DateTime.utc_now(), -state.abandoned_cleanup_hours, :hour)
      
      # Find sessions abandoned before cutoff
      case ConversationSession.read() do
        {:ok, all_sessions} ->
          old_abandoned = Enum.filter(all_sessions, fn session ->
            session.session_status == :abandoned && 
            DateTime.compare(session.updated_at, abandoned_cutoff) == :lt
          end)
          
          cleanup_count = Enum.reduce(old_abandoned, 0, fn session, acc ->
            case ConversationSession.destroy(session) do
              :ok ->
                Logger.debug("Cleaned up abandoned session #{session.id}")
                acc + 1
              
              {:error, reason} ->
                Logger.error("Failed to cleanup session #{session.id}: #{inspect(reason)}")
                acc
            end
          end)
          
          new_results = %{results | abandoned_cleaned: cleanup_count}
          {:ok, new_results}
        
        {:error, reason} ->
          error_msg = "Failed to fetch sessions for abandoned cleanup: #{inspect(reason)}"
          Logger.error(error_msg)
          
          new_results = %{results | errors: [error_msg | results.errors]}
          {:error, new_results}
      end
    rescue
      exception ->
        error_msg = "Exception during abandoned session cleanup: #{inspect(exception)}"
        Logger.error(error_msg)
        
        new_results = %{results | errors: [error_msg | results.errors]}
        {:error, new_results}
    end
  end

  defp trim_conversation_histories(state, results) do
    try do
      case ConversationSession.read() do
        {:ok, all_sessions} ->
          oversized_sessions = Enum.filter(all_sessions, fn session ->
            history_size = length(session.conversation_history || [])
            history_size > state.max_history_size
          end)
          
          trim_count = Enum.reduce(oversized_sessions, 0, fn session, acc ->
            trimmed_history = trim_history(session.conversation_history, state.max_history_size)
            
            case ConversationSession.update_session(session, %{conversation_history: trimmed_history}) do
              {:ok, _updated_session} ->
                Logger.debug("Trimmed conversation history for session #{session.id}")
                acc + 1
              
              {:error, reason} ->
                Logger.error("Failed to trim history for session #{session.id}: #{inspect(reason)}")
                acc
            end
          end)
          
          new_results = %{results | history_trimmed: trim_count}
          {:ok, new_results}
        
        {:error, reason} ->
          error_msg = "Failed to fetch sessions for history trimming: #{inspect(reason)}"
          Logger.error(error_msg)
          
          new_results = %{results | errors: [error_msg | results.errors]}
          {:error, new_results}
      end
    rescue
      exception ->
        error_msg = "Exception during history trimming: #{inspect(exception)}"
        Logger.error(error_msg)
        
        new_results = %{results | errors: [error_msg | results.errors]}
        {:error, new_results}
    end
  end

  defp attempt_session_recoveries(state, results) do
    try do
      # Find interrupted sessions that might be recoverable
      case ConversationSession.read() do
        {:ok, all_sessions} ->
          interrupted_sessions = Enum.filter(all_sessions, fn session ->
            session.session_status == :interrupted &&
            is_recovery_viable?(session)
          end)
          
          recovery_count = Enum.reduce(interrupted_sessions, 0, fn session, acc ->
            case ErrorHandler.attempt_session_recovery(session.id) do
              {:ok, _recovered_session} ->
                Logger.info("Successfully recovered interrupted session #{session.id}")
                acc + 1
              
              {:error, reason} ->
                Logger.debug("Could not recover session #{session.id}: #{inspect(reason)}")
                acc
            end
          end)
          
          new_results = %{results | interruption_recoveries: recovery_count}
          {:ok, new_results}
        
        {:error, reason} ->
          error_msg = "Failed to fetch sessions for recovery attempts: #{inspect(reason)}"
          Logger.error(error_msg)
          
          new_results = %{results | errors: [error_msg | results.errors]}
          {:error, new_results}
      end
    rescue
      exception ->
        error_msg = "Exception during session recovery: #{inspect(exception)}"
        Logger.error(error_msg)
        
        new_results = %{results | errors: [error_msg | results.errors]}
        {:error, new_results}
    end
  end

  defp trim_history(history, max_size) when length(history) <= max_size, do: history
  defp trim_history(history, max_size) do
    # Keep the most recent messages, but try to preserve conversation flow
    total_messages = length(history)
    keep_count = max_size
    skip_count = total_messages - keep_count
    
    # Add a trim marker message
    trim_marker = %{
      type: "system",
      content: "...(#{skip_count} earlier messages trimmed for performance)...",
      timestamp: DateTime.utc_now(),
      metadata: %{type: "history_trim", trimmed_count: skip_count}
    }
    
    recent_messages = Enum.take(history, -keep_count + 1)  # Leave room for trim marker
    [trim_marker | recent_messages]
  end

  defp is_recovery_viable?(session) do
    # Check if session was interrupted recently enough to attempt recovery
    case session.recovery_checkpoint do
      %{"interrupted_at" => interrupted_at_string} ->
        case DateTime.from_iso8601(interrupted_at_string) do
          {:ok, interrupted_at, _} ->
            hours_since_interruption = DateTime.diff(DateTime.utc_now(), interrupted_at, :hour)
            hours_since_interruption <= 2  # Only attempt recovery within 2 hours
          
          _ ->
            false
        end
      
      _ ->
        false
    end
  end

  defp initialize_cleanup_stats do
    %{
      total_cycles: 0,
      total_duration_ms: 0,
      average_duration_ms: 0,
      total_timeouts_processed: 0,
      total_abandoned_cleaned: 0,
      total_histories_trimmed: 0,
      total_recoveries: 0,
      last_cycle_duration_ms: 0,
      last_cycle_errors: []
    }
  end

  defp update_cleanup_stats(current_stats, cycle_results, cycle_duration) do
    new_total_cycles = current_stats.total_cycles + 1
    new_total_duration = current_stats.total_duration_ms + cycle_duration
    new_average_duration = div(new_total_duration, new_total_cycles)
    
    %{current_stats |
      total_cycles: new_total_cycles,
      total_duration_ms: new_total_duration,
      average_duration_ms: new_average_duration,
      total_timeouts_processed: current_stats.total_timeouts_processed + cycle_results.timeouts_processed,
      total_abandoned_cleaned: current_stats.total_abandoned_cleaned + cycle_results.abandoned_cleaned,
      total_histories_trimmed: current_stats.total_histories_trimmed + cycle_results.history_trimmed,
      total_recoveries: current_stats.total_recoveries + cycle_results.interruption_recoveries,
      last_cycle_duration_ms: cycle_duration,
      last_cycle_errors: cycle_results.errors
    }
  end
end