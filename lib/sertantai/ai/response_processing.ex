defmodule Sertantai.AI.ResponseProcessing do
  @moduledoc """
  AshAI resource for processing natural language responses and mapping
  them to structured organization schema fields.
  """

  use Ash.Resource,
    domain: Sertantai.AI,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    
    attribute :session_id, :uuid do
      description "ID of the conversation session"
      allow_nil? false
    end
    
    attribute :user_response, :string do
      description "Original user response text"
      allow_nil? false
    end
    
    attribute :extracted_data, :map do
      description "Structured data extracted from response"
      default %{}
    end
    
    attribute :confidence_scores, :map do
      description "Confidence scores for each extracted field"
      default %{}
    end
    
    attribute :validation_status, :atom do
      description "Validation status of extracted data"
      constraints one_of: [:pending, :valid, :needs_clarification, :invalid]
      default :pending
    end
    
    attribute :processing_metadata, :map do
      description "Metadata about the processing attempt"
      default %{}
    end
    
    timestamps()
  end

  relationships do
    belongs_to :session, Sertantai.AI.ConversationSession
  end


  actions do
    defaults [:create, :read, :update, :destroy]
  end

  postgres do
    table "ai_response_processings"
    repo Sertantai.Repo
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
  end
end