defmodule SertantaiWeb.Organization.LocationManagementLiveTest do
  use SertantaiWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  
  alias Sertantai.Organizations.{Organization, OrganizationLocation}
  alias Sertantai.Accounts.User
  
  describe "location management authentication" do
    test "redirects to login when not authenticated", %{conn: conn} do
      {:error, redirect} = live(conn, ~p"/organizations/locations")
      
      assert {:redirect, %{to: "/login"}} = redirect
    end
    
    test "redirects to organization registration when no organization", %{conn: conn} do
      # Create user but no organization
      user_attrs = %{
        email: "no_org@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      conn = log_in_user(conn, user)
      
      {:error, redirect} = live(conn, ~p"/organizations/locations")
      
      assert {:redirect, %{to: "/organizations/register"}} = redirect
    end
  end
  
  describe "location management interface" do
    setup %{conn: conn} do
      # Create a test user
      user_attrs = %{
        email: "location_mgmt@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Location Management Test Org",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction",
          "total_employees" => 50
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      conn = log_in_user(conn, user)
      
      %{conn: conn, user: user, organization: organization}
    end
    
    test "displays empty state when no locations", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      assert html =~ "Location Management"
      assert html =~ "Add Location" or html =~ "Add your first location"
      assert html =~ "Location Management Test Org"
    end
    
    test "displays organization locations", %{conn: conn, organization: organization} do
      # Create test locations
      location1_attrs = %{
        organization_id: organization.id,
        location_name: "Head Office",
        location_type: :headquarters,
        address: %{"street" => "123 Business St", "city" => "London"},
        geographic_region: "england",
        employee_count: 30,
        is_primary_location: true
      }
      {:ok, _location1} = Ash.create(OrganizationLocation, location1_attrs, domain: Sertantai.Organizations)
      
      location2_attrs = %{
        organization_id: organization.id,
        location_name: "Manchester Branch",
        location_type: :branch_office,
        address: %{"street" => "456 Industrial Ave", "city" => "Manchester"},
        geographic_region: "england",
        employee_count: 20
      }
      {:ok, _location2} = Ash.create(OrganizationLocation, location2_attrs, domain: Sertantai.Organizations)
      
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      assert html =~ "Location Management"
      assert html =~ "Head Office"
      assert html =~ "Manchester Branch"
      assert html =~ "Headquarters"
      assert html =~ "Branch Office"
      assert html =~ "Primary" # Should show primary location indicator
    end
    
    test "shows location details and statistics", %{conn: conn, organization: organization} do
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Test Manufacturing Site",
        location_type: :manufacturing_site,
        address: %{
          "street" => "789 Factory Road",
          "city" => "Birmingham",
          "postcode" => "B1 1AA"
        },
        geographic_region: "england",
        employee_count: 150,
        operational_status: :active,
        industry_activities: ["manufacturing", "assembly", "quality_control"],
        environmental_factors: %{
          "emissions" => "moderate",
          "waste_types" => ["metal", "plastic"]
        }
      }
      {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      assert html =~ "Test Manufacturing Site"
      assert html =~ "Manufacturing Site"
      assert html =~ "150" # Employee count
      assert html =~ "Active" # Operational status
      assert html =~ "england" or html =~ "England"
    end
    
    test "allows navigation to screening from location", %{conn: conn, organization: organization} do
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Screenable Location",
        location_type: :branch_office,
        address: %{"street" => "123 Test St"},
        geographic_region: "england"
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      assert html =~ "Screenable Location"
      
      # Should have screen/view buttons linking to screening
      assert html =~ "Screen" or html =~ "View Screening"
      
      # Check that the link contains the location ID
      assert html =~ location.id
    end
    
    test "shows appropriate interface mode based on location count", %{conn: conn, organization: organization} do
      # Test single location interface indicators
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Only Location",
        location_type: :headquarters,
        address: %{"street" => "123 Single St"},
        geographic_region: "england",
        is_primary_location: true
      }
      {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should show single location context
      assert html =~ "Only Location"
      
      # Add second location to test multi-location interface
      location2_attrs = %{
        organization_id: organization.id,
        location_name: "Second Location",
        location_type: :branch_office,
        address: %{"street" => "456 Multi St"},
        geographic_region: "scotland"
      }
      {:ok, _location2} = Ash.create(OrganizationLocation, location2_attrs, domain: Sertantai.Organizations)
      
      # Refresh the view
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should now show multi-location context
      assert html =~ "Only Location"
      assert html =~ "Second Location"
      
      # Should have organization-wide screening option
      assert html =~ "Organization" or html =~ "Aggregate" or html =~ "All Locations"
    end
  end
  
  describe "location actions" do
    setup %{conn: conn} do
      # Create a test user
      user_attrs = %{
        email: "location_actions@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Actions Test Org",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      # Create a test location
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Actions Test Location",
        location_type: :branch_office,
        address: %{"street" => "123 Actions St"},
        geographic_region: "england",
        employee_count: 25
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      conn = log_in_user(conn, user)
      
      %{conn: conn, user: user, organization: organization, location: location}
    end
    
    test "has add location button", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      assert has_element?(view, "button", "Add Location") or
             has_element?(view, "a", "Add Location") or
             html =~ "Add Location"
    end
    
    test "has edit location functionality", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      assert html =~ "Actions Test Location"
      
      # Should have edit functionality (button, link, or icon)
      assert html =~ "Edit" or 
             html =~ "edit" or 
             has_element?(view, "[phx-click*='edit']") or
             has_element?(view, "a[href*='edit']")
    end
    
    test "has delete location functionality", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      assert html =~ "Actions Test Location"
      
      # Should have delete functionality (button or link)
      assert html =~ "Delete" or 
             html =~ "Remove" or
             has_element?(view, "[phx-click*='delete']") or
             has_element?(view, "[phx-click*='remove']")
    end
    
    test "has screening navigation", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      assert html =~ "Actions Test Location"
      
      # Should have screening navigation
      assert html =~ "Screen" or 
             html =~ "Screening" or
             has_element?(view, "a[href*='applicability']") or
             has_element?(view, "a[href*='screening']")
    end
    
    test "navigation to smart screening route", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should have links to smart screening
      assert html =~ ~r/\/applicability\/smart/ or
             html =~ "Smart Screening" or
             html =~ "Start Screening"
    end
  end
  
  describe "multi-location specific features" do
    setup %{conn: conn} do
      # Create a test user
      user_attrs = %{
        email: "multi_location@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Multi-Location Test Org",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      # Create multiple test locations
      locations = for i <- 1..3 do
        location_attrs = %{
          organization_id: organization.id,
          location_name: "Location #{i}",
          location_type: if(i == 1, do: :headquarters, else: :branch_office),
          address: %{"street" => "#{i} Test Street", "city" => "City #{i}"},
          geographic_region: if(i == 1, do: "england", else: "scotland"),
          employee_count: i * 20,
          is_primary_location: i == 1,
          operational_status: :active
        }
        {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
        location
      end
      
      conn = log_in_user(conn, user)
      
      %{conn: conn, user: user, organization: organization, locations: locations}
    end
    
    test "displays multi-location summary", %{conn: conn, locations: locations} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should show all locations
      assert html =~ "Location 1"
      assert html =~ "Location 2" 
      assert html =~ "Location 3"
      
      # Should show total locations count
      assert html =~ "3" # total locations
      
      # Should distinguish primary location
      assert html =~ "Primary" or html =~ "Headquarters"
    end
    
    test "shows aggregate screening option", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should have organization-wide screening option
      assert html =~ "Organization" or 
             html =~ "Aggregate" or 
             html =~ "All Locations" or
             html =~ "Organization-Wide"
      
      # Should link to aggregate screening
      assert html =~ ~r/\/applicability\/organization/ or
             html =~ ~r/\/applicability\/aggregate/
    end
    
    test "shows location-specific statistics", %{conn: conn, locations: locations} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should show different employee counts
      assert html =~ "20" # Location 1
      assert html =~ "40" # Location 2
      assert html =~ "60" # Location 3
      
      # Should show different regions
      assert html =~ "england" or html =~ "England"
      assert html =~ "scotland" or html =~ "Scotland"
      
      # Should show different location types
      assert html =~ "Headquarters"
      assert html =~ "Branch Office"
    end
    
    test "provides navigation to individual location screening", %{conn: conn, locations: [location1, location2, location3]} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should have links to individual location screening
      assert html =~ location1.id
      assert html =~ location2.id
      assert html =~ location3.id
      
      # Links should point to location-specific screening
      assert html =~ ~r/\/applicability\/location\/#{location1.id}/ or
             html =~ "Screen Location 1"
    end
  end
  
  describe "responsive design and accessibility" do
    setup %{conn: conn} do
      # Create a test user
      user_attrs = %{
        email: "responsive@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Responsive Test Org",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      conn = log_in_user(conn, user)
      
      %{conn: conn, user: user, organization: organization}
    end
    
    test "renders proper page structure", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should have proper page title
      assert view.module == SertantaiWeb.Organization.LocationManagementLive
      
      # Should have main content area
      assert html =~ "Location Management"
      
      # Should have semantic HTML structure
      assert html =~ "<main" or html =~ "main"
    end
    
    test "includes proper navigation elements", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should have navigation back to organizations
      assert html =~ "Organizations" or 
             html =~ "Back" or
             has_element?(view, "a[href*='/organizations']")
    end
    
    test "handles empty state gracefully", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should show helpful empty state
      assert html =~ "Add" or 
             html =~ "Create" or 
             html =~ "first location" or
             html =~ "No locations"
    end
    
    test "includes action buttons", %{conn: conn, organization: organization} do
      # Create a location first
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Button Test Location",
        location_type: :branch_office,
        address: %{"street" => "123 Button St"},
        geographic_region: "england"
      }
      {:ok, _location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should have clear action buttons
      assert html =~ "button" or 
             html =~ "btn" or
             has_element?(view, "button") or
             has_element?(view, ".button")
    end
  end
  
  describe "integration with SingleLocationAdapter" do
    setup %{conn: conn} do
      # Create a test user
      user_attrs = %{
        email: "adapter@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Adapter Test Org",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      conn = log_in_user(conn, user)
      
      %{conn: conn, user: user, organization: organization}
    end
    
    test "adapts interface for single location organization", %{conn: conn, organization: organization} do
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
      
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should show single location context
      assert html =~ "Single Location"
      
      # Should not show multi-location specific features
      refute html =~ "Organization-Wide" and html =~ "Aggregate"
      
      # Should provide direct access to location screening
      assert html =~ "Screen" or html =~ "Screening"
    end
    
    test "adapts interface for multi-location organization", %{conn: conn, organization: organization} do
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
      
      {:ok, view, html} = live(conn, ~p"/organizations/locations")
      
      # Should show both locations
      assert html =~ "Multi Location 1"
      assert html =~ "Multi Location 2"
      
      # Should show multi-location specific features
      assert html =~ "Organization" or html =~ "Aggregate" or html =~ "All Locations"
      
      # Should provide both individual and aggregate screening options
      assert html =~ "Screen" # Individual screening
    end
  end
end