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
      constraints one_of: [:active, :paused, :completed, :abandoned]
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
  end
end