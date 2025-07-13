defmodule Sertantai.AI.OrganizationAnalysis do
  @moduledoc """
  AshAI resource for analyzing organization profiles and identifying data gaps.
  
  This resource uses AI to analyze organization profiles and identify missing
  critical information needed for comprehensive applicability screening.
  """

  use Ash.Resource,
    domain: Sertantai.AI,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    
    attribute :organization_id, :uuid do
      description "ID of the organization being analyzed"
      allow_nil? false
    end
    
    attribute :conversation_session_id, :uuid do
      description "ID of the conversation session"
      allow_nil? true
    end
    
    attribute :analysis_type, :atom do
      description "Type of analysis performed"
      constraints one_of: [:gap_analysis, :sector_analysis, :completeness_check]
      default :gap_analysis
    end
    
    attribute :gap_analysis_result, :map do
      description "Structured result of the gap analysis"
    end
    
    attribute :confidence_score, :decimal do
      description "Confidence score for the analysis results (0.0 to 1.0)"
      constraints min: 0.0, max: 1.0
    end
    
    attribute :recommendations, {:array, :string} do
      description "List of recommendations for data collection"
      default []
    end
    
    timestamps()
  end

  relationships do
    belongs_to :organization, Sertantai.Organizations.Organization do
      description "The organization being analyzed"
    end
    
    belongs_to :conversation_session, Sertantai.AI.ConversationSession do
      description "The conversation session this analysis belongs to"
    end
  end


  actions do
    defaults [:create, :read, :update, :destroy]
  end

  postgres do
    table "ai_organization_analyses"
    repo Sertantai.Repo
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
  end
end