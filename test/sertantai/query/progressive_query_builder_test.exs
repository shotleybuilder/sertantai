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

    test "builds optimized strategy for high-complexity organizations" do
      organization = %{
        core_profile: %{
          "organization_name" => "Complex Corp",
          "organization_type" => "public_limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction",
          "total_employees" => 500,
          "annual_turnover" => 50_000_000,
          "operational_regions" => ["england", "wales", "scotland"],
          "business_activities" => ["construction", "engineering", "consulting"]
        }
      }

      strategy = ProgressiveQueryBuilder.build_query_strategy(organization)

      assert strategy.complexity_level == :comprehensive
      assert strategy.cache_ttl >= 3600  # Higher TTL for complex queries
      assert Map.has_key?(strategy.query_params, :employee_range)
      assert Map.has_key?(strategy.query_params, :annual_turnover_range)
    end

    test "builds fallback strategy for incomplete profiles" do
      organization = %{
        core_profile: %{
          "organization_name" => "Incomplete Corp"
        }
      }

      strategy = ProgressiveQueryBuilder.build_query_strategy(organization)

      assert strategy.complexity_level == :basic
      assert Map.has_key?(strategy, :fallback_strategy)
      # Check that fallback strategy is set appropriately
      assert is_atom(strategy.fallback_strategy) || is_map(strategy.fallback_strategy)
    end
  end

  describe "performance optimization" do
    test "function filtering optimization reduces query scope" do
      organization = %{
        core_profile: %{
          "organization_name" => "Function Test Corp",
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }

      results = ProgressiveQueryBuilder.execute_progressive_screening(organization)
      
      # Should have query optimization applied
      assert results.performance_metadata.query_optimization_applied == true
      # Execution time should be reasonable (< 2s as per plan)
      assert results.performance_metadata.execution_time_ms < 2000
    end

    test "cache efficiency varies with profile complexity" do
      basic_org = %{
        core_profile: %{
          "organization_name" => "Basic Org",
          "organization_type" => "limited_company"
        }
      }

      enhanced_org = %{
        core_profile: %{
          "organization_name" => "Enhanced Org", 
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction",
          "total_employees" => 100
        }
      }

      basic_strategy = ProgressiveQueryBuilder.build_query_strategy(basic_org)
      enhanced_strategy = ProgressiveQueryBuilder.build_query_strategy(enhanced_org)

      # Both should have reasonable cache TTL values
      assert basic_strategy.cache_ttl > 0
      assert enhanced_strategy.cache_ttl > 0
      # Enhanced queries might have different caching strategies
      assert basic_strategy.complexity_level != enhanced_strategy.complexity_level
    end
  end

  describe "error handling and resilience" do
    test "handles missing or invalid data gracefully" do
      invalid_organization = %{
        core_profile: %{
          "organization_name" => "",
          "organization_type" => "invalid_type",
          "total_employees" => -1
        }
      }

      results = ProgressiveQueryBuilder.execute_progressive_screening(invalid_organization)

      # Should return results without crashing
      assert is_map(results)
      assert Map.has_key?(results, :applicable_law_count)
      # Should use some form of progressive screening method
      assert String.contains?(results.screening_method, "progressive")
    end

    test "handles database timeout scenarios" do
      # Simulate organization that might cause slow queries
      complex_org = %{
        core_profile: %{
          "organization_name" => "Complex Timeout Test",
          "organization_type" => "public_limited_company",
          "headquarters_region" => "england", 
          "industry_sector" => "multiple_sectors",
          "total_employees" => 10000,
          "operational_regions" => ["england", "wales", "scotland", "northern_ireland"]
        }
      }

      # Should complete within reasonable time even for complex queries
      start_time = System.monotonic_time(:millisecond)
      results = ProgressiveQueryBuilder.execute_progressive_screening(complex_org)
      execution_time = System.monotonic_time(:millisecond) - start_time

      assert is_map(results)
      assert execution_time < 5000  # Should complete within 5 seconds
    end
  end

  describe "query result validation" do
    test "ensures result structure consistency" do
      organization = %{
        core_profile: %{
          "organization_name" => "Validation Test Corp",
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }

      results = ProgressiveQueryBuilder.execute_progressive_screening(organization)

      # Validate required fields
      required_fields = [:applicable_law_count, :sample_regulations, :performance_metadata, 
                        :screening_method, :confidence_level]
      
      for field <- required_fields do
        assert Map.has_key?(results, field), "Missing required field: #{field}"
      end

      # Validate data types
      assert is_integer(results.applicable_law_count)
      assert is_list(results.sample_regulations)
      assert is_map(results.performance_metadata)
      assert is_binary(results.screening_method)
      assert results.confidence_level in ["basic", "enhanced", "high"]
    end

    test "validates sample regulations structure" do
      organization = %{
        core_profile: %{
          "organization_name" => "Sample Test Corp",
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }

      results = ProgressiveQueryBuilder.execute_progressive_screening(organization)

      if length(results.sample_regulations) > 0 do
        sample = List.first(results.sample_regulations)
        
        # Each sample regulation should have expected fields
        assert Map.has_key?(sample, :id) || Map.has_key?(sample, :name)
        assert Map.has_key?(sample, :family) || Map.has_key?(sample, :title_en)
      end
    end
  end
end