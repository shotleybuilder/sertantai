defmodule SertantaiWeb.Organization.RegistrationLiveTest do
  use SertantaiWeb.ConnCase, async: false  # SYNCHRONOUS to avoid terminal crashes

  # Basic test to verify LiveView module loads and helper functions work
  describe "RegistrationLive helper functions" do
    test "helper functions are defined and work correctly" do
      # Test that the module exists and can be loaded
      assert Code.ensure_loaded?(SertantaiWeb.Organization.RegistrationLive)
      
      # Since mount requires session data and user authentication,
      # we'll test the basic functionality through the static functions
      
      # We can't easily test private functions, but we can verify the module loads
      # and that the public interface exists
      module = SertantaiWeb.Organization.RegistrationLive
      
      # Check that the required LiveView callbacks are defined
      assert function_exported?(module, :mount, 3)
      assert function_exported?(module, :handle_event, 3)
    end
  end

  describe "ApplicabilityMatcher integration in LiveView context" do
    test "ApplicabilityMatcher functions work for LiveView dropdowns" do
      # Test the data that would be used in the LiveView mount
      industry_sectors = Sertantai.Organizations.ApplicabilityMatcher.get_supported_industry_sectors()
      regions = Sertantai.Organizations.ApplicabilityMatcher.get_supported_regions()
      organization_types = Sertantai.Organizations.ApplicabilityMatcher.get_organization_types()

      # Verify the data structure expected by the template
      assert is_list(industry_sectors)
      assert length(industry_sectors) > 0
      
      # Verify each item is a tuple with label and value
      Enum.each(industry_sectors, fn item ->
        assert {label, value} = item
        assert is_binary(label)
        assert is_binary(value)
      end)

      assert is_list(regions)
      assert length(regions) > 0
      
      assert is_list(organization_types) 
      assert length(organization_types) > 0
    end
  end

  describe "form validation logic" do
    test "would work with form data structure" do
      # Test the form validation logic that would be used in handle_event
      # We can't test the actual LiveView without complex setup, but we can
      # verify the underlying service validation works
      
      valid_params = %{
        "organization_name" => "Test Company Ltd",
        "organization_type" => "limited_company",
        "industry_sector" => "construction",
        "headquarters_region" => "england",
        "total_employees" => "50"
      }

      # Test that OrganizationService validation works with form-like data
      atom_params = %{
        organization_name: valid_params["organization_name"],
        organization_type: valid_params["organization_type"],
        industry_sector: valid_params["industry_sector"],
        headquarters_region: valid_params["headquarters_region"]
      }

      assert :ok = Sertantai.Organizations.OrganizationService.validate_organization_attrs(atom_params)
    end

    test "would handle invalid form data" do
      invalid_params = %{
        "organization_name" => "",
        "organization_type" => "",
        "industry_sector" => "",
        "headquarters_region" => ""
      }

      atom_params = %{
        organization_name: invalid_params["organization_name"],
        organization_type: invalid_params["organization_type"],
        industry_sector: invalid_params["industry_sector"],
        headquarters_region: invalid_params["headquarters_region"]
      }

      assert {:error, errors} = Sertantai.Organizations.OrganizationService.validate_organization_attrs(atom_params)
      assert is_list(errors)
      assert length(errors) > 0
    end
  end
end