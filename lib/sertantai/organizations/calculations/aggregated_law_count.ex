defmodule Sertantai.Organizations.Calculations.AggregatedLawCount do
  @moduledoc """
  Calculates the total number of applicable laws across all organization locations.
  Handles deduplication of laws that apply to multiple locations.
  
  Phase 1 of multi-location organization support.
  """
  
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, _context) do
    [:locations]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn organization ->
      case organization.locations do
        %Ash.NotLoaded{} -> 0
        locations when is_list(locations) ->
          aggregate_laws_from_locations(locations, organization)
        _ -> 0
      end
    end)
  end

  defp aggregate_laws_from_locations(locations, organization) do
    # Get all unique laws that apply to any location of this organization
    active_locations = Enum.filter(locations, &(&1.operational_status == :active))
    
    case active_locations do
      [] -> 0
      [single_location] ->
        # Single location - use direct count
        get_location_law_count(single_location)
      
      multiple_locations ->
        # Multi-location - aggregate and deduplicate
        aggregate_multi_location_laws(multiple_locations, organization)
    end
  end

  defp aggregate_multi_location_laws(locations, organization) do
    # For Phase 1, we'll use a simplified calculation
    # This will be enhanced in Phase 3 with actual law matching
    
    # Collect all applicable law IDs from all locations
    all_law_ids = 
      locations
      |> Enum.flat_map(&get_applicable_law_ids/1)
      |> Enum.uniq()
    
    # Add organization-wide laws (those that apply regardless of location)
    org_wide_laws = get_organization_wide_applicable_laws(organization)
    
    (all_law_ids ++ org_wide_laws)
    |> Enum.uniq()
    |> length()
  end

  defp get_location_law_count(location) do
    # For Phase 1, return a placeholder calculation
    # This will be replaced with actual ApplicabilityMatcher logic in Phase 3
    base_count = calculate_base_count_from_profile(location)
    
    # Apply location-specific multipliers
    location_multiplier = get_location_type_multiplier(location.location_type)
    activity_multiplier = get_activity_multiplier(location.industry_activities)
    
    round(base_count * location_multiplier * activity_multiplier)
  end

  defp get_applicable_law_ids(location) do
    # For Phase 1, return placeholder law IDs based on location characteristics
    # This will be replaced with actual query logic in Phase 3
    base_laws = generate_base_law_ids(location)
    geographic_laws = generate_geographic_law_ids(location.geographic_region)
    activity_laws = generate_activity_law_ids(location.industry_activities)
    
    base_laws ++ geographic_laws ++ activity_laws
  end

  defp get_organization_wide_applicable_laws(organization) do
    # Laws that apply at organization level (e.g., corporate governance, reporting)
    # For Phase 1, return placeholder organization-wide law IDs
    org_type = organization.core_profile["organization_type"] || "limited_company"
    
    case org_type do
      "limited_company" -> ["corp_gov_001", "financial_reporting_001", "directors_duties_001"]
      "partnership" -> ["partnership_001", "tax_reporting_001"]
      "sole_trader" -> ["sole_trader_001", "personal_tax_001"]
      _ -> ["general_business_001"]
    end
  end

  # Phase 1 placeholder calculation helpers
  # These will be replaced with actual law matching in Phase 3
  
  defp calculate_base_count_from_profile(location) do
    # Base count calculation from location characteristics
    base = 10
    
    # Add count based on employee count
    employee_addition = case location.employee_count do
      nil -> 0
      count when count < 10 -> 5
      count when count < 50 -> 15
      count when count < 250 -> 25
      _ -> 40
    end
    
    # Add count based on revenue
    revenue_addition = case location.annual_revenue do
      nil -> 0
      revenue when revenue < 100_000 -> 3
      revenue when revenue < 1_000_000 -> 8
      revenue when revenue < 10_000_000 -> 15
      _ -> 25
    end
    
    base + employee_addition + revenue_addition
  end

  defp get_location_type_multiplier(location_type) do
    case location_type do
      :headquarters -> 1.5
      :manufacturing_site -> 1.4
      :warehouse -> 1.1
      :retail_outlet -> 1.2
      :project_site -> 1.3
      :temporary_location -> 0.8
      :home_office -> 0.7
      _ -> 1.0
    end
  end

  defp get_activity_multiplier(industry_activities) do
    case length(industry_activities || []) do
      0 -> 1.0
      1 -> 1.1
      2 -> 1.2
      3 -> 1.3
      _ -> 1.4
    end
  end

  defp generate_base_law_ids(location) do
    # Generate placeholder law IDs based on location characteristics
    base_laws = ["health_safety_001", "employment_001", "tax_001"]
    
    if location.employee_count && location.employee_count > 10 do
      base_laws ++ ["workplace_regs_001", "pension_001"]
    else
      base_laws
    end
  end

  defp generate_geographic_law_ids(geographic_region) do
    case geographic_region do
      "england" -> ["england_planning_001", "england_env_001"]
      "scotland" -> ["scotland_planning_001", "scotland_env_001", "scotland_specific_001"]
      "wales" -> ["wales_planning_001", "wales_env_001", "welsh_language_001"]
      "northern_ireland" -> ["ni_planning_001", "ni_env_001", "ni_specific_001"]
      _ -> ["uk_general_001"]
    end
  end

  defp generate_activity_law_ids(industry_activities) do
    (industry_activities || [])
    |> Enum.flat_map(fn activity ->
      case activity do
        "construction" -> ["construction_001", "construction_safety_001"]
        "manufacturing" -> ["manufacturing_001", "industrial_emissions_001"]
        "retail" -> ["retail_001", "consumer_protection_001"]
        "technology" -> ["data_protection_001", "ip_001"]
        _ -> ["general_activity_001"]
      end
    end)
  end
end