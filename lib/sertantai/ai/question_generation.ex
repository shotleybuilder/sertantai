defmodule Sertantai.AI.QuestionGeneration do
  @moduledoc """
  AshAI resource for generating intelligent, context-aware questions
  to gather missing organization information.
  """

  use Ash.Resource,
    domain: Sertantai.AI,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAI]

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

    action :generate_contextual_questions, :map do
      description "Generate contextual questions based on gap analysis"
      
      argument :gap_analysis, :map do
        description "Results from organization gap analysis"
        allow_nil? false
      end
      
      argument :organization_context, :map do
        description "Current organization information for context"
        allow_nil? false
      end
      
      argument :conversation_history, {:array, :map} do
        description "Previous conversation context"
        default []
      end
      
      run fn input, _context ->
        # Placeholder for AI question generation logic
        # Will implement OpenAI integration with sector-specific templates
        %{
          questions: [
            %{
              question_text: "What is your organization's primary business activity?",
              target_field: "business_activities",
              priority: "high",
              question_type: "new_information",
              expected_response_type: "text",
              follow_up_potential: "high"
            },
            %{
              question_text: "In which regions do you operate?",
              target_field: "operational_regions", 
              priority: "high",
              question_type: "new_information",
              expected_response_type: "selection",
              follow_up_potential: "medium"
            }
          ],
          generation_metadata: %{
            question_count: 2,
            estimated_completion_time: 5,
            conversation_strategy: "start_with_critical_fields"
          }
        }
      end
    end

    action :prioritize_question_set, :map do
      description "Prioritize and order questions for optimal conversation flow"
      
      argument :questions, {:array, :map} do
        description "Set of questions to prioritize"
        allow_nil? false
      end
      
      argument :user_context, :map do
        description "User context for personalization"
        default %{}
      end
      
      run fn input, _context ->
        # Placeholder for question prioritization logic
        # Will implement smart ordering based on regulatory impact and flow
        %{
          prioritized_questions: [
            %{
              question_text: "What is your organization's primary business activity?",
              priority_score: 95,
              order: 1,
              rationale: "Critical for family mapping"
            }
          ],
          conversation_strategy: "regulatory_impact_first",
          estimated_completion_time: 8
        }
      end
    end

    action :generate_sector_questions, :map do
      description "Generate sector-specific questions based on organization type"
      
      argument :sector, :string do
        description "Industry sector (e.g., 'CONSTRUCTION', 'MANUFACTURING')"
        allow_nil? false
      end
      
      argument :organization_size, :string do
        description "Organization size category (small/medium/large)"
        allow_nil? false
      end
      
      run fn input, _context ->
        # Placeholder for sector-specific question logic
        sector = input.arguments.sector
        size = input.arguments.organization_size
        
        questions = case sector do
          "CONSTRUCTION" ->
            [
              %{
                question_text: "What types of construction projects do you undertake?",
                target_field: "construction_activities",
                sector_specific: true,
                regulatory_families: ["CONSTRUCTION", "HEALTH_AND_SAFETY"]
              },
              %{
                question_text: "Do you employ contractors or subcontractors?",
                target_field: "contractor_relationships", 
                sector_specific: true,
                regulatory_families: ["CONSTRUCTION", "EMPLOYMENT"]
              }
            ]
          "MANUFACTURING" ->
            [
              %{
                question_text: "What products do you manufacture?",
                target_field: "manufactured_products",
                sector_specific: true,
                regulatory_families: ["MANUFACTURING", "PRODUCT_SAFETY"]
              }
            ]
          _ ->
            [
              %{
                question_text: "What services do you provide?",
                target_field: "services_provided",
                sector_specific: false,
                regulatory_families: ["GENERAL"]
              }
            ]
        end
        
        %{
          sector_questions: questions,
          sector: sector,
          size_considerations: %{
            size: size,
            threshold_questions: size == "large"
          }
        }
      end
    end
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
    define :generate_contextual_questions, args: [:gap_analysis, :organization_context, :conversation_history]
    define :prioritize_question_set, args: [:questions, :user_context]
    define :generate_sector_questions, args: [:sector, :organization_size]
  end
end