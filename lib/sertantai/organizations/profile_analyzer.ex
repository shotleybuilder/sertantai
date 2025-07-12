defmodule Sertantai.Organizations.ProfileAnalyzer do
  @moduledoc """
  Phase 2 Organization Profile Analyzer for enhanced applicability screening.
  
  Provides advanced profile analysis, data quality assessment, and intelligent
  recommendations for improving screening accuracy.
  """

  @doc """
  Performs comprehensive analysis of organization profile for screening optimization.
  """
  def analyze_organization_profile(organization) do
    profile = extract_profile(organization)
    
    %{
      completeness_analysis: analyze_completeness(profile),
      data_quality_assessment: assess_data_quality(profile),
      screening_readiness: evaluate_screening_readiness(profile),
      recommendations: generate_recommendations(profile),
      risk_indicators: identify_risk_indicators(profile),
      compliance_profile: build_compliance_profile(profile)
    }
  end

  @doc """
  Calculates enhanced profile completeness score with weighted categories.
  """
  def calculate_enhanced_completeness(profile) do
    categories = %{
      basic_identification: calculate_basic_identification_score(profile),
      operational_details: calculate_operational_details_score(profile),
      compliance_context: calculate_compliance_context_score(profile),
      risk_assessment: calculate_risk_assessment_score(profile)
    }
    
    weights = %{
      basic_identification: 0.4,  # Critical for basic matching
      operational_details: 0.3,   # Important for accuracy
      compliance_context: 0.2,    # Valuable for prioritization
      risk_assessment: 0.1        # Helpful for recommendations
    }
    
    weighted_score = categories
    |> Enum.map(fn {category, score} -> score * weights[category] end)
    |> Enum.sum()
    
    %{
      total_score: weighted_score,
      category_scores: categories,
      weights_applied: weights,
      completeness_level: determine_completeness_level(weighted_score)
    }
  end

  @doc """
  Identifies data quality issues and provides improvement suggestions.
  """
  def assess_data_quality(profile) do
    quality_checks = %{
      field_completeness: check_field_completeness(profile),
      data_consistency: check_data_consistency(profile),
      value_validity: check_value_validity(profile),
      logical_coherence: check_logical_coherence(profile)
    }
    
    issues = identify_quality_issues(quality_checks)
    
    %{
      overall_quality: calculate_overall_quality(quality_checks),
      quality_checks: quality_checks,
      identified_issues: issues,
      improvement_suggestions: generate_improvement_suggestions(issues),
      data_confidence: calculate_data_confidence(quality_checks)
    }
  end

  @doc """
  Evaluates organization's readiness for different screening complexity levels.
  """
  def evaluate_screening_readiness(profile) do
    %{
      basic_screening: evaluate_basic_readiness(profile),
      enhanced_screening: evaluate_enhanced_readiness(profile),
      comprehensive_screening: evaluate_comprehensive_readiness(profile),
      recommended_level: recommend_screening_level(profile)
    }
  end

  @doc """
  Generates intelligent recommendations for profile improvement.
  """
  def generate_profile_recommendations(organization) do
    profile = extract_profile(organization)
    analysis = analyze_organization_profile(organization)
    
    %{
      priority_improvements: identify_priority_improvements(analysis),
      quick_wins: identify_quick_wins(profile),
      compliance_focus_areas: identify_compliance_focus_areas(profile),
      data_collection_strategy: suggest_data_collection_strategy(analysis),
      screening_optimization: suggest_screening_optimization(analysis)
    }
  end

  @doc """
  Builds compliance profile based on organization characteristics.
  """
  def build_compliance_profile(profile) do
    %{
      sector_compliance_areas: identify_sector_compliance_areas(profile),
      geographic_requirements: identify_geographic_requirements(profile),
      size_based_obligations: identify_size_based_obligations(profile),
      activity_specific_rules: identify_activity_specific_rules(profile),
      risk_based_priorities: identify_risk_based_priorities(profile)
    }
  end

  # Private implementation functions

  defp extract_profile(organization) do
    case organization do
      %{core_profile: profile} when is_map(profile) -> profile
      %{"core_profile" => profile} when is_map(profile) -> profile
      _ -> %{}
    end
  end

  defp analyze_completeness(profile) do
    basic_fields = get_basic_fields()
    enhanced_fields = get_enhanced_fields()
    optional_fields = get_optional_fields()
    
    %{
      basic_completeness: calculate_field_completeness(profile, basic_fields),
      enhanced_completeness: calculate_field_completeness(profile, enhanced_fields),
      optional_completeness: calculate_field_completeness(profile, optional_fields),
      missing_critical_fields: identify_missing_fields(profile, basic_fields),
      missing_enhanced_fields: identify_missing_fields(profile, enhanced_fields)
    }
  end

  defp calculate_basic_identification_score(profile) do
    required_fields = ["organization_name", "organization_type", "headquarters_region", "industry_sector"]
    calculate_field_completeness(profile, required_fields)
  end

  defp calculate_operational_details_score(profile) do
    operational_fields = ["total_employees", "annual_turnover", "operational_regions", "business_activities"]
    calculate_field_completeness(profile, operational_fields)
  end

  defp calculate_compliance_context_score(profile) do
    compliance_fields = ["compliance_requirements", "risk_profile", "primary_sic_code"]
    calculate_field_completeness(profile, compliance_fields)
  end

  defp calculate_risk_assessment_score(profile) do
    risk_fields = ["special_circumstances", "risk_profile"]
    calculate_field_completeness(profile, risk_fields)
  end

  defp calculate_field_completeness(profile, fields) do
    if length(fields) == 0 do
      1.0
    else
      completed = Enum.count(fields, &field_has_meaningful_value?(profile, &1))
      completed / length(fields)
    end
  end

  defp field_has_meaningful_value?(profile, field) do
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

  defp determine_completeness_level(score) when score >= 0.9, do: :excellent
  defp determine_completeness_level(score) when score >= 0.7, do: :good
  defp determine_completeness_level(score) when score >= 0.5, do: :adequate
  defp determine_completeness_level(score) when score >= 0.3, do: :basic
  defp determine_completeness_level(_score), do: :insufficient

  defp check_field_completeness(profile) do
    all_fields = get_basic_fields() ++ get_enhanced_fields() ++ get_optional_fields()
    completed_count = Enum.count(all_fields, &field_has_meaningful_value?(profile, &1))
    
    ratio = completed_count / length(all_fields)
    %{
      total_fields: length(all_fields),
      completed_fields: completed_count,
      completeness_ratio: ratio,
      status: if(ratio >= 0.7, do: :good, else: :needs_improvement)
    }
  end

  defp check_data_consistency(profile) do
    consistency_checks = [
      check_employee_turnover_consistency(profile),
      check_region_activity_consistency(profile),
      check_size_classification_consistency(profile)
    ]
    
    passed_checks = Enum.count(consistency_checks, & &1)
    
    ratio = passed_checks / length(consistency_checks)
    %{
      total_checks: length(consistency_checks),
      passed_checks: passed_checks,
      consistency_ratio: ratio,
      status: if(ratio >= 0.8, do: :consistent, else: :inconsistent)
    }
  end

  defp check_value_validity(profile) do
    validity_checks = %{
      employee_count: validate_employee_count(Map.get(profile, "total_employees")),
      turnover: validate_turnover(Map.get(profile, "annual_turnover")),
      regions: validate_regions(Map.get(profile, "operational_regions")),
      sic_code: validate_sic_code(Map.get(profile, "primary_sic_code"))
    }
    
    valid_count = Enum.count(validity_checks, fn {_field, valid} -> valid end)
    
    %{
      validity_checks: validity_checks,
      valid_fields: valid_count,
      total_checked: map_size(validity_checks),
      validity_ratio: valid_count / map_size(validity_checks)
    }
  end

  defp check_logical_coherence(profile) do
    # Check if the profile makes logical sense as a whole
    coherence_issues = []
    
    # Check if large employee count matches with small turnover (potential issue)
    coherence_issues = check_size_coherence(profile, coherence_issues)
    
    # Check if operational regions make sense with headquarters
    coherence_issues = check_geographic_coherence(profile, coherence_issues)
    
    %{
      coherence_issues: coherence_issues,
      issue_count: length(coherence_issues),
      coherence_status: if(length(coherence_issues) == 0, do: :coherent, else: :needs_review)
    }
  end

  defp evaluate_basic_readiness(profile) do
    required_fields = ["organization_name", "organization_type", "headquarters_region", "industry_sector"]
    completeness = calculate_field_completeness(profile, required_fields)
    
    %{
      ready: completeness >= 0.75,
      completeness_score: completeness,
      missing_fields: identify_missing_fields(profile, required_fields),
      confidence_level: if(completeness >= 0.75, do: :high, else: :low)
    }
  end

  defp evaluate_enhanced_readiness(profile) do
    required_basic = ["organization_name", "organization_type", "headquarters_region", "industry_sector"]
    enhanced_fields = ["total_employees", "operational_regions", "business_activities"]
    
    basic_completeness = calculate_field_completeness(profile, required_basic)
    enhanced_completeness = calculate_field_completeness(profile, enhanced_fields)
    
    overall_readiness = (basic_completeness * 0.6) + (enhanced_completeness * 0.4)
    
    %{
      ready: overall_readiness >= 0.6 && basic_completeness >= 0.75,
      overall_readiness: overall_readiness,
      basic_completeness: basic_completeness,
      enhanced_completeness: enhanced_completeness,
      confidence_level: determine_confidence_level(overall_readiness)
    }
  end

  defp evaluate_comprehensive_readiness(profile) do
    all_categories = %{
      basic: calculate_basic_identification_score(profile),
      operational: calculate_operational_details_score(profile),
      compliance: calculate_compliance_context_score(profile),
      risk: calculate_risk_assessment_score(profile)
    }
    
    minimum_thresholds = %{basic: 0.9, operational: 0.7, compliance: 0.5, risk: 0.3}
    
    meets_thresholds = Enum.all?(all_categories, fn {category, score} ->
      score >= minimum_thresholds[category]
    end)
    
    overall_score = all_categories
    |> Map.values()
    |> Enum.sum()
    |> Kernel./(map_size(all_categories))
    
    %{
      ready: meets_thresholds && overall_score >= 0.7,
      overall_score: overall_score,
      category_scores: all_categories,
      threshold_compliance: meets_thresholds,
      confidence_level: determine_confidence_level(overall_score)
    }
  end

  defp recommend_screening_level(profile) do
    basic_ready = evaluate_basic_readiness(profile)
    enhanced_ready = evaluate_enhanced_readiness(profile)
    comprehensive_ready = evaluate_comprehensive_readiness(profile)
    
    cond do
      comprehensive_ready.ready -> :comprehensive
      enhanced_ready.ready -> :enhanced
      basic_ready.ready -> :basic
      true -> :insufficient_data
    end
  end

  # Helper functions for field definitions and validation

  defp get_basic_fields do
    ["organization_name", "organization_type", "headquarters_region", "industry_sector"]
  end

  defp get_enhanced_fields do
    ["total_employees", "annual_turnover", "operational_regions", "business_activities", "primary_sic_code"]
  end

  defp get_optional_fields do
    ["registration_number", "compliance_requirements", "risk_profile", "special_circumstances"]
  end

  defp identify_missing_fields(profile, fields) do
    Enum.reject(fields, &field_has_meaningful_value?(profile, &1))
  end

  defp validate_employee_count(nil), do: true  # Missing is valid
  defp validate_employee_count(count) when is_integer(count) and count >= 0, do: true
  defp validate_employee_count(_), do: false

  defp validate_turnover(nil), do: true  # Missing is valid
  defp validate_turnover(turnover) when is_number(turnover) and turnover >= 0, do: true
  defp validate_turnover(_), do: false

  defp validate_regions(nil), do: true  # Missing is valid
  defp validate_regions(regions) when is_list(regions), do: length(regions) > 0
  defp validate_regions(_), do: false

  defp validate_sic_code(nil), do: true  # Missing is valid
  defp validate_sic_code(code) when is_binary(code), do: String.length(code) >= 4
  defp validate_sic_code(_), do: false

  defp check_employee_turnover_consistency(profile) do
    employees = Map.get(profile, "total_employees")
    turnover = Map.get(profile, "annual_turnover")
    
    case {employees, turnover} do
      {emp, turn} when is_integer(emp) and is_number(turn) ->
        # Very rough consistency check: turnover per employee shouldn't be extremely high or low
        turnover_per_employee = turn / emp
        turnover_per_employee > 5_000 && turnover_per_employee < 500_000
      _ -> true  # Can't check if data missing
    end
  end

  defp check_region_activity_consistency(profile) do
    # For now, assume consistency - more sophisticated checks can be added
    true
  end

  defp check_size_classification_consistency(profile) do
    employees = Map.get(profile, "total_employees")
    turnover = Map.get(profile, "annual_turnover")
    
    case {employees, turnover} do
      {emp, turn} when is_integer(emp) and is_number(turn) ->
        # Check if employee count and turnover suggest similar company size
        emp_category = categorize_by_employees(emp)
        turnover_category = categorize_by_turnover(turn)
        
        # Allow for one category difference (not exact science)
        abs(emp_category - turnover_category) <= 1
      _ -> true  # Can't check if data missing
    end
  end

  defp check_size_coherence(profile, issues) do
    case check_size_classification_consistency(profile) do
      false -> ["Employee count and turnover suggest different company sizes" | issues]
      true -> issues
    end
  end

  defp check_geographic_coherence(profile, issues) do
    headquarters = Map.get(profile, "headquarters_region")
    operational = Map.get(profile, "operational_regions")
    
    case {headquarters, operational} do
      {hq, ops} when is_binary(hq) and is_list(ops) ->
        if hq in ops do
          issues
        else
          ["Headquarters region not included in operational regions" | issues]
        end
      _ -> issues
    end
  end

  defp categorize_by_employees(emp) when emp < 10, do: 1
  defp categorize_by_employees(emp) when emp < 50, do: 2
  defp categorize_by_employees(emp) when emp < 250, do: 3
  defp categorize_by_employees(emp) when emp < 1000, do: 4
  defp categorize_by_employees(_), do: 5

  defp categorize_by_turnover(turn) when turn < 100_000, do: 1
  defp categorize_by_turnover(turn) when turn < 1_000_000, do: 2
  defp categorize_by_turnover(turn) when turn < 10_000_000, do: 3
  defp categorize_by_turnover(turn) when turn < 50_000_000, do: 4
  defp categorize_by_turnover(_), do: 5

  defp determine_confidence_level(score) when score >= 0.8, do: :high
  defp determine_confidence_level(score) when score >= 0.6, do: :medium
  defp determine_confidence_level(_), do: :low

  defp calculate_overall_quality(quality_checks) do
    scores = [
      quality_checks.field_completeness.completeness_ratio,
      quality_checks.data_consistency.consistency_ratio,
      quality_checks.value_validity.validity_ratio,
      (if quality_checks.logical_coherence.coherence_status == :coherent, do: 1.0, else: 0.5)
    ]
    
    Enum.sum(scores) / length(scores)
  end

  defp identify_quality_issues(quality_checks) do
    issues = []
    
    if quality_checks.field_completeness.status == :needs_improvement do
      issues = ["Incomplete profile data" | issues]
    end
    
    if quality_checks.data_consistency.status == :inconsistent do
      issues = ["Data consistency issues detected" | issues]
    end
    
    if quality_checks.value_validity.validity_ratio < 0.8 do
      issues = ["Invalid data values found" | issues]
    end
    
    if quality_checks.logical_coherence.coherence_status == :needs_review do
      issues = issues ++ quality_checks.logical_coherence.coherence_issues
    end
    
    issues
  end

  defp generate_improvement_suggestions(issues) do
    Enum.map(issues, &suggest_improvement_for_issue/1)
  end

  defp suggest_improvement_for_issue("Incomplete profile data") do
    "Complete missing required fields to improve screening accuracy"
  end
  defp suggest_improvement_for_issue("Data consistency issues detected") do
    "Review profile data for inconsistencies between related fields"
  end
  defp suggest_improvement_for_issue("Invalid data values found") do
    "Validate and correct invalid data entries"
  end
  defp suggest_improvement_for_issue(issue) do
    "Review and address: #{issue}"
  end

  defp calculate_data_confidence(quality_checks) do
    confidence_factors = [
      quality_checks.field_completeness.completeness_ratio * 0.3,
      quality_checks.data_consistency.consistency_ratio * 0.3,
      quality_checks.value_validity.validity_ratio * 0.3,
      (if quality_checks.logical_coherence.coherence_status == :coherent, do: 0.1, else: 0.0)
    ]
    
    Enum.sum(confidence_factors)
  end

  defp identify_priority_improvements(analysis) do
    # Identify the most impactful improvements based on analysis
    []  # TODO: Implement priority improvement identification
  end

  defp identify_quick_wins(profile) do
    # Identify easy-to-complete fields that would improve screening
    []  # TODO: Implement quick wins identification
  end

  defp identify_compliance_focus_areas(profile) do
    # Identify key compliance areas based on sector and activities
    []  # TODO: Implement compliance focus area identification
  end

  defp suggest_data_collection_strategy(analysis) do
    # Suggest strategy for collecting missing data
    %{}  # TODO: Implement data collection strategy
  end

  defp suggest_screening_optimization(analysis) do
    # Suggest ways to optimize screening based on current profile
    %{}  # TODO: Implement screening optimization suggestions
  end

  defp identify_sector_compliance_areas(profile) do
    # Identify compliance areas specific to the organization's sector
    []  # TODO: Implement sector-specific compliance identification
  end

  defp identify_geographic_requirements(profile) do
    # Identify requirements based on geographic presence
    []  # TODO: Implement geographic requirements identification
  end

  defp identify_size_based_obligations(profile) do
    # Identify obligations based on organization size
    []  # TODO: Implement size-based obligations identification
  end

  defp identify_activity_specific_rules(profile) do
    # Identify rules specific to business activities
    []  # TODO: Implement activity-specific rules identification
  end

  defp identify_risk_based_priorities(profile) do
    # Identify priorities based on risk profile
    []  # TODO: Implement risk-based priority identification
  end

  defp identify_risk_indicators(profile) do
    # Identify potential risk indicators in the profile
    indicators = []
    
    # High employee count without proper compliance framework
    if Map.get(profile, "total_employees", 0) > 250 && 
       (!Map.has_key?(profile, "compliance_requirements") || Map.get(profile, "compliance_requirements") == []) do
      indicators = ["Large workforce without documented compliance requirements" | indicators]
    end
    
    # High turnover without clear industry classification
    if Map.get(profile, "annual_turnover", 0) > 10_000_000 && 
       (!Map.has_key?(profile, "industry_sector") || Map.get(profile, "industry_sector") == "") do
      indicators = ["High turnover without clear industry classification" | indicators]
    end
    
    # Multi-regional operations without documented operational regions
    if Map.get(profile, "headquarters_region") != nil &&
       (!Map.has_key?(profile, "operational_regions") || length(Map.get(profile, "operational_regions", [])) < 2) do
      indicators = ["Potential multi-regional operations not documented" | indicators]
    end
    
    indicators
  end

  defp generate_recommendations(profile) do
    recommendations = []
    
    # Basic field completion recommendations
    missing_basic = identify_missing_fields(profile, get_basic_fields())
    if length(missing_basic) > 0 do
      recommendations = ["Complete missing basic fields: #{Enum.join(missing_basic, ", ")}" | recommendations]
    end
    
    # Enhanced field completion recommendations
    missing_enhanced = identify_missing_fields(profile, get_enhanced_fields())
    if length(missing_enhanced) > 0 && length(missing_basic) == 0 do
      recommendations = ["Add enhanced profile details: #{Enum.join(missing_enhanced, ", ")}" | recommendations]
    end
    
    # Data quality improvements
    if !validate_employee_count(Map.get(profile, "total_employees")) do
      recommendations = ["Verify and correct employee count data" | recommendations]
    end
    
    if !validate_turnover(Map.get(profile, "annual_turnover")) do
      recommendations = ["Verify and correct annual turnover data" | recommendations]
    end
    
    recommendations
  end
end