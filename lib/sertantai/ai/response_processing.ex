defmodule Sertantai.AI.ResponseProcessing do
  @moduledoc """
  AshAI resource for processing natural language responses and mapping
  them to structured organization schema fields.
  """

  use Ash.Resource,
    domain: Sertantai.AI,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAI]

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

    action :extract_organization_entities, :map do
      description "Extract structured organization data from natural language response"
      
      argument :user_response, :string do
        description "User's natural language response"
        allow_nil? false
      end
      
      argument :question_context, :map do
        description "Context about the question that was asked"
        allow_nil? false
      end
      
      argument :organization_schema, :map do
        description "Expected organization schema fields"
        allow_nil? false
      end
      
      run fn input, _context ->
        # Placeholder for entity extraction logic
        # Will implement OpenAI integration for NLP processing
        response = input.arguments.user_response
        context = input.arguments.question_context
        
        # Basic entity extraction based on question context
        extracted_data = extract_entities_from_response(response, context)
        
        %{
          extracted_fields: extracted_data,
          confidence_scores: calculate_confidence_scores(extracted_data),
          clarifications_needed: identify_clarifications_needed(response, context),
          extraction_notes: "Processed via placeholder logic",
          validation_warnings: []
        }
      end
    end

    action :validate_extracted_data, :map do
      description "Validate extracted data against organization schema constraints"
      
      argument :extracted_data, :map do
        description "Data extracted from user response"
        allow_nil? false
      end
      
      argument :schema_constraints, :map do
        description "Schema validation constraints"
        allow_nil? false
      end
      
      argument :existing_data, :map do
        description "Existing organization data for conflict detection"
        default %{}
      end
      
      run fn input, _context ->
        # Placeholder for validation logic
        # Will implement comprehensive schema validation
        extracted = input.arguments.extracted_data
        constraints = input.arguments.schema_constraints
        existing = input.arguments.existing_data
        
        validation_result = validate_against_schema(extracted, constraints, existing)
        
        %{
          validation_status: validation_result.status,
          validation_errors: validation_result.errors,
          data_conflicts: detect_conflicts(extracted, existing),
          suggestions: generate_improvement_suggestions(extracted),
          corrected_data: apply_auto_corrections(extracted),
          confidence_assessment: calculate_overall_confidence(extracted)
        }
      end
    end

    action :map_to_organization_fields, :map do
      description "Map validated extracted data to organization schema fields"
      
      argument :extracted_data, :map do
        description "Validated extracted data"
        allow_nil? false
      end
      
      argument :target_organization_id, :uuid do
        description "Organization to update"
        allow_nil? false
      end
      
      run fn input, _context ->
        # Placeholder for schema mapping logic
        # Will implement field mapping to organization core_profile
        extracted = input.arguments.extracted_data
        org_id = input.arguments.target_organization_id
        
        field_mappings = map_extracted_to_schema_fields(extracted)
        
        %{
          organization_id: org_id,
          field_mappings: field_mappings,
          update_operations: generate_update_operations(field_mappings),
          mapping_confidence: calculate_mapping_confidence(field_mappings),
          preview_changes: preview_organization_changes(field_mappings, org_id)
        }
      end
    end
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
    define :extract_organization_entities, args: [:user_response, :question_context, :organization_schema]
    define :validate_extracted_data, args: [:extracted_data, :schema_constraints, :existing_data]
    define :map_to_organization_fields, args: [:extracted_data, :target_organization_id]
  end

  # Private helper functions for response processing

  defp extract_entities_from_response(response, context) do
    # Basic entity extraction based on question context
    target_field = context["target_field"]
    
    case target_field do
      "business_activities" ->
        %{"business_activities" => extract_business_activities(response)}
      
      "operational_regions" ->
        %{"operational_regions" => extract_regions(response)}
      
      "employee_count" ->
        %{"employee_count" => extract_numbers(response)}
      
      _ ->
        %{"general_response" => String.trim(response)}
    end
  end

  defp extract_business_activities(response) do
    # Extract business activities from natural language
    response
    |> String.downcase()
    |> String.split([",", "and", "&", ";"])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp extract_regions(response) do
    # Extract geographical regions
    known_regions = ["england", "scotland", "wales", "northern ireland", "uk", "great britain"]
    
    response_lower = String.downcase(response)
    
    Enum.filter(known_regions, fn region ->
      String.contains?(response_lower, region)
    end)
  end

  defp extract_numbers(response) do
    # Extract numeric values from response
    case Regex.run(~r/(\d+)/, response) do
      [_, number] -> String.to_integer(number)
      _ -> nil
    end
  end

  defp calculate_confidence_scores(extracted_data) do
    # Calculate confidence scores for each extracted field
    Map.new(extracted_data, fn {field, value} ->
      confidence = case value do
        nil -> 0.1
        "" -> 0.2
        value when is_list(value) and length(value) > 0 -> 0.8
        value when is_integer(value) -> 0.9
        _ -> 0.7
      end
      
      {field, confidence}
    end)
  end

  defp identify_clarifications_needed(response, context) do
    # Identify if clarification is needed based on response quality
    if String.length(String.trim(response)) < 10 do
      ["Response seems too brief, could you provide more detail?"]
    else
      []
    end
  end

  defp validate_against_schema(extracted_data, _constraints, _existing) do
    # Basic validation logic
    errors = []
    
    status = if length(errors) == 0, do: "valid", else: "invalid"
    
    %{status: status, errors: errors}
  end

  defp detect_conflicts(extracted_data, existing_data) do
    # Detect conflicts between extracted and existing data
    conflicts = []
    
    Enum.reduce(extracted_data, conflicts, fn {field, new_value}, acc ->
      case Map.get(existing_data, field) do
        nil -> acc
        ^new_value -> acc
        existing_value -> 
          [%{field: field, existing: existing_value, new: new_value} | acc]
      end
    end)
  end

  defp generate_improvement_suggestions(extracted_data) do
    # Generate suggestions for data quality improvement
    suggestions = []
    
    Enum.reduce(extracted_data, suggestions, fn {field, value}, acc ->
      case {field, value} do
        {"employee_count", count} when is_integer(count) and count > 1000 ->
          ["Consider providing employee count ranges for large organizations" | acc]
        
        {"business_activities", activities} when is_list(activities) and length(activities) > 5 ->
          ["Consider focusing on primary business activities" | acc]
        
        _ -> acc
      end
    end)
  end

  defp apply_auto_corrections(extracted_data) do
    # Apply automatic corrections to extracted data
    Map.new(extracted_data, fn {field, value} ->
      corrected_value = case {field, value} do
        {"operational_regions", regions} when is_list(regions) ->
          # Standardize region names
          Enum.map(regions, &standardize_region_name/1)
        
        _ -> value
      end
      
      {field, corrected_value}
    end)
  end

  defp standardize_region_name(region) do
    # Standardize region names to consistent format
    case String.downcase(String.trim(region)) do
      "uk" -> "United Kingdom"
      "gb" -> "Great Britain"
      "england" -> "England"
      "scotland" -> "Scotland"
      "wales" -> "Wales"
      "northern ireland" -> "Northern Ireland"
      other -> String.capitalize(other)
    end
  end

  defp calculate_overall_confidence(extracted_data) do
    # Calculate overall confidence for the extraction
    if map_size(extracted_data) == 0 do
      0.0
    else
      scores = Map.values(calculate_confidence_scores(extracted_data))
      Enum.sum(scores) / length(scores)
    end
  end

  defp map_extracted_to_schema_fields(extracted_data) do
    # Map extracted data to organization schema fields
    Map.new(extracted_data, fn {field, value} ->
      schema_field = case field do
        "business_activities" -> "core_profile.business_activities"
        "operational_regions" -> "core_profile.operational_regions"
        "employee_count" -> "core_profile.total_employees"
        other -> "core_profile.#{other}"
      end
      
      {schema_field, value}
    end)
  end

  defp generate_update_operations(field_mappings) do
    # Generate operations to update organization record
    Enum.map(field_mappings, fn {field_path, value} ->
      %{
        operation: "set",
        field: field_path,
        value: value,
        timestamp: DateTime.utc_now()
      }
    end)
  end

  defp calculate_mapping_confidence(field_mappings) do
    # Calculate confidence in field mappings
    if map_size(field_mappings) == 0 do
      0.0
    else
      0.8  # Default mapping confidence
    end
  end

  defp preview_organization_changes(field_mappings, org_id) do
    # Preview what changes would be made to organization
    %{
      organization_id: org_id,
      fields_to_update: Map.keys(field_mappings),
      preview: "Organization profile will be updated with discovered information",
      estimated_completeness_increase: map_size(field_mappings) * 5
    }
  end
end