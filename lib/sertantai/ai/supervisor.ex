defmodule Sertantai.AI.Supervisor do
  @moduledoc """
  Supervisor for AI services including health monitoring, session management,
  and recovery systems.
  """

  use Supervisor
  require Logger
  require Ash.Query

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
      query = ConversationSession
        |> Ash.Query.filter(session_status == :interrupted)
      
      case Ash.read(query) do
        {:ok, interrupted_sessions} ->
          
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
        
        {:error, %Ash.Error.Unknown{errors: errors}} = error ->
          # Check if it's a table not found error
          if Enum.any?(errors, fn 
            %{error: error_string} when is_binary(error_string) -> 
              error_string =~ "undefined_table" or error_string =~ "does not exist"
            _ -> 
              false
          end) do
            Logger.debug("AI conversation sessions table not yet created - skipping recovery")
            {:ok, 0}
          else
            {:error, error}
          end
          
        {:error, reason} ->
          {:error, reason}
      end
    rescue
      exception ->
        # Handle Postgrex errors for missing tables
        case exception do
          %Postgrex.Error{postgres: %{code: :undefined_table}} ->
            Logger.debug("AI conversation sessions table not yet created - skipping recovery")
            {:ok, 0}
            
          _ ->
            {:error, exception}
        end
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