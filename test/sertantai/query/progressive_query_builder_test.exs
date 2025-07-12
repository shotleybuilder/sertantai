defmodule Sertantai.Query.ProgressiveQueryBuilderTest do
  use ExUnit.Case
  alias Sertantai.Query.ProgressiveQueryBuilder

  describe "progressive query complexity scoring" do
    test "calculates query complexity for basic organization" do
      organization = %{
        core_profile: %{
          "organization_name" => "Test Corp",
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }

      score = ProgressiveQueryBuilder.calculate_query_complexity_score(organization)

      assert is_map(score)
      assert Map.has_key?(score, :total_score)
      assert Map.has_key?(score, :recommended_complexity)
      assert score.total_score >= 0.0 && score.total_score <= 1.0
      assert score.recommended_complexity in [:basic, :enhanced, :comprehensive]
    end

    test "calculates query complexity for enhanced organization" do
      organization = %{
        core_profile: %{
          "organization_name" => "Enhanced Corp",
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction",
          "total_employees" => 100,
          "annual_turnover" => 5_000_000,
          "operational_regions" => ["england", "wales"],
          "business_activities" => ["construction", "engineering"]
        }
      }

      score = ProgressiveQueryBuilder.calculate_query_complexity_score(organization)

      assert score.total_score > 0.5
      assert score.recommended_complexity in [:enhanced, :comprehensive]
    end
  end

  describe "progressive screening execution" do
    test "executes progressive screening for basic organization" do
      organization = %{
        core_profile: %{
          "organization_name" => "Basic Corp",
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }

      results = ProgressiveQueryBuilder.execute_progressive_screening(organization)

      assert is_map(results)
      assert Map.has_key?(results, :applicable_law_count)
      assert Map.has_key?(results, :sample_regulations)
      assert Map.has_key?(results, :performance_metadata)
      assert Map.has_key?(results, :screening_method)
      
      # Should be progressive method
      assert String.contains?(results.screening_method, "progressive")
      
      # Should have performance metadata
      metadata = results.performance_metadata
      assert Map.has_key?(metadata, :execution_time_ms)
      assert Map.has_key?(metadata, :complexity_level)
      assert is_integer(metadata.execution_time_ms)
    end
  end

  describe "query strategy building" do
    test "builds appropriate strategy for organization profile" do
      organization = %{
        core_profile: %{
          "organization_name" => "Strategy Corp",
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction",
          "total_employees" => 50
        }
      }

      strategy = ProgressiveQueryBuilder.build_query_strategy(organization)

      assert is_map(strategy)
      assert Map.has_key?(strategy, :complexity_level)
      assert Map.has_key?(strategy, :query_params)
      assert Map.has_key?(strategy, :performance_estimate)
      assert Map.has_key?(strategy, :fallback_strategy)
      assert Map.has_key?(strategy, :cache_ttl)

      # Complexity level should be valid
      assert strategy.complexity_level in [:basic, :enhanced, :comprehensive]
      
      # Query params should contain basic parameters
      assert Map.has_key?(strategy.query_params, :family)
      assert Map.has_key?(strategy.query_params, :geo_extent)
      assert Map.has_key?(strategy.query_params, :live_status)
    end
  end
end