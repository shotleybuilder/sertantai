defmodule Sertantai.AI.QuestionGeneration do
  @moduledoc """
  AshAI resource for generating intelligent, context-aware questions
  to gather missing organization information.
  """

  use Ash.Resource,
    domain: Sertantai.AI,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    
    attribute :organization_id, :uuid do
      description "ID of the organization for question generation"
      allow_nil? false
    end
    
    attribute :conversation_session_id, :uuid do
      description "ID of the conversation session"
      allow_nil? true
    end
    
    attribute :question_type, :atom do
      description "Type of question being generated"
      constraints one_of: [:gap_filling, :sector_specific, :regulatory_context, :follow_up]
      default :gap_filling
    end
    
    attribute :generated_questions, {:array, :map} do
      description "Array of generated questions with metadata"
      default []
    end
    
    attribute :priority_score, :decimal do
      description "Priority score for the questions (0.0 to 1.0)"
      constraints min: 0.0, max: 1.0
    end
    
    attribute :context_data, :map do
      description "Context information used for question generation"
    end
    
    timestamps()
  end

  relationships do
    belongs_to :organization, Sertantai.Organizations.Organization
    belongs_to :analysis, Sertantai.AI.OrganizationAnalysis
    belongs_to :conversation_session, Sertantai.AI.ConversationSession
  end


  actions do
    defaults [:create, :read, :update, :destroy]
  end

  postgres do
    table "ai_question_generations"
    repo Sertantai.Repo
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
  end
end