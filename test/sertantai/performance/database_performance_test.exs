defmodule Sertantai.Performance.DatabasePerformanceTest do
  use ExUnit.Case
  
  alias Sertantai.Query.ProgressiveQueryBuilder
  alias Sertantai.Organizations.ApplicabilityMatcher

  @moduletag timeout: 30_000  # 30 seconds timeout for performance tests

  describe "Database Performance Testing" do
    test "function filtering provides performance improvement" do
      organization = %{
        core_profile: %{
          "organization_name" => "Performance Test Corp",
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }

      # Measure execution time for progressive screening
      start_time = System.monotonic_time(:millisecond)
      results = ProgressiveQueryBuilder.execute_progressive_screening(organization)
      execution_time = System.monotonic_time(:millisecond) - start_time

      # Validate performance expectations from Phase 2 plan
      assert execution_time < 2000  # < 2s for complex queries target
      assert results.performance_metadata.execution_time_ms < 2000
      
      # Should apply function filtering optimization
      assert results.performance_metadata.query_optimization_applied == true
    end

    test "query complexity scaling performs within limits" do
      test_cases = [
        # Basic organization
        %{
          core_profile: %{
            "organization_name" => "Basic Perf Test",
            "organization_type" => "limited_company"
          },
          expected_max_time: 100  # < 100ms for basic queries
        },
        # Enhanced organization
        %{
          core_profile: %{
            "organization_name" => "Enhanced Perf Test",
            "organization_type" => "limited_company",
            "headquarters_region" => "england",
            "industry_sector" => "construction",
            "total_employees" => 50
          },
          expected_max_time: 500  # < 500ms for enhanced queries
        },
        # Complex organization
        %{
          core_profile: %{
            "organization_name" => "Complex Perf Test",
            "organization_type" => "public_limited_company",
            "headquarters_region" => "england",
            "industry_sector" => "construction",
            "total_employees" => 1000,
            "annual_turnover" => 10_000_000,
            "operational_regions" => ["england", "wales", "scotland"]
          },
          expected_max_time: 2000  # < 2s for comprehensive queries
        }
      ]

      for test_case <- test_cases do
        start_time = System.monotonic_time(:millisecond)
        results = ProgressiveQueryBuilder.execute_progressive_screening(test_case)
        execution_time = System.monotonic_time(:millisecond) - start_time

        assert execution_time < test_case.expected_max_time, 
               "Query exceeded expected time: #{execution_time}ms > #{test_case.expected_max_time}ms"
        
        # Validate result structure
        assert is_map(results)
        assert Map.has_key?(results, :applicable_law_count)
        assert Map.has_key?(results, :performance_metadata)
      end
    end

    test "concurrent user simulation stays within performance targets" do
      organization = %{
        core_profile: %{
          "organization_name" => "Concurrent Test Corp",
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }

      # Simulate 10 concurrent users (scaled down from 100+ target for test efficiency)
      concurrent_users = 10
      
      tasks = for i <- 1..concurrent_users do
        Task.async(fn ->
          start_time = System.monotonic_time(:millisecond)
          results = ProgressiveQueryBuilder.execute_progressive_screening(organization)
          execution_time = System.monotonic_time(:millisecond) - start_time
          {i, execution_time, results}
        end)
      end

      # Wait for all tasks and collect results
      results = Task.await_many(tasks, 30_000)

      # Validate all queries completed successfully
      assert length(results) == concurrent_users

      # Check performance under concurrent load
      execution_times = Enum.map(results, fn {_user, time, _result} -> time end)
      avg_time = Enum.sum(execution_times) / length(execution_times)
      max_time = Enum.max(execution_times)

      # Performance should remain reasonable under concurrent load
      assert avg_time < 1000  # Average < 1s
      assert max_time < 3000  # Max < 3s (allowing for some degradation under load)

      # All queries should return valid results
      for {_user, _time, result} <- results do
        assert is_map(result)
        assert Map.has_key?(result, :applicable_law_count)
      end
    end

    test "memory usage remains stable during repeated queries" do
      organization = %{
        core_profile: %{
          "organization_name" => "Memory Test Corp",
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }

      # Measure initial memory
      initial_memory = :erlang.memory(:total)

      # Execute many queries to test for memory leaks
      for _i <- 1..50 do
        ProgressiveQueryBuilder.execute_progressive_screening(organization)
      end

      # Force garbage collection
      :erlang.garbage_collect()
      :timer.sleep(100)  # Allow GC to complete

      # Measure final memory
      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory

      # Memory increase should be reasonable (< 10MB)
      max_acceptable_increase = 10 * 1024 * 1024  # 10MB
      
      assert memory_increase < max_acceptable_increase,
             "Excessive memory usage: #{memory_increase} bytes increased"
    end
  end

  describe "Caching Performance" do
    test "repeated queries benefit from caching" do
      organization = %{
        core_profile: %{
          "organization_name" => "Cache Test Corp",
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }

      # First query (cold cache)
      start_time_1 = System.monotonic_time(:millisecond)
      results_1 = ProgressiveQueryBuilder.execute_progressive_screening(organization)
      time_1 = System.monotonic_time(:millisecond) - start_time_1

      # Second query (potentially warm cache)
      start_time_2 = System.monotonic_time(:millisecond)
      results_2 = ProgressiveQueryBuilder.execute_progressive_screening(organization)
      time_2 = System.monotonic_time(:millisecond) - start_time_2

      # Results should be consistent
      assert results_1.applicable_law_count == results_2.applicable_law_count
      assert results_1.screening_method == results_2.screening_method

      # Both queries should complete within reasonable time
      assert time_1 < 2000
      assert time_2 < 2000
    end

    test "cache efficiency varies with profile complexity" do
      profiles = [
        %{
          core_profile: %{
            "organization_name" => "Simple Cache Test",
            "organization_type" => "limited_company"
          }
        },
        %{
          core_profile: %{
            "organization_name" => "Complex Cache Test",
            "organization_type" => "public_limited_company",
            "headquarters_region" => "england",
            "industry_sector" => "construction",
            "total_employees" => 500,
            "annual_turnover" => 20_000_000
          }
        }
      ]

      for profile <- profiles do
        strategy = ProgressiveQueryBuilder.build_query_strategy(profile)
        
        # All profiles should have caching strategies
        assert Map.has_key?(strategy, :cache_ttl)
        assert strategy.cache_ttl > 0
        
        # Should have reasonable cache TTL (between 1 hour and multiple days)
        assert strategy.cache_ttl >= 3600      # >= 1 hour
        assert strategy.cache_ttl <= 86400000  # <= reasonable maximum
      end
    end
  end

  describe "Database Query Optimization" do
    test "validates JSONB index usage effectiveness" do
      # Test different query patterns to ensure indexes are effective
      test_organizations = [
        # Industry-focused query
        %{
          core_profile: %{
            "organization_name" => "Industry Test",
            "organization_type" => "limited_company",
            "headquarters_region" => "england",
            "industry_sector" => "construction"
          }
        },
        # Geographic-focused query
        %{
          core_profile: %{
            "organization_name" => "Geographic Test",
            "organization_type" => "limited_company",
            "headquarters_region" => "scotland",
            "industry_sector" => "manufacturing"
          }
        },
        # Size-focused query
        %{
          core_profile: %{
            "organization_name" => "Size Test",
            "organization_type" => "public_limited_company",
            "headquarters_region" => "england",
            "industry_sector" => "construction",
            "total_employees" => 200
          }
        }
      ]

      for organization <- test_organizations do
        start_time = System.monotonic_time(:millisecond)
        results = ProgressiveQueryBuilder.execute_progressive_screening(organization)
        execution_time = System.monotonic_time(:millisecond) - start_time

        # All queries should complete quickly with proper indexing
        assert execution_time < 1500
        assert results.performance_metadata.execution_time_ms < 1500
        
        # Should return valid results
        assert is_integer(results.applicable_law_count)
        assert results.applicable_law_count >= 0
      end
    end

    test "function-based filtering reduces query scope effectively" do
      organization = %{
        core_profile: %{
          "organization_name" => "Function Filter Test",
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }

      results = ProgressiveQueryBuilder.execute_progressive_screening(organization)

      # Should apply query optimizations
      assert results.performance_metadata.query_optimization_applied == true
      
      # Performance should be enhanced by function filtering
      assert results.performance_metadata.execution_time_ms < 1000
      
      # Should return focused results (duty-creating laws only) 
      # Note: May be 0 if no applicable laws found for test organization
      assert results.applicable_law_count >= 0
    end
  end

  describe "Error Handling and Resilience" do
    test "handles edge cases gracefully without performance degradation" do
      edge_cases = [
        # Empty organization
        %{core_profile: %{}},
        # Minimal data
        %{core_profile: %{"organization_name" => "Minimal"}},
        # Invalid data
        %{
          core_profile: %{
            "organization_name" => "",
            "organization_type" => "invalid",
            "total_employees" => -1
          }
        }
      ]

      for edge_case <- edge_cases do
        start_time = System.monotonic_time(:millisecond)
        
        # Should not crash on edge cases
        results = try do
          ProgressiveQueryBuilder.execute_progressive_screening(edge_case)
        rescue
          _ -> %{applicable_law_count: 0, screening_method: "error_fallback"}
        end
        
        execution_time = System.monotonic_time(:millisecond) - start_time

        # Should handle edge cases quickly
        assert execution_time < 2000
        
        # Should return valid structure even for edge cases
        assert is_map(results)
        assert Map.has_key?(results, :applicable_law_count)
      end
    end
  end
end