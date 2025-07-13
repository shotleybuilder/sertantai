defmodule Sertantai.AI.Supervisor do
  @moduledoc """
  Supervisor for AI services including health monitoring, session management,
  and recovery systems.
  """

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Health monitoring service
      {Sertantai.AI.HealthMonitor, []},
      
      # Session management and cleanup service
      {Sertantai.AI.SessionManager, []},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def start_recovery_process do
    # Start automated recovery for interrupted sessions on application startup
    Task.start(fn ->
      Logger.info("Starting AI session recovery process...")
      
      try do
        # Wait a bit for services to be ready
        Process.sleep(5000)
        
        # Attempt to recover interrupted sessions
        case recover_interrupted_sessions() do
          {:ok, recovered_count} ->
            Logger.info("Successfully recovered #{recovered_count} AI sessions")
          
          {:error, reason} ->
            Logger.error("Failed to recover AI sessions: #{inspect(reason)}")
        end
        
        # Register core AI services for health monitoring
        register_core_services()
        
      rescue
        exception ->
          Logger.error("Exception during AI session recovery: #{inspect(exception)}")
      end
    end)
  end

  defp recover_interrupted_sessions do
    alias Sertantai.AI.{ConversationSession, ErrorHandler}
    
    try do
      # Find all interrupted sessions
      case ConversationSession.read() do
        {:ok, all_sessions} ->
          interrupted_sessions = Enum.filter(all_sessions, fn session ->
            session.session_status == :interrupted
          end)
          
          recovery_count = Enum.reduce(interrupted_sessions, 0, fn session, acc ->
            case ErrorHandler.attempt_session_recovery(session.id) do
              {:ok, _recovered_session} ->
                Logger.info("Recovered interrupted session #{session.id}")
                acc + 1
              
              {:error, reason} ->
                Logger.debug("Could not recover session #{session.id}: #{inspect(reason)}")
                acc
            end
          end)
          
          {:ok, recovery_count}
        
        {:error, reason} ->
          {:error, reason}
      end
    rescue
      exception ->
        {:error, exception}
    end
  end

  defp register_core_services do
    alias Sertantai.AI.HealthMonitor
    
    # Register database service
    HealthMonitor.register_database_service()
    
    # Register conversation session service
    HealthMonitor.register_conversation_session_service()
    
    # Register OpenAI service if API key is available
    if openai_api_key = System.get_env("OPENAI_API_KEY") do
      HealthMonitor.register_openai_service(openai_api_key)
    else
      Logger.warning("OpenAI API key not found - AI service health monitoring disabled")
    end
    
    Logger.info("AI service health monitoring registered")
  end
end