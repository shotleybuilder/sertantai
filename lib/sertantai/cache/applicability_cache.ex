defmodule Sertantai.Cache.ApplicabilityCache do
  @moduledoc """
  High-performance Elixir-native caching for Phase 2 applicability screening results.
  
  Uses Cachex for TTL management and automatic fallback to database queries.
  Optimized for function-filtered 'Making' law subset with intelligent cache keys.
  """
  
  alias Sertantai.Organizations.ApplicabilityMatcher
  
  @cache_name :applicability_cache
  
  @doc """
  Get cached law count for an organization profile with automatic fallback.
  Uses function-optimized queries that filter to 'Making' subset only.
  """
  def get_law_count(organization) do
    cache_key = generate_cache_key(organization, :count)
    
    case Cachex.fetch(@cache_name, cache_key, fn ->
           count = ApplicabilityMatcher.direct_count_query(organization)
           {:commit, count, ttl: cache_ttl_for_organization(organization)}
         end) do
      {:ok, count} -> count
      {:commit, count, _opts} -> count
      {:error, _reason} -> 
        # Fallback to direct database query if cache fails
        ApplicabilityMatcher.direct_count_query(organization)
    end
  end
  
  @doc """
  Get cached screening results for an organization with automatic fallback.
  Includes law count, sample regulations, and metadata.
  """
  def get_screening_results(organization) do
    cache_key = generate_cache_key(organization, :screening)
    
    case Cachex.fetch(@cache_name, cache_key, fn ->
           results = ApplicabilityMatcher.direct_screening_query(organization)
           {:commit, results, ttl: cache_ttl_for_screening(organization)}
         end) do
      {:ok, results} -> results
      {:commit, results, _opts} -> results
      {:error, _reason} ->
        # Fallback to direct screening if cache fails
        ApplicabilityMatcher.direct_screening_query(organization)
    end
  end
  
  @doc """
  Invalidate cache entries for a specific organization.
  Called when organization profile is updated.
  """
  def invalidate_organization_cache(organization) do
    base_key = generate_base_cache_key(organization)
    
    # Remove both count and screening cache entries
    Cachex.del(@cache_name, "#{base_key}:count")
    Cachex.del(@cache_name, "#{base_key}:screening")
    
    # Broadcast cache invalidation to LiveViews
    Phoenix.PubSub.broadcast(
      Sertantai.PubSub,
      "org:#{organization.id}",
      {:cache_invalidated, :applicability_data}
    )
  end
  
  @doc """
  Get cache statistics for monitoring and performance tuning.
  """
  def get_cache_stats do
    case Cachex.stats(@cache_name) do
      {:ok, stats} -> stats
      {:error, _reason} -> %{error: "Unable to retrieve cache stats"}
    end
  end
  
  @doc """
  Warm cache with common organization profiles.
  Useful for pre-populating frequently accessed patterns.
  """
  def warm_cache(organizations) when is_list(organizations) do
    Task.async_stream(organizations, fn org ->
      get_law_count(org)
      get_screening_results(org)
    end, max_concurrency: 10, timeout: 30_000)
    |> Stream.run()
  end
  
  # Private helper functions
  
  defp generate_cache_key(organization, type) do
    base_key = generate_base_cache_key(organization)
    "#{base_key}:#{type}"
  end
  
  defp generate_base_cache_key(organization) do
    # Create stable hash from organization profile for cache key
    profile_hash = %{
      sector: ApplicabilityMatcher.get_industry_sector(organization),
      region: ApplicabilityMatcher.get_headquarters_region(organization),
      size: ApplicabilityMatcher.get_total_employees(organization),
      # Phase 2 enhancement: include additional profile elements
      operational_regions: get_operational_regions(organization),
      annual_turnover: get_annual_turnover(organization),
      business_activities: get_business_activities(organization)
    }
    |> :erlang.phash2()
    
    "org_profile:#{profile_hash}"
  end
  
  defp cache_ttl_for_organization(organization) do
    # Longer TTL for more established organizations (they change profiles less frequently)
    case ApplicabilityMatcher.get_total_employees(organization) do
      n when is_integer(n) and n > 1000 -> :timer.hours(24)  # Large orgs
      n when is_integer(n) and n > 100 -> :timer.hours(8)    # Medium orgs
      n when is_integer(n) and n > 10 -> :timer.hours(4)     # Small orgs
      _ -> :timer.hours(2)                                    # Very small or unknown
    end
  end
  
  defp cache_ttl_for_screening(organization) do
    # Screening results can be cached longer than simple counts
    # as they include more comprehensive analysis
    base_ttl = cache_ttl_for_organization(organization)
    min(base_ttl * 2, :timer.hours(24))  # Max 24 hours for screening results
  end
  
  # Phase 2 organization profile extractors
  
  defp get_operational_regions(organization) do
    get_core_profile_field(organization, "operational_regions")
  end
  
  defp get_annual_turnover(organization) do
    get_core_profile_field(organization, "annual_turnover")
  end
  
  defp get_business_activities(organization) do
    get_core_profile_field(organization, "business_activities")
  end
  
  defp get_core_profile_field(organization, field) do
    case organization do
      %{core_profile: profile} when is_map(profile) -> Map.get(profile, field)
      %{"core_profile" => profile} when is_map(profile) -> Map.get(profile, field)
      _ -> nil
    end
  end
end