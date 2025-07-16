defmodule Sertantai.AI.ConversationSession do
  @moduledoc """
  AshAI resource for managing AI conversation sessions with organizations.
  
  Handles session persistence, conversation history, and state management
  for AI-powered organization profiling conversations.
  """

  use Ash.Resource,
    domain: Sertantai.AI,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    
    attribute :organization_id, :uuid do
      description "ID of the organization being profiled"
      allow_nil? false
    end
    
    attribute :user_id, :uuid do
      description "ID of the user conducting the conversation"
    end
    
    attribute :session_status, :atom do
      description "Current status of the conversation session"
      constraints one_of: [:active, :paused, :completed, :abandoned, :interrupted, :resuming]
      default :active
    end
    
    attribute :conversation_history, {:array, :map} do
      description "Complete conversation history with timestamps"
      default []
    end
    
    attribute :discovered_attributes, :map do
      description "Organization attributes discovered during conversation"
      default %{}
    end
    
    attribute :current_context, :map do
      description "Current conversation context and state"
      default %{}
    end
    
    attribute :completion_percentage, :decimal do
      description "Estimated completion percentage (0.0 to 1.0)"
      constraints min: 0.0, max: 1.0
      default 0.0
    end
    
    attribute :session_metadata, :map do
      description "Session metadata including duration, question count, etc."
      default %{}
    end
    
    attribute :last_activity_at, :utc_datetime do
      description "Timestamp of last conversation activity"
      default &DateTime.utc_now/0
    end
    
    attribute :session_timeout_minutes, :integer do
      description "Session timeout in minutes"
      default 30
    end
    
    attribute :recovery_checkpoint, :map do
      description "Checkpoint data for session recovery"
      default %{}
    end
    
    attribute :interruption_reason, :string do
      description "Reason for session interruption if applicable"
    end
    
    timestamps()
  end

  relationships do
    belongs_to :organization, Sertantai.Organizations.Organization
    belongs_to :user, Sertantai.Accounts.User
    has_many :analyses, Sertantai.AI.OrganizationAnalysis
    has_many :question_sets, Sertantai.AI.QuestionGeneration
  end

  actions do
    defaults [:create, :read, :update, :destroy]

    read :by_organization do
      description "Find sessions by organization ID"
      
      argument :organization_id, :uuid do
        description "Organization ID to search for"
        allow_nil? false
      end
      
      filter expr(organization_id == ^arg(:organization_id))
    end

    read :active_sessions do
      description "Find all active sessions"
      filter expr(session_status == :active)
    end

    read :stale_sessions do
      description "Find sessions that may need timeout checking"
      
      argument :stale_threshold_minutes, :integer do
        description "Minutes threshold for considering a session stale"
        default 30
      end
      
      filter expr(
        session_status == :active and 
        last_activity_at < ago(^arg(:stale_threshold_minutes), :minute)
      )
    end
  end

  postgres do
    table "ai_conversation_sessions"
    repo Sertantai.Repo
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :by_organization, args: [:organization_id]
    define :active_sessions
    define :stale_sessions, args: [:stale_threshold_minutes]
  end

  # Helper functions for session management - moved to separate module
  def add_conversation_message(session, message) do
    current_history = session.conversation_history || []
    updated_message = Map.put(message, :timestamp, DateTime.utc_now())
    new_history = current_history ++ [updated_message]
    
    update(session, %{
      conversation_history: new_history,
      last_activity_at: DateTime.utc_now(),
      session_status: :active
    })
  end

  def pause_session(session, reason \\ "User requested pause") do
    current_context = session.current_context || %{}
    history = session.conversation_history || []
    
    checkpoint = %{
      paused_at: DateTime.utc_now(),
      conversation_state: current_context,
      message_count: length(history),
      last_message: List.last(history),
      reason: reason
    }
    
    update(session, %{
      session_status: :paused,
      recovery_checkpoint: checkpoint,
      last_activity_at: DateTime.utc_now()
    })
  end

  def resume_session(session) do
    checkpoint = session.recovery_checkpoint || %{}
    
    resume_message = if checkpoint != %{} do
      %{
        type: "ai",
        content: "Welcome back! Let's continue where we left off.",
        timestamp: DateTime.utc_now(),
        metadata: %{
          type: "session_resume",
          paused_duration: calculate_pause_duration(checkpoint["paused_at"])
        }
      }
    end
    
    current_history = session.conversation_history || []
    new_history = if resume_message, do: current_history ++ [resume_message], else: current_history
    
    update(session, %{
      session_status: :active,
      conversation_history: new_history,
      last_activity_at: DateTime.utc_now()
    })
  end

  def mark_interrupted(session, reason) do
    current_context = session.current_context || %{}
    history = session.conversation_history || []
    
    checkpoint = %{
      interrupted_at: DateTime.utc_now(),
      conversation_state: current_context,
      message_count: length(history),
      last_successful_exchange: find_last_successful_exchange(history),
      failure_point: %{
        reason: reason,
        timestamp: DateTime.utc_now()
      }
    }
    
    update(session, %{
      session_status: :interrupted,
      interruption_reason: reason,
      recovery_checkpoint: checkpoint,
      last_activity_at: DateTime.utc_now()
    })
  end

  def recover_session(session) do
    checkpoint = session.recovery_checkpoint || %{}
    reason = session.interruption_reason
    
    recovery_message = %{
      type: "ai",
      content: generate_recovery_message(reason, checkpoint),
      timestamp: DateTime.utc_now(),
      metadata: %{
        type: "session_recovery",
        recovery_from: reason,
        downtime_duration: calculate_downtime_duration(checkpoint["interrupted_at"])
      }
    }
    
    current_history = session.conversation_history || []
    new_history = current_history ++ [recovery_message]
    
    update(session, %{
      session_status: :active,
      conversation_history: new_history,
      interruption_reason: nil,
      last_activity_at: DateTime.utc_now()
    })
  end

  def check_timeout(session) do
    last_activity = session.last_activity_at
    timeout_minutes = session.session_timeout_minutes || 30
    current_status = session.session_status
    
    if current_status == :active && last_activity do
      timeout_threshold = DateTime.add(last_activity, timeout_minutes, :minute)
      
      if DateTime.compare(DateTime.utc_now(), timeout_threshold) == :gt do
        timeout_message = %{
          type: "system",
          content: "Session timed out due to inactivity",
          timestamp: DateTime.utc_now(),
          metadata: %{type: "timeout", timeout_minutes: timeout_minutes}
        }
        
        current_history = session.conversation_history || []
        new_history = current_history ++ [timeout_message]
        
        update(session, %{
          session_status: :abandoned,
          conversation_history: new_history,
          interruption_reason: "Session timeout"
        })
      else
        {:ok, session}
      end
    else
      {:ok, session}
    end
  end

  def update_session(session, updates) do
    final_updates = Map.put(updates, :last_activity_at, DateTime.utc_now())
    update(session, final_updates)
  end

  # Private helper functions

  defp calculate_pause_duration(paused_at_string) when is_binary(paused_at_string) do
    case DateTime.from_iso8601(paused_at_string) do
      {:ok, paused_time, _} -> calculate_pause_duration(paused_time)
      _ -> "unknown"
    end
  end

  defp calculate_pause_duration(paused_at) when not is_nil(paused_at) do
    duration_seconds = DateTime.diff(DateTime.utc_now(), paused_at)
    format_duration(duration_seconds)
  end

  defp calculate_pause_duration(_), do: "unknown"

  defp calculate_downtime_duration(interrupted_at_string) when is_binary(interrupted_at_string) do
    case DateTime.from_iso8601(interrupted_at_string) do
      {:ok, _interrupted_time, _} -> calculate_downtime_duration(interrupted_at_string)
      _ -> "unknown"
    end
  end

  defp calculate_downtime_duration(interrupted_at) when not is_nil(interrupted_at) do
    duration_seconds = DateTime.diff(DateTime.utc_now(), interrupted_at)
    format_duration(duration_seconds)
  end

  defp calculate_downtime_duration(_), do: "unknown"

  defp format_duration(seconds) when seconds < 60, do: "#{seconds} seconds"
  defp format_duration(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    "#{minutes} minutes"
  end
  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    "#{hours} hours, #{minutes} minutes"
  end

  defp find_last_successful_exchange(history) do
    history
    |> Enum.reverse()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find(fn [msg1, msg2] ->
      (msg1.type == "ai" && msg2.type == "user") || 
      (msg1.type == "user" && msg2.type == "ai")
    end)
    |> case do
      nil -> nil
      [msg1, msg2] -> %{ai_message: msg1, user_message: msg2}
    end
  end

  defp generate_recovery_message(reason, checkpoint) do
    base_message = "I apologize for the interruption. "
    
    specific_message = case reason do
      "network_error" ->
        "There was a network connectivity issue, but we're back online now."
      
      "service_timeout" ->
        "The AI service experienced a timeout, but it's responding normally now."
      
      "unexpected_error" ->
        "We encountered an unexpected error, but the system has recovered."
      
      _ ->
        "We experienced a technical issue, but everything is working again."
    end
    
    continuation_message = if checkpoint["last_successful_exchange"] do
      " Let's continue from where we left off."
    else
      " Let's start fresh with your organization profile."
    end
    
    base_message <> specific_message <> continuation_message
  end
end