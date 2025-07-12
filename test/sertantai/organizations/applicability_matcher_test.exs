defmodule Sertantai.Organizations.ApplicabilityMatcherTest do
  use Sertantai.DataCase, async: false  # SYNCHRONOUS to avoid terminal crashes

  alias Sertantai.Organizations.ApplicabilityMatcher

  describe "basic applicability screening" do
    test "returns supported industry sectors" do
      sectors = ApplicabilityMatcher.get_supported_industry_sectors()
      
      assert is_list(sectors)
      assert length(sectors) > 0
      assert {"Construction", "construction"} in sectors
      assert {"Healthcare", "healthcare"} in sectors
    end

    test "returns supported regions" do
      regions = ApplicabilityMatcher.get_supported_regions()
      
      assert is_list(regions)
      assert length(regions) > 0
      assert {"England", "england"} in regions
      assert {"Scotland", "scotland"} in regions
    end

    test "returns organization types" do
      types = ApplicabilityMatcher.get_organization_types()
      
      assert is_list(types)
      assert length(types) > 0
      assert {"Limited Company", "limited_company"} in types
    end

    test "performs basic screening for sample organization" do
      organization = %{
        core_profile: %{
          "industry_sector" => "construction",
          "headquarters_region" => "england",
          "total_employees" => 50
        }
      }

      result = ApplicabilityMatcher.perform_basic_screening(organization)

      assert is_map(result)
      assert Map.has_key?(result, :applicable_law_count)
      assert Map.has_key?(result, :sample_regulations)
      assert Map.has_key?(result, :screening_method)
      assert result.screening_method == "phase2_function_optimized"
      assert Map.has_key?(result, :organization_profile)
      assert Map.has_key?(result, :generated_at)
      assert result.confidence_level == "enhanced"
      assert Map.has_key?(result, :function_filter)
      assert result.function_filter == "Making laws only (duty-creating)"
    end

    test "basic applicability count returns integer" do
      organization = %{
        core_profile: %{
          "industry_sector" => "healthcare",
          "headquarters_region" => "wales"
        }
      }

      count = ApplicabilityMatcher.basic_applicability_count(organization)
      assert is_integer(count)
      assert count >= 0
    end

    test "basic applicability preview returns list" do
      organization = %{
        core_profile: %{
          "industry_sector" => "manufacturing",
          "headquarters_region" => "scotland"
        }
      }

      preview = ApplicabilityMatcher.basic_applicability_preview(organization, 5)
      assert is_list(preview)
    end
  end

  describe "private mapping functions via public interface" do
    test "screening extracts correct mapping attributes" do
      organization = %{
        core_profile: %{
          "industry_sector" => "construction",
          "headquarters_region" => "england",
          "total_employees" => 100
        }
      }

      result = ApplicabilityMatcher.perform_basic_screening(organization)
      profile = result.organization_profile

      assert profile.industry_sector == "construction"
      assert profile.headquarters_region == "england"
      assert profile.total_employees == 100
      assert profile.mapped_family == "💙 CONSTRUCTION"
      assert is_list(profile.applicable_extents)
      assert "England" in profile.applicable_extents
    end

    test "handles organization with minimal profile" do
      organization = %{
        core_profile: %{
          "industry_sector" => "unknown_sector"
        }
      }

      result = ApplicabilityMatcher.perform_basic_screening(organization)
      
      assert is_map(result)
      assert is_integer(result.applicable_law_count)
      assert result.organization_profile.mapped_family == nil
    end

    test "handles organization with empty profile" do
      organization = %{core_profile: %{}}

      result = ApplicabilityMatcher.perform_basic_screening(organization)
      
      assert is_map(result)
      assert is_integer(result.applicable_law_count)
      assert result.organization_profile.industry_sector == nil
    end
  end
end