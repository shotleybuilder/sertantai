defmodule Sertantai.Organizations.Calculations.Phase2Completeness do
  @moduledoc """
  Phase 2 enhanced profile completeness calculation.
  
  Calculates organization profile completeness including both Phase 1 core fields
  and Phase 2 extended fields for deeper applicability screening.
  """
  
  use Ash.Resource.Calculation
  
  @impl true
  def init(opts) do
    {:ok, opts}
  end
  
  @impl true
  def load(_query, _opts, _context) do
    [:core_profile]
  end
  
  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &calculate_phase2_completeness/1)
  end
  
  # Phase 1 Core Fields (required for basic screening)
  @phase1_fields [
    "organization_name",
    "organization_type", 
    "headquarters_region",
    "industry_sector"
  ]
  
  # Phase 2 Extended Fields (enhance screening accuracy)
  @phase2_fields [
    "operational_regions",
    "annual_turnover",
    "business_activities",
    "total_employees",
    "primary_sic_code",
    "compliance_requirements",
    "risk_profile"
  ]
  
  # Optional fields (nice-to-have for comprehensive profiling)
  @optional_fields [
    "registration_number",
    "special_circumstances"
  ]
  
  defp calculate_phase2_completeness(organization) do
    profile = organization.core_profile || %{}
    
    # Phase 1 fields are weighted highest (40% of score)
    phase1_score = calculate_field_completion(@phase1_fields, profile) * 0.4
    
    # Phase 2 fields are weighted second (50% of score)  
    phase2_score = calculate_field_completion(@phase2_fields, profile) * 0.5
    
    # Optional fields provide bonus completion (10% of score)
    optional_score = calculate_field_completion(@optional_fields, profile) * 0.1
    
    total_score = phase1_score + phase2_score + optional_score
    
    # Ensure score is between 0.0 and 1.0
    max(0.0, min(1.0, total_score))
  end
  
  defp calculate_field_completion(fields, profile) do
    total_fields = length(fields)
    
    if total_fields == 0 do
      1.0
    else
      completed_fields = 
        fields
        |> Enum.count(&field_completed?(profile, &1))
      
      completed_fields / total_fields
    end
  end
  
  defp field_completed?(profile, field) do
    case Map.get(profile, field) do
      nil -> false
      "" -> false
      [] -> false
      %{} -> false
      value when is_binary(value) -> String.trim(value) != ""
      value when is_number(value) -> value > 0
      value when is_list(value) -> length(value) > 0
      value when is_map(value) -> map_size(value) > 0
      _other -> true
    end
  end
end