defmodule Sertantai.AI.OrganizationAnalysis do
  @moduledoc """
  AshAI resource for analyzing organization profiles and identifying data gaps.
  
  This resource uses AI to analyze organization profiles and identify missing
  critical information needed for comprehensive applicability screening.
  """

  use Ash.Resource,
    domain: Sertantai.AI,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAI]

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

    action :analyze_profile_gaps, :map do
      description "Analyze organization profile to identify critical data gaps"
      
      argument :organization_profile, :map do
        description "Current organization profile data"
        allow_nil? false
      end
      
      argument :sector_context, :string do
        description "Industry sector context for analysis"
        allow_nil? false
      end
      
      run fn input, _context ->
        # Placeholder for AI gap analysis logic
        # Will implement OpenAI integration once basic structure is working
        %{
          missing_critical_fields: ["business_activities", "operational_regions"],
          sector_specific_gaps: [
            %{field: "employee_count", importance: "high", reason: "Size-based thresholds"}
          ],
          risk_prioritization: %{
            high: ["business_activities", "operational_regions"],
            medium: ["annual_turnover"],
            low: ["organization_chart"]
          },
          confidence_score: 0.8,
          completeness_percentage: 60
        }
      end
    end

    action :assess_profile_completeness, :map do
      description "Assess overall completeness of organization profile for UK regulatory screening"
      
      argument :organization_profile, :map do
        description "Organization profile to assess"
        allow_nil? false
      end
      
      run fn input, _context ->
        # Placeholder for AI completeness assessment logic
        # Will implement OpenAI integration once basic structure is working
        %{
          overall_completeness_percentage: 75,
          section_scores: %{
            core_identity: %{score: 90, weight: 20},
            business_operations: %{score: 60, weight: 25},
            size_and_scale: %{score: 80, weight: 20}
          },
          completed_sections: ["core_identity", "size_and_scale"],
          incomplete_sections: [
            %{section: "business_operations", missing: ["detailed_activities"]},
            %{section: "geographic_presence", missing: ["operational_regions"]}
          ],
          readiness_for_screening: false,
          recommended_next_steps: ["Complete business activities section"]
        }
      end
    end
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
    define :analyze_profile_gaps, args: [:organization_profile, :sector_context]
    define :assess_profile_completeness, args: [:organization_profile]
  end
end