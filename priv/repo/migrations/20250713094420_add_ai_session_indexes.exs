defmodule Sertantai.Repo.Migrations.AddAiSessionIndexes do
  use Ecto.Migration

  def change do
    # Indexes for AI conversation sessions performance optimization
    
    # Primary lookup indexes
    create index(:ai_conversation_sessions, [:organization_id])
    create index(:ai_conversation_sessions, [:user_id])
    create index(:ai_conversation_sessions, [:session_status])
    
    # Session management indexes
    create index(:ai_conversation_sessions, [:last_activity_at])
    create index(:ai_conversation_sessions, [:session_status, :last_activity_at])
    
    # Cleanup and timeout checking indexes
    create index(:ai_conversation_sessions, [:session_status, :updated_at])
    create index(:ai_conversation_sessions, [:session_status, :last_activity_at, :session_timeout_minutes])
    
    # Composite indexes for common queries
    create index(:ai_conversation_sessions, [:organization_id, :session_status])
    create index(:ai_conversation_sessions, [:user_id, :session_status])
    create index(:ai_conversation_sessions, [:organization_id, :user_id, :session_status])
    
    # Indexes for other AI tables
    
    # Organization analysis indexes
    create index(:ai_organization_analyses, [:organization_id])
    create index(:ai_organization_analyses, [:analysis_type])
    create index(:ai_organization_analyses, [:organization_id, :analysis_type])
    create index(:ai_organization_analyses, [:inserted_at])
    
    # Question generation indexes  
    create index(:ai_question_generations, [:organization_id])
    create index(:ai_question_generations, [:conversation_session_id])
    create index(:ai_question_generations, [:question_type])
    create index(:ai_question_generations, [:priority_score])
    create index(:ai_question_generations, [:organization_id, :question_type])
    
    # Response processing indexes
    create index(:ai_response_processings, [:session_id])
    create index(:ai_response_processings, [:validation_status])
    create index(:ai_response_processings, [:session_id, :inserted_at])
    create index(:ai_response_processings, [:inserted_at])
    
    # Partial indexes for specific scenarios
    
    # Active sessions index (most commonly queried)
    create index(:ai_conversation_sessions, [:organization_id], 
      where: "session_status = 'active'", 
      name: :ai_sessions_active_by_org)
    
    # Stale sessions index for cleanup
    create index(:ai_conversation_sessions, [:last_activity_at], 
      where: "session_status = 'active'", 
      name: :ai_sessions_stale_active)
    
    # Interrupted sessions index for recovery
    create index(:ai_conversation_sessions, [:updated_at], 
      where: "session_status = 'interrupted'", 
      name: :ai_sessions_interrupted_recovery)
    
    # Abandoned sessions index for cleanup
    create index(:ai_conversation_sessions, [:updated_at], 
      where: "session_status = 'abandoned'", 
      name: :ai_sessions_abandoned_cleanup)
      
    # High priority questions index
    create index(:ai_question_generations, [:organization_id, :inserted_at], 
      where: "priority_score > 0.8", 
      name: :ai_questions_high_priority)
  end
end
