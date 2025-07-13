defmodule Sertantai.Organizations.SingleLocationAdapterTest do
  use Sertantai.DataCase, async: false
  
  alias Sertantai.Organizations.{Organization, OrganizationLocation, SingleLocationAdapter}
  alias Sertantai.Accounts.User
  
  describe "interface_mode/1" do
    setup do
      # Create a test user
      user_attrs = %{
        email: "adapter_test@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Adapter Test Organization",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      %{user: user, organization: organization}
    end
    
    test "returns :no_locations for organization with no locations", %{organization: organization} do
      # Load organization with empty locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      assert SingleLocationAdapter.interface_mode(org_with_locations) == :no_locations
    end
    
    test "returns :single_location for organization with one location", %{organization: organization} do
      # Create single location
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Single Location",
        location_type: :headquarters,
        address: %{"street" => "123 Single St"},
        geographic_region: "england",
        is_primary_location: true
      }
      {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      assert SingleLocationAdapter.interface_mode(org_with_locations) == :single_location
    end
    
    test "returns :multi_location for organization with multiple locations", %{organization: organization} do
      # Create multiple locations
      for i <- 1..3 do
        location_attrs = %{
          organization_id: organization.id,
          location_name: "Location #{i}",
          location_type: if(i == 1, do: :headquarters, else: :branch_office),
          address: %{"street" => "#{i} Multi St"},
          geographic_region: "england",
          is_primary_location: i == 1
        }
        {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      end
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      assert SingleLocationAdapter.interface_mode(org_with_locations) == :multi_location
    end
    
    test "handles edge case with two locations", %{organization: organization} do
      # Create exactly two locations
      for i <- 1..2 do
        location_attrs = %{
          organization_id: organization.id,
          location_name: "Location #{i}",
          location_type: if(i == 1, do: :headquarters, else: :branch_office),
          address: %{"street" => "#{i} Two St"},
          geographic_region: "england",
          is_primary_location: i == 1
        }
        {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      end
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      assert SingleLocationAdapter.interface_mode(org_with_locations) == :multi_location
    end
    
    test "returns :single_location as fallback for unexpected location data", %{organization: organization} do
      # Create organization with unexpected location structure (simulate edge case)
      org_with_unexpected = %{organization | locations: nil}
      
      assert SingleLocationAdapter.interface_mode(org_with_unexpected) == :single_location
    end
  end
  
  describe "get_primary_location/1" do
    setup do
      # Create a test user
      user_attrs = %{
        email: "primary_test@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Primary Test Organization",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      %{user: user, organization: organization}
    end
    
    test "returns error for multi-location organization", %{organization: organization} do
      # Create multiple locations
      for i <- 1..2 do
        location_attrs = %{
          organization_id: organization.id,
          location_name: "Multi Location #{i}",
          location_type: if(i == 1, do: :headquarters, else: :branch_office),
          address: %{"street" => "#{i} Multi St"},
          geographic_region: "england",
          is_primary_location: i == 1
        }
        {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      end
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      assert {:error, :not_single_location} = SingleLocationAdapter.get_primary_location(org_with_locations)
    end
    
    test "returns the single location for single-location organization", %{organization: organization} do
      # Create single location
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Primary Single Location",
        location_type: :headquarters,
        address: %{"street" => "123 Primary St"},
        geographic_region: "england",
        is_primary_location: true
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      assert {:ok, returned_location} = SingleLocationAdapter.get_primary_location(org_with_locations)
      assert returned_location.id == location.id
      assert returned_location.location_name == "Primary Single Location"
    end
    
    test "finds marked primary location when multiple exist but only one primary", %{organization: organization} do
      # Create multiple locations but with clear primary designation
      location1_attrs = %{
        organization_id: organization.id,
        location_name: "Non-Primary Location",
        location_type: :branch_office,
        address: %{"street" => "123 Non-Primary St"},
        geographic_region: "england",
        is_primary_location: false
      }
      {:ok, _location1} = Ash.create(OrganizationLocation, location1_attrs, domain: Sertantai.Organizations)
      
      # This should trigger the case where we have multiple locations but are looking for primary
      # However, since interface_mode will return :multi_location, this should return :not_single_location
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      # Should return error because it's not a single location organization
      assert {:error, :not_single_location} = SingleLocationAdapter.get_primary_location(org_with_locations)
    end
    
    test "handles organization with no locations", %{organization: organization} do
      # Load organization with empty locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      assert {:error, :not_single_location} = SingleLocationAdapter.get_primary_location(org_with_locations)
    end
  end
  
  describe "get_screening_route/1" do
    setup do
      # Create a test user
      user_attrs = %{
        email: "routing_test@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Routing Test Organization",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      %{user: user, organization: organization}
    end
    
    test "routes to location management for organization with no locations", %{organization: organization} do
      # Load organization with empty locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      assert {:no_locations, route} = SingleLocationAdapter.get_screening_route(org_with_locations)
      assert route =~ "/organizations/locations"
    end
    
    test "routes to location-specific screening for single location", %{organization: organization} do
      # Create single location
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Single Route Location",
        location_type: :headquarters,
        address: %{"street" => "123 Route St"},
        geographic_region: "england",
        is_primary_location: true
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      assert {:single_location, route} = SingleLocationAdapter.get_screening_route(org_with_locations)
      assert route =~ "/applicability/location/#{location.id}"
    end
    
    test "routes to aggregate screening for multi-location", %{organization: organization} do
      # Create multiple locations
      for i <- 1..3 do
        location_attrs = %{
          organization_id: organization.id,
          location_name: "Multi Route Location #{i}",
          location_type: if(i == 1, do: :headquarters, else: :branch_office),
          address: %{"street" => "#{i} Route St"},
          geographic_region: "england",
          is_primary_location: i == 1
        }
        {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      end
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      assert {:multi_location, route} = SingleLocationAdapter.get_screening_route(org_with_locations)
      assert route =~ "/applicability/organization/aggregate"
    end
    
    test "provides correct route patterns for different organization types", %{organization: organization} do
      # Test with exactly two locations (edge case for multi-location)
      for i <- 1..2 do
        location_attrs = %{
          organization_id: organization.id,
          location_name: "Edge Case Location #{i}",
          location_type: if(i == 1, do: :headquarters, else: :branch_office),
          address: %{"street" => "#{i} Edge St"},
          geographic_region: "england",
          is_primary_location: i == 1
        }
        {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      end
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      assert {:multi_location, route} = SingleLocationAdapter.get_screening_route(org_with_locations)
      assert route =~ "/applicability/organization/aggregate"
    end
  end
  
  describe "get_legacy_profile/1" do
    setup do
      # Create a test user
      user_attrs = %{
        email: "legacy_test@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization with legacy core_profile
      org_attrs = %{
        organization_name: "Legacy Test Organization",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction",
          "total_employees" => 100,
          "annual_turnover" => "1000000"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      %{user: user, organization: organization}
    end
    
    test "returns original core_profile when no primary location found", %{organization: organization} do
      # Load organization with empty locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      legacy_profile = SingleLocationAdapter.get_legacy_profile(org_with_locations)
      
      assert legacy_profile["organization_type"] == "limited_company"
      assert legacy_profile["headquarters_region"] == "england"
      assert legacy_profile["industry_sector"] == "construction"
      assert legacy_profile["total_employees"] == 100
    end
    
    test "merges location data with core_profile for single location", %{organization: organization} do
      # Create single location with specific data
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Legacy Primary Location",
        location_type: :headquarters,
        address: %{"street" => "123 Legacy St", "city" => "Birmingham"},
        geographic_region: "england",
        employee_count: 75,  # Different from org total_employees
        is_primary_location: true
      }
      {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      legacy_profile = SingleLocationAdapter.get_legacy_profile(org_with_locations)
      
      # Should have original organization data
      assert legacy_profile["organization_type"] == "limited_company"
      assert legacy_profile["industry_sector"] == "construction"
      
      # Should have location-specific overrides
      assert legacy_profile["headquarters_region"] == "england"  # From location
      assert legacy_profile["location_type"] == :headquarters  # From location
      assert legacy_profile["total_employees"] == 75  # From location employee_count
    end
    
    test "preserves organization data when location has nil employee_count", %{organization: organization} do
      # Create location without employee_count
      location_attrs = %{
        organization_id: organization.id,
        location_name: "No Employee Count Location",
        location_type: :headquarters,
        address: %{"street" => "123 NoCount St"},
        geographic_region: "scotland",  # Different from org
        is_primary_location: true
        # employee_count intentionally omitted (will be nil)
      }
      {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      legacy_profile = SingleLocationAdapter.get_legacy_profile(org_with_locations)
      
      # Should use location's geographic_region
      assert legacy_profile["headquarters_region"] == "scotland"
      
      # Should fall back to organization's total_employees when location has nil
      assert legacy_profile["total_employees"] == 100  # Original org value
    end
    
    test "handles multi-location organization gracefully", %{organization: organization} do
      # Create multiple locations
      for i <- 1..2 do
        location_attrs = %{
          organization_id: organization.id,
          location_name: "Multi Legacy Location #{i}",
          location_type: if(i == 1, do: :headquarters, else: :branch_office),
          address: %{"street" => "#{i} Multi Legacy St"},
          geographic_region: "england",
          is_primary_location: i == 1,
          employee_count: i * 30
        }
        {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      end
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      # Should fall back to original core_profile since get_primary_location will fail
      legacy_profile = SingleLocationAdapter.get_legacy_profile(org_with_locations)
      
      assert legacy_profile["organization_type"] == "limited_company"
      assert legacy_profile["headquarters_region"] == "england"  # Original value
      assert legacy_profile["total_employees"] == 100  # Original value
    end
  end
  
  describe "edge cases and error handling" do
    setup do
      # Create a test user
      user_attrs = %{
        email: "edge_case@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Edge Case Organization",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      %{user: user, organization: organization}
    end
    
    test "handles organization with multiple locations but no primary", %{organization: organization} do
      # Create multiple locations, none marked as primary
      for i <- 1..2 do
        location_attrs = %{
          organization_id: organization.id,
          location_name: "No Primary Location #{i}",
          location_type: :branch_office,
          address: %{"street" => "#{i} No Primary St"},
          geographic_region: "england",
          is_primary_location: false  # Explicitly not primary
        }
        {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      end
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      # Should detect as multi-location
      assert SingleLocationAdapter.interface_mode(org_with_locations) == :multi_location
      
      # Should route to aggregate screening
      assert {:multi_location, route} = SingleLocationAdapter.get_screening_route(org_with_locations)
      assert route =~ "/applicability/organization/aggregate"
    end
    
    test "handles organization with single location not marked as primary", %{organization: organization} do
      # Create single location but not marked as primary
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Single Not Primary",
        location_type: :headquarters,
        address: %{"street" => "123 Not Primary St"},
        geographic_region: "england",
        is_primary_location: false
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      # Should still detect as single location
      assert SingleLocationAdapter.interface_mode(org_with_locations) == :single_location
      
      # Should route to location-specific screening
      assert {:single_location, route} = SingleLocationAdapter.get_screening_route(org_with_locations)
      assert route =~ "/applicability/location/#{location.id}"
      
      # Should be able to get the single location even if not marked primary
      assert {:ok, returned_location} = SingleLocationAdapter.get_primary_location(org_with_locations)
      assert returned_location.id == location.id
    end
    
    test "handles nil locations gracefully", %{organization: organization} do
      # Create organization with nil locations (simulate unloaded relationship)
      org_with_nil = %{organization | locations: nil}
      
      # Should default to single_location mode
      assert SingleLocationAdapter.interface_mode(org_with_nil) == :single_location
      
      # Should handle errors gracefully in other functions
      assert {:error, :not_single_location} = SingleLocationAdapter.get_primary_location(org_with_nil)
    end
    
    test "handles empty list vs nil locations", %{organization: organization} do
      # Load organization with empty locations list
      {:ok, org_with_empty} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      # Should detect as no locations
      assert SingleLocationAdapter.interface_mode(org_with_empty) == :no_locations
      
      # Should route to location management
      assert {:no_locations, route} = SingleLocationAdapter.get_screening_route(org_with_empty)
      assert route =~ "/organizations/locations"
    end
  end
  
  describe "integration with organization calculations" do
    setup do
      # Create a test user
      user_attrs = %{
        email: "integration@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Integration Test Organization",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      %{user: user, organization: organization}
    end
    
    test "correctly identifies single vs multi location for UI adaptation", %{organization: organization} do
      # Start with no locations
      {:ok, org_empty} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      assert SingleLocationAdapter.interface_mode(org_empty) == :no_locations
      
      # Add one location
      location1_attrs = %{
        organization_id: organization.id,
        location_name: "First Location",
        location_type: :headquarters,
        address: %{"street" => "123 First St"},
        geographic_region: "england",
        is_primary_location: true
      }
      {:ok, _location1} = Ash.create(OrganizationLocation, location1_attrs, domain: Sertantai.Organizations)
      
      {:ok, org_single} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      assert SingleLocationAdapter.interface_mode(org_single) == :single_location
      
      # Add second location
      location2_attrs = %{
        organization_id: organization.id,
        location_name: "Second Location",
        location_type: :branch_office,
        address: %{"street" => "456 Second St"},
        geographic_region: "scotland"
      }
      {:ok, _location2} = Ash.create(OrganizationLocation, location2_attrs, domain: Sertantai.Organizations)
      
      {:ok, org_multi} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      assert SingleLocationAdapter.interface_mode(org_multi) == :multi_location
    end
    
    test "provides consistent routing for UI navigation", %{organization: organization} do
      # Create single location
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Routing Test Location",
        location_type: :headquarters,
        address: %{"street" => "123 Routing St"},
        geographic_region: "england",
        is_primary_location: true
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      # Load organization with locations
      {:ok, org_with_locations} = Ash.load(organization, [:locations], domain: Sertantai.Organizations)
      
      # Test routing consistency
      mode = SingleLocationAdapter.interface_mode(org_with_locations)
      {returned_mode, route} = SingleLocationAdapter.get_screening_route(org_with_locations)
      
      assert mode == :single_location
      assert returned_mode == :single_location
      assert route =~ location.id
    end
  end
end