defmodule Sertantai.Organizations.ApplicabilityMatcher do
  @moduledoc """
  Phase 2 enhanced applicability matching service.
  Provides high-performance organization-to-regulation matching using function-optimized queries
  and Elixir-native caching for duty-creating laws only ('Making' function).
  """
  
  alias Sertantai.UkLrt
  alias Sertantai.Cache.ApplicabilityCache
  alias Sertantai.Query.ProgressiveQueryBuilder
  alias Sertantai.Query.ResultStreamer
  alias Sertantai.Organizations.ProfileAnalyzer

  @doc """
  Returns the count of potentially applicable laws for an organization.
  Phase 2: Uses function-optimized queries filtering to 'Making' function only.
  Performance-optimized with caching through ApplicabilityCache.
  """
  def basic_applicability_count(organization) do
    # Use cached count with function-optimized query
    ApplicabilityCache.get_law_count(organization)
  end

  @doc """
  Direct database query for count (used by cache on miss).
  Filters to 'Making' function laws only for massive performance improvement.
  """
  def direct_count_query(organization) do
    family = map_sector_to_family(get_industry_sector(organization))
    geo_extent = get_applicable_geo_extent(organization)
    
    case UkLrt.count_for_screening(family, geo_extent, "✔ In force") do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end

  @doc """
  Returns a preview of applicable laws with details for display.
  Phase 2: Uses function-optimized Ash actions with caching.
  """
  def basic_applicability_preview(organization, limit \\ 10) do
    family = map_sector_to_family(get_industry_sector(organization))
    geo_extent = get_applicable_geo_extent(organization)
    
    case UkLrt.for_applicability_screening(family, geo_extent, "✔ In force", limit) do
      {:ok, results} -> results
      {:error, _} -> []
    end
  end

  @doc """
  Performs complete enhanced screening and returns structured results.
  Phase 2: Uses cached data and function-optimized queries.
  """
  def perform_basic_screening(organization) do
    # Use cached screening results
    ApplicabilityCache.get_screening_results(organization)
  end

  @doc """
  Performs progressive screening with adaptive complexity based on organization profile.
  Phase 2: Uses Progressive Query Builder for optimized performance and accuracy.
  """
  def perform_progressive_screening(organization, opts \\ []) do
    # Use progressive query builder for adaptive screening
    ProgressiveQueryBuilder.execute_progressive_screening(organization, opts)
  end

  @doc """
  Analyzes organization profile and returns query complexity recommendations.
  """
  def analyze_query_complexity(organization) do
    ProgressiveQueryBuilder.calculate_query_complexity_score(organization)
  end

  @doc """
  Builds optimized query strategy based on organization profile completeness.
  """
  def build_query_strategy(organization) do
    ProgressiveQueryBuilder.build_query_strategy(organization)
  end

  @doc """
  Starts progressive result streaming for real-time applicability updates.
  """
  def start_progressive_stream(organization, subscriber_pid, opts \\ []) do
    ResultStreamer.start_progressive_stream(organization, subscriber_pid, opts)
  end

  @doc """
  Handles organization profile updates and triggers re-screening if needed.
  """
  def handle_profile_update(organization, changed_fields) do
    ResultStreamer.handle_profile_update(organization, changed_fields)
  end

  @doc """
  Performs comprehensive organization profile analysis for screening optimization.
  """
  def analyze_organization_profile(organization) do
    ProfileAnalyzer.analyze_organization_profile(organization)
  end

  @doc """
  Calculates enhanced profile completeness with weighted categories.
  """
  def calculate_enhanced_completeness(organization) do
    profile = get_organization_profile(organization)
    ProfileAnalyzer.calculate_enhanced_completeness(profile)
  end

  @doc """
  Generates intelligent recommendations for profile improvement.
  """
  def generate_profile_recommendations(organization) do
    ProfileAnalyzer.generate_profile_recommendations(organization)
  end

  @doc """
  Direct database query for screening (used by cache on miss).
  Phase 2: Filters to 'Making' function laws only.
  """
  def direct_screening_query(organization) do
    count = direct_count_query(organization)
    preview = basic_applicability_preview(organization, 5)
    
    %{
      applicable_law_count: count,
      sample_regulations: preview,
      screening_method: "phase2_function_optimized",
      organization_profile: extract_matching_attributes(organization),
      generated_at: DateTime.utc_now(),
      confidence_level: "enhanced",
      function_filter: "Making laws only (duty-creating)"
    }
  end

  # Phase 2 Helper Functions

  @doc """
  Get the primary geographic extent for an organization.
  Phase 2: Simplified geographic matching for function-optimized queries.
  """
  def get_applicable_geo_extent(organization) do
    case get_headquarters_region(organization) do
      "england" -> "England"
      "wales" -> "Wales"
      "scotland" -> "Scotland"
      "northern_ireland" -> "Northern Ireland"
      "great_britain" -> "Great Britain"
      "united_kingdom" -> "United Kingdom"
      _ -> "United Kingdom"  # Default fallback
    end
  end

  # Organization attribute extraction helpers (public for cache usage)

  def get_industry_sector(organization) do
    get_core_profile_field(organization, "industry_sector")
  end

  def get_headquarters_region(organization) do
    get_core_profile_field(organization, "headquarters_region")
  end

  def get_total_employees(organization) do
    get_core_profile_field(organization, "total_employees")
  end

  defp get_core_profile_field(organization, field) do
    case organization do
      %{core_profile: profile} when is_map(profile) -> Map.get(profile, field)
      %{"core_profile" => profile} when is_map(profile) -> Map.get(profile, field)
      _ -> nil
    end
  end

  defp get_organization_profile(organization) do
    case organization do
      %{core_profile: profile} when is_map(profile) -> profile
      %{"core_profile" => profile} when is_map(profile) -> profile
      _ -> %{}
    end
  end

  defp extract_matching_attributes(organization) do
    %{
      industry_sector: get_industry_sector(organization),
      headquarters_region: get_headquarters_region(organization),
      total_employees: get_total_employees(organization),
      mapped_family: map_sector_to_family(get_industry_sector(organization)),
      applicable_extents: map_region_to_extents(get_headquarters_region(organization))
    }
  end

  # Phase 1 Simple Mapping Functions
  # Maps industry sectors to UK LRT family classifications

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

  # Maps UK regions to applicable geographic extents in UK LRT
  defp map_region_to_extents("england") do
    ["England", "England and Wales", "Great Britain", "United Kingdom"]
  end
  
  defp map_region_to_extents("wales") do
    ["Wales", "England and Wales", "Great Britain", "United Kingdom"] 
  end
  
  defp map_region_to_extents("scotland") do
    ["Scotland", "Great Britain", "United Kingdom"]
  end
  
  defp map_region_to_extents("northern_ireland") do
    ["Northern Ireland", "United Kingdom"]
  end
  
  defp map_region_to_extents("great_britain") do
    ["Great Britain", "United Kingdom"]
  end
  
  defp map_region_to_extents("united_kingdom") do
    ["United Kingdom"]
  end
  
  defp map_region_to_extents(_) do
    ["United Kingdom"]  # Default to UK-wide if region unknown
  end

  @doc """
  Returns available industry sectors for form dropdowns.
  """
  def get_supported_industry_sectors do
    [
      {"Agriculture", "agriculture"},
      {"Chemicals", "chemicals"},
      {"Construction", "construction"},
      {"Education", "education"},
      {"Energy", "energy"},
      {"Environment", "environment"},
      {"Fire Safety", "fire_safety"},
      {"Food", "food"},
      {"Healthcare", "healthcare"},
      {"Manufacturing", "manufacturing"},
      {"Mining", "mining"},
      {"Nuclear", "nuclear"},
      {"Telecommunications", "telecommunications"},
      {"Transport", "transport"},
      {"Waste", "waste"},
      {"Water", "water"}
    ]
  end

  @doc """
  Returns available UK regions for form dropdowns.
  """
  def get_supported_regions do
    [
      {"England", "england"},
      {"Wales", "wales"},
      {"Scotland", "scotland"},
      {"Northern Ireland", "northern_ireland"},
      {"Great Britain", "great_britain"},
      {"United Kingdom", "united_kingdom"}
    ]
  end

  @doc """
  Returns organization types for form dropdowns.
  """
  def get_organization_types do
    [
      {"Limited Company", "limited_company"},
      {"Public Limited Company", "public_limited_company"},
      {"Partnership", "partnership"},
      {"Limited Liability Partnership", "limited_liability_partnership"},
      {"Sole Trader", "sole_trader"},
      {"Charity", "charity"},
      {"Community Interest Company", "community_interest_company"},
      {"Public Sector Organization", "public_sector_organization"},
      {"Local Authority", "local_authority"},
      {"NHS Trust", "nhs_trust"},
      {"Educational Institution", "educational_institution"},
      {"Housing Association", "housing_association"},
      {"Cooperative", "cooperative"},
      {"Trade Union", "trade_union"}
    ]
  end
end