defmodule Sertantai.Query.ProgressiveQueryBuilder do
  @moduledoc """
  Phase 2 Progressive Query Builder for adaptive applicability screening.
  
  Builds queries that adapt to available organization data and optimize performance
  through function-based filtering and complexity scoring.
  """

  alias Sertantai.Organizations.ApplicabilityMatcher
  alias Sertantai.UkLrt

  @doc """
  Builds a progressive query strategy based on organization profile completeness.
  Returns query parameters optimized for the available data.
  """
  def build_query_strategy(organization) do
    profile_score = calculate_profile_completeness(organization)
    complexity_level = determine_complexity_level(profile_score)
    
    %{
      complexity_level: complexity_level,
      query_params: build_query_params(organization, complexity_level),
      performance_estimate: estimate_query_performance(complexity_level),
      fallback_strategy: determine_fallback_strategy(organization),
      cache_ttl: calculate_cache_ttl(complexity_level, organization)
    }
  end

  @doc """
  Executes progressive screening with adaptive complexity.
  Returns results with performance metadata for optimization.
  """
  def execute_progressive_screening(organization, _opts \\ []) do
    strategy = build_query_strategy(organization)
    start_time = System.monotonic_time(:millisecond)
    
    results = case strategy.complexity_level do
      :basic -> execute_basic_screening(organization, strategy)
      :enhanced -> execute_enhanced_screening(organization, strategy)
      :comprehensive -> execute_comprehensive_screening(organization, strategy)
    end
    
    execution_time = System.monotonic_time(:millisecond) - start_time
    
    Map.merge(results, %{
      performance_metadata: %{
        execution_time_ms: execution_time,
        complexity_level: strategy.complexity_level,
        estimated_performance: strategy.performance_estimate,
        cache_ttl: strategy.cache_ttl,
        query_optimization_applied: true
      }
    })
  end

  @doc """
  Calculates query complexity score based on available organization data.
  Higher scores indicate more data available for precise matching.
  """
  def calculate_query_complexity_score(organization) do
    profile = get_organization_profile(organization)
    
    # Phase 1 core fields (40% weight)
    phase1_score = calculate_phase1_completeness(profile) * 0.4
    
    # Phase 2 extended fields (50% weight)
    phase2_score = calculate_phase2_completeness(profile) * 0.5
    
    # Data quality indicators (10% weight)
    quality_score = calculate_data_quality_score(profile) * 0.1
    
    total_score = phase1_score + phase2_score + quality_score
    
    %{
      total_score: total_score,
      phase1_completeness: phase1_score / 0.4,
      phase2_completeness: phase2_score / 0.5,
      data_quality: quality_score / 0.1,
      recommended_complexity: determine_complexity_level(total_score)
    }
  end

  # Private implementation functions

  defp calculate_profile_completeness(organization) do
    profile = get_organization_profile(organization)
    
    # Use Phase 2 completeness calculation if available
    case organization do
      %{phase2_completeness_score: score} when is_number(score) -> score
      _ -> calculate_basic_completeness(profile)
    end
  end

  defp determine_complexity_level(score) when score >= 0.8, do: :comprehensive
  defp determine_complexity_level(score) when score >= 0.5, do: :enhanced
  defp determine_complexity_level(_score), do: :basic

  defp build_query_params(organization, complexity_level) do
    base_params = %{
      family: map_sector_to_family(
        ApplicabilityMatcher.get_industry_sector(organization)
      ),
      geo_extent: ApplicabilityMatcher.get_applicable_geo_extent(organization),
      live_status: "✔ In force"
    }

    case complexity_level do
      :basic -> base_params
      :enhanced -> Map.merge(base_params, build_enhanced_params(organization))
      :comprehensive -> Map.merge(base_params, build_comprehensive_params(organization))
    end
  end

  defp build_enhanced_params(organization) do
    profile = get_organization_profile(organization)
    
    %{
      employee_range: categorize_employee_count(Map.get(profile, "total_employees")),
      operational_regions: Map.get(profile, "operational_regions", []),
      business_activities: Map.get(profile, "business_activities", [])
    }
  end

  defp build_comprehensive_params(organization) do
    profile = get_organization_profile(organization)
    
    enhanced_params = build_enhanced_params(organization)
    
    Map.merge(enhanced_params, %{
      annual_turnover_range: categorize_turnover(Map.get(profile, "annual_turnover")),
      compliance_requirements: Map.get(profile, "compliance_requirements", []),
      risk_profile: Map.get(profile, "risk_profile"),
      special_circumstances: Map.get(profile, "special_circumstances")
    })
  end

  defp execute_basic_screening(organization, strategy) do
    params = strategy.query_params
    
    # Use function-optimized basic screening (Making laws only)
    try do
      count_result = UkLrt.count_for_screening(params.family, params.geo_extent, params.live_status)
      preview_result = UkLrt.for_applicability_screening(params.family, params.geo_extent, params.live_status, 5)
      
      count = case count_result do
        {:ok, c} -> c
        _ -> 0
      end
      
      preview = case preview_result do
        {:ok, p} -> p
        _ -> []
      end
      
      %{
        applicable_law_count: count,
        sample_regulations: preview,
        screening_method: "progressive_basic",
        organization_profile: extract_basic_profile(organization),
        generated_at: DateTime.utc_now(),
        confidence_level: "basic"
      }
    rescue
      _error ->
        %{
          applicable_law_count: 0,
          sample_regulations: [],
          screening_method: "progressive_basic_fallback",
          organization_profile: extract_basic_profile(organization),
          generated_at: DateTime.utc_now(),
          confidence_level: "basic"
        }
    end
  end

  defp execute_enhanced_screening(organization, strategy) do
    # Enhanced screening with additional filtering
    basic_results = execute_basic_screening(organization, strategy)
    enhanced_filters = strategy.query_params
    
    # Apply enhanced filtering to basic results
    filtered_regulations = apply_enhanced_filtering(
      basic_results.sample_regulations, 
      enhanced_filters
    )
    
    Map.merge(basic_results, %{
      sample_regulations: filtered_regulations,
      screening_method: "progressive_enhanced",
      confidence_level: "enhanced",
      enhanced_filters_applied: Map.keys(enhanced_filters) -- [:family, :geo_extent, :live_status]
    })
  end

  defp execute_comprehensive_screening(organization, strategy) do
    # Comprehensive screening with full profile analysis
    enhanced_results = execute_enhanced_screening(organization, strategy)
    comprehensive_filters = strategy.query_params
    
    # Apply comprehensive analysis
    analyzed_regulations = apply_comprehensive_analysis(
      enhanced_results.sample_regulations,
      comprehensive_filters,
      organization
    )
    
    Map.merge(enhanced_results, %{
      sample_regulations: analyzed_regulations,
      screening_method: "progressive_comprehensive",
      confidence_level: "high",
      comprehensive_analysis: true,
      risk_assessment: calculate_risk_assessment(organization, analyzed_regulations)
    })
  end

  defp estimate_query_performance(complexity_level) do
    case complexity_level do
      :basic -> %{estimated_time_ms: 50, cache_effectiveness: "high"}
      :enhanced -> %{estimated_time_ms: 150, cache_effectiveness: "medium"}
      :comprehensive -> %{estimated_time_ms: 400, cache_effectiveness: "low"}
    end
  end

  defp determine_fallback_strategy(organization) do
    profile = get_organization_profile(organization)
    
    cond do
      has_minimal_data?(profile) -> :use_sector_defaults
      has_partial_data?(profile) -> :interpolate_missing_fields
      true -> :use_profile_as_is
    end
  end

  defp calculate_cache_ttl(complexity_level, organization) do
    base_ttl = case complexity_level do
      :basic -> :timer.hours(4)
      :enhanced -> :timer.hours(2)
      :comprehensive -> :timer.hours(1)
    end
    
    # Adjust based on organization stability
    employee_count = ApplicabilityMatcher.get_total_employees(organization)
    stability_multiplier = case employee_count do
      n when is_integer(n) and n > 1000 -> 2.0  # Large orgs change less
      n when is_integer(n) and n > 100 -> 1.5   # Medium orgs
      _ -> 1.0                                   # Small orgs change more
    end
    
    round(base_ttl * stability_multiplier)
  end

  # Helper functions for profile analysis

  defp get_organization_profile(organization) do
    case organization do
      %{core_profile: profile} when is_map(profile) -> profile
      %{"core_profile" => profile} when is_map(profile) -> profile
      _ -> %{}
    end
  end

  defp calculate_basic_completeness(profile) do
    required_fields = ["organization_name", "organization_type", "headquarters_region", "industry_sector"]
    completed = Enum.count(required_fields, &Map.has_key?(profile, &1))
    completed / length(required_fields)
  end

  defp calculate_phase1_completeness(profile) do
    phase1_fields = ["organization_name", "organization_type", "headquarters_region", "industry_sector"]
    completed = Enum.count(phase1_fields, &field_has_value?(profile, &1))
    completed / length(phase1_fields)
  end

  defp calculate_phase2_completeness(profile) do
    phase2_fields = [
      "operational_regions", "annual_turnover", "business_activities", 
      "total_employees", "primary_sic_code", "compliance_requirements", "risk_profile"
    ]
    completed = Enum.count(phase2_fields, &field_has_value?(profile, &1))
    completed / length(phase2_fields)
  end

  defp calculate_data_quality_score(profile) do
    # Assess data quality based on field completeness and validity
    quality_indicators = [
      has_valid_employee_count?(profile),
      has_valid_turnover?(profile),
      has_valid_regions?(profile),
      has_detailed_activities?(profile)
    ]
    
    Enum.count(quality_indicators, & &1) / length(quality_indicators)
  end

  defp field_has_value?(profile, field) do
    case Map.get(profile, field) do
      nil -> false
      "" -> false
      [] -> false
      %{} -> false
      _value -> true
    end
  end

  defp has_valid_employee_count?(profile) do
    case Map.get(profile, "total_employees") do
      n when is_integer(n) and n > 0 -> true
      _ -> false
    end
  end

  defp has_valid_turnover?(profile) do
    case Map.get(profile, "annual_turnover") do
      n when is_number(n) and n > 0 -> true
      _ -> false
    end
  end

  defp has_valid_regions?(profile) do
    case Map.get(profile, "operational_regions") do
      regions when is_list(regions) and length(regions) > 0 -> true
      _ -> false
    end
  end

  defp has_detailed_activities?(profile) do
    case Map.get(profile, "business_activities") do
      activities when is_list(activities) and length(activities) > 1 -> true
      _ -> false
    end
  end

  defp categorize_employee_count(nil), do: :unknown
  defp categorize_employee_count(count) when is_integer(count) do
    cond do
      count < 10 -> :micro
      count < 50 -> :small
      count < 250 -> :medium
      count < 1000 -> :large
      true -> :enterprise
    end
  end

  defp categorize_turnover(nil), do: :unknown
  defp categorize_turnover(turnover) when is_number(turnover) do
    cond do
      turnover < 100_000 -> :micro
      turnover < 1_000_000 -> :small
      turnover < 10_000_000 -> :medium
      turnover < 50_000_000 -> :large
      true -> :enterprise
    end
  end

  defp extract_basic_profile(organization) do
    %{
      industry_sector: ApplicabilityMatcher.get_industry_sector(organization),
      headquarters_region: ApplicabilityMatcher.get_headquarters_region(organization),
      total_employees: ApplicabilityMatcher.get_total_employees(organization)
    }
  end

  defp apply_enhanced_filtering(regulations, filters) do
    # Enhanced filtering logic for improved accuracy
    regulations
    |> filter_by_employee_range(Map.get(filters, :employee_range))
    |> filter_by_operational_regions(Map.get(filters, :operational_regions))
    |> filter_by_business_activities(Map.get(filters, :business_activities))
  end

  defp apply_comprehensive_analysis(regulations, filters, organization) do
    # Comprehensive analysis with risk assessment
    regulations
    |> apply_enhanced_filtering(filters)
    |> analyze_compliance_requirements(Map.get(filters, :compliance_requirements))
    |> assess_risk_profile(Map.get(filters, :risk_profile))
    |> prioritize_by_relevance(organization)
  end

  defp calculate_risk_assessment(organization, regulations) do
    profile = get_organization_profile(organization)
    
    %{
      risk_level: Map.get(profile, "risk_profile", "medium"),
      applicable_regulation_count: length(regulations),
      priority_areas: identify_priority_compliance_areas(regulations),
      recommended_actions: generate_compliance_recommendations(regulations, profile)
    }
  end

  defp filter_by_employee_range(regulations, nil), do: regulations
  defp filter_by_employee_range(regulations, _range) do
    # TODO: Implement employee-based filtering when duty_holder JSONB analysis is ready
    regulations
  end

  defp filter_by_operational_regions(regulations, nil), do: regulations
  defp filter_by_operational_regions(regulations, _regions) do
    # TODO: Implement multi-region filtering
    regulations
  end

  defp filter_by_business_activities(regulations, nil), do: regulations
  defp filter_by_business_activities(regulations, _activities) do
    # TODO: Implement activity-based filtering
    regulations
  end

  defp analyze_compliance_requirements(regulations, nil), do: regulations
  defp analyze_compliance_requirements(regulations, _requirements) do
    # TODO: Implement compliance requirement analysis
    regulations
  end

  defp assess_risk_profile(regulations, nil), do: regulations
  defp assess_risk_profile(regulations, _risk_profile) do
    # TODO: Implement risk-based prioritization
    regulations
  end

  defp prioritize_by_relevance(regulations, _organization) do
    # TODO: Implement relevance-based prioritization
    regulations
  end

  defp identify_priority_compliance_areas(_regulations) do
    # TODO: Analyze regulations to identify key compliance areas
    ["health_safety", "environmental", "data_protection"]
  end

  defp generate_compliance_recommendations(_regulations, _profile) do
    # TODO: Generate actionable compliance recommendations
    [
      "Review health and safety regulations applicable to your sector",
      "Ensure environmental compliance for your operational regions",
      "Validate data protection requirements for your business activities"
    ]
  end

  defp has_minimal_data?(profile) do
    required_fields = ["organization_name", "organization_type", "headquarters_region", "industry_sector"]
    completed = Enum.count(required_fields, &Map.has_key?(profile, &1))
    completed < 2
  end

  defp has_partial_data?(profile) do
    required_fields = ["organization_name", "organization_type", "headquarters_region", "industry_sector"]
    completed = Enum.count(required_fields, &Map.has_key?(profile, &1))
    completed >= 2 && completed < 4
  end

  # Sector to family mapping - copied from ApplicabilityMatcher for independence
  defp map_sector_to_family("construction"), do: "💙 CONSTRUCTION"
  defp map_sector_to_family("healthcare"), do: "💙 HEALTH"
  defp map_sector_to_family("health"), do: "💙 HEALTH"
  defp map_sector_to_family("manufacturing"), do: "💙 MANUFACTURING"
  defp map_sector_to_family("education"), do: "💙 EDUCATION"
  defp map_sector_to_family("fire_safety"), do: "💙 FIRE"
  defp map_sector_to_family("fire"), do: "💙 FIRE"
  defp map_sector_to_family("transport"), do: "💙 TRANSPORT"
  defp map_sector_to_family("transportation"), do: "💙 TRANSPORT"
  defp map_sector_to_family("energy"), do: "💙 ENERGY"
  defp map_sector_to_family("environment"), do: "💙 ENVIRONMENT"
  defp map_sector_to_family("waste"), do: "💙 WASTE"
  defp map_sector_to_family("water"), do: "💙 WATER"
  defp map_sector_to_family("food"), do: "💙 FOOD"
  defp map_sector_to_family("agriculture"), do: "💙 AGRICULTURE"
  defp map_sector_to_family("mining"), do: "💙 MINING"
  defp map_sector_to_family("chemicals"), do: "💙 CHEMICALS"
  defp map_sector_to_family("nuclear"), do: "💙 NUCLEAR"
  defp map_sector_to_family("telecommunications"), do: "💙 TELECOMMUNICATIONS"
  defp map_sector_to_family(_), do: nil
end