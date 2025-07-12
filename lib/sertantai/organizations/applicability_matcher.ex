defmodule Sertantai.Organizations.ApplicabilityMatcher do
  @moduledoc """
  Phase 1 basic applicability matching service.
  Provides simple organization-to-regulation matching based on core profile attributes.
  """
  
  import Ecto.Query
  alias Sertantai.Repo
  alias Sertantai.UkLrt

  @doc """
  Returns the count of potentially applicable laws for an organization.
  Uses basic matching on sector and geographic scope.
  """
  def basic_applicability_count(organization) do
    organization
    |> build_basic_query()
    |> count_matching_regulations()
  end

  @doc """
  Returns a preview of applicable laws with details for display.
  Limited to specified number of results for performance.
  """
  def basic_applicability_preview(organization, limit \\ 10) do
    organization
    |> build_basic_query()
    |> limit_results(limit)
    |> execute_query()
  end

  @doc """
  Performs complete basic screening and returns structured results.
  """
  def perform_basic_screening(organization) do
    count = basic_applicability_count(organization)
    preview = basic_applicability_preview(organization, 5)
    
    %{
      applicable_law_count: count,
      sample_regulations: preview,
      screening_method: "phase1_basic",
      organization_profile: extract_matching_attributes(organization),
      generated_at: DateTime.utc_now(),
      confidence_level: "basic"
    }
  end

  # Private helper functions

  defp build_basic_query(organization) do
    from(u in UkLrt, as: :uk_lrt)
    |> where([uk_lrt: u], u.live == "✔ In force")
    |> add_sector_filter(organization)
    |> add_geographic_filter(organization)
    |> add_size_filter(organization)
    |> order_by([uk_lrt: u], [desc: u.year, desc: u.latest_amend_date])
  end

  defp add_sector_filter(query, organization) do
    case get_industry_sector(organization) do
      nil -> query
      sector -> 
        family_value = map_sector_to_family(sector)
        if family_value do
          where(query, [uk_lrt: u], u.family == ^family_value)
        else
          query
        end
    end
  end

  defp add_geographic_filter(query, organization) do
    case get_headquarters_region(organization) do
      nil -> query
      region -> 
        applicable_extents = map_region_to_extents(region)
        where(query, [uk_lrt: u], u.geo_extent in ^applicable_extents)
    end
  end

  defp add_size_filter(query, organization) do
    case get_total_employees(organization) do
      nil -> query
      employee_count when is_integer(employee_count) ->
        # Add size-based filtering logic here
        # For Phase 1, we'll keep it simple and not filter by size
        query
      _ -> query
    end
  end

  defp count_matching_regulations(query) do
    # Remove ORDER BY for count queries as PostgreSQL doesn't allow it
    query
    |> exclude(:order_by)
    |> select([uk_lrt: u], count(u.id))
    |> Repo.one()
    |> case do
      nil -> 0
      count -> count
    end
  end

  defp limit_results(query, limit) do
    limit(query, ^limit)
  end

  defp execute_query(query) do
    query
    |> select([uk_lrt: u], %{
      id: u.id,
      name: u.name,
      title_en: u.title_en,
      family: u.family,
      geo_extent: u.geo_extent,
      live: u.live,
      year: u.year,
      md_description: u.md_description
    })
    |> Repo.all()
  end

  # Organization attribute extraction helpers

  defp get_industry_sector(organization) do
    get_core_profile_field(organization, "industry_sector")
  end

  defp get_headquarters_region(organization) do
    get_core_profile_field(organization, "headquarters_region")
  end

  defp get_total_employees(organization) do
    get_core_profile_field(organization, "total_employees")
  end

  defp get_core_profile_field(organization, field) do
    case organization do
      %{core_profile: profile} when is_map(profile) -> Map.get(profile, field)
      %{"core_profile" => profile} when is_map(profile) -> Map.get(profile, field)
      _ -> nil
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