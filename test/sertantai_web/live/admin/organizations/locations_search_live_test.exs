defmodule SertantaiWeb.Admin.Organizations.LocationsSearchLiveTest do
  @moduledoc """
  Test locations search functionality using safe component testing patterns.
  
  Tests the global location search interface that allows admins to search
  for organizations and then view/manage their locations.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  
  alias SertantaiWeb.Admin.Organizations.LocationsSearchLive
  alias Phoenix.LiveView.Socket
  
  describe "locations search component rendering" do
    test "renders location search interface for admin user" do
      admin = user_fixture(%{role: :admin})
      
      # Mock organization data
      org1 = %{
        id: "test-org-1",
        organization_name: "ACME Construction",
        email_domain: "acme.com",
        location_count: 2,
        organization_locations: [
          %{id: "loc-1", location_name: "London Office"},
          %{id: "loc-2", location_name: "Manchester Branch"}
        ]
      }
      
      org2 = %{
        id: "test-org-2", 
        organization_name: "Tech Solutions Ltd",
        email_domain: "techsolutions.com",
        location_count: 1,
        organization_locations: [
          %{id: "loc-3", location_name: "Edinburgh HQ"}
        ]
      }
      
      # Create socket for initial search state (no organization selected)
      socket = %Socket{
        assigns: %{
          current_user: admin,
          search_term: "",
          selected_organization: nil,
          organizations: [],
          locations: [],
          searching: false,
          page: 1,
          per_page: 20,
          total_locations: 0,
          recent_organizations: [org1, org2],
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&LocationsSearchLive.render/1, socket.assigns)
      
      # Check that search interface elements are present
      assert html =~ "Organization Locations"
      assert html =~ "Search for organizations and manage their locations across the entire system"
      assert html =~ "Search Organizations"
      assert html =~ "Search by organization name or email domain..."
      
      # Check that recent organizations are shown
      assert html =~ "Recent Organizations"
      assert html =~ "ACME Construction"
      assert html =~ "Tech Solutions Ltd"
      assert html =~ "acme.com"
      assert html =~ "techsolutions.com"
      assert html =~ "2 locations"
      assert html =~ "1 location"
    end
    
    test "renders location search interface for support user" do
      support = user_fixture(%{role: :support})
      
      socket = %Socket{
        assigns: %{
          current_user: support,
          search_term: "",
          selected_organization: nil,
          organizations: [],
          locations: [],
          searching: false,
          page: 1,
          per_page: 20,
          total_locations: 0,
          recent_organizations: [],
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&LocationsSearchLive.render/1, socket.assigns)
      
      # Support users should see the interface
      assert html =~ "Organization Locations"
      assert html =~ "Search Organizations"
    end
    
    test "displays search results when organizations are found" do
      admin = user_fixture(%{role: :admin})
      
      # Mock search results
      search_results = [
        %{
          id: "search-org-1",
          organization_name: "ACME Corp",
          email_domain: "acme.com",
          location_count: 3
        },
        %{
          id: "search-org-2",
          organization_name: "ACME Industries", 
          email_domain: "acme-industries.com",
          location_count: 1
        }
      ]
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          search_term: "acme",
          selected_organization: nil,
          organizations: search_results,
          locations: [],
          searching: false,
          page: 1,
          per_page: 20,
          total_locations: 0,
          recent_organizations: [],
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&LocationsSearchLive.render/1, socket.assigns)
      
      # Check search results display
      assert html =~ "Search Results"
      assert html =~ "ACME Corp"
      assert html =~ "ACME Industries"
      assert html =~ "acme.com"
      assert html =~ "acme-industries.com"
      assert html =~ "3 locations"
      assert html =~ "1 location"
    end
    
    test "shows searching state when search is in progress" do
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          search_term: "test",
          selected_organization: nil,
          organizations: [],
          locations: [],
          searching: true,  # Search in progress
          page: 1,
          per_page: 20,
          total_locations: 0,
          recent_organizations: [],
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&LocationsSearchLive.render/1, socket.assigns)
      
      # Check searching indicator
      assert html =~ "Searching..."
      assert html =~ "animate-spin"
    end
    
    test "displays selected organization locations" do
      admin = user_fixture(%{role: :admin})
      
      # Mock selected organization
      selected_org = %{
        id: "selected-org-1",
        organization_name: "Selected Corp",
        email_domain: "selected.com"
      }
      
      # Mock locations for the selected organization
      locations = [
        %{
          id: "loc-1",
          location_name: "London Office",
          location_type: :headquarters,
          geographic_region: "london",
          operational_status: :active,
          is_primary_location: true,
          postcode: "SW1A 1AA",
          organization: selected_org
        },
        %{
          id: "loc-2", 
          location_name: "Manchester Branch",
          location_type: :branch,
          geographic_region: "manchester",
          operational_status: :inactive,
          is_primary_location: false,
          postcode: "M1 1AA",
          organization: selected_org
        }
      ]
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          search_term: "",
          selected_organization: selected_org,
          organizations: [],
          locations: locations,
          searching: false,
          page: 1,
          per_page: 20,
          total_locations: 2,
          recent_organizations: [],
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&LocationsSearchLive.render/1, socket.assigns)
      
      # Check selected organization display
      assert html =~ "Locations for Selected Corp"
      assert html =~ "2 locations total"
      assert html =~ "Manage All"
      assert html =~ "Clear"
      
      # Check locations table
      assert html =~ "London Office"
      assert html =~ "Manchester Branch"
      assert html =~ "Primary"
      assert html =~ "Active"
      assert html =~ "Inactive"
      assert html =~ "SW1A 1AA"
      assert html =~ "M1 1AA"
      
      # Check action links
      assert html =~ "Edit"
      assert html =~ "View Org"
    end
    
    test "shows empty state when no locations found for selected organization" do
      admin = user_fixture(%{role: :admin})
      
      selected_org = %{
        id: "empty-org-1",
        organization_name: "Empty Corp",
        email_domain: "empty.com"
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          search_term: "",
          selected_organization: selected_org,
          organizations: [],
          locations: [],
          searching: false,
          page: 1,
          per_page: 20,
          total_locations: 0,
          recent_organizations: [],
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&LocationsSearchLive.render/1, socket.assigns)
      
      # Check empty state
      assert html =~ "Locations for Empty Corp"
      assert html =~ "0 locations total"
      assert html =~ "No locations found"
      assert html =~ "This organization doesn't have any locations yet"
      assert html =~ "Add First Location"
    end
    
    test "displays pagination when there are many locations" do
      admin = user_fixture(%{role: :admin})
      
      selected_org = %{
        id: "big-org-1", 
        organization_name: "Big Corp",
        email_domain: "bigcorp.com"
      }
      
      # Create 5 mock locations (but total_locations is 50 to show pagination)
      locations = Enum.map(1..5, fn i ->
        %{
          id: "loc-#{i}",
          location_name: "Office #{i}",
          location_type: :branch,
          geographic_region: "region#{i}",
          operational_status: :active,
          is_primary_location: i == 1,
          postcode: "AA#{i} #{i}AA",
          organization: selected_org
        }
      end)
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          search_term: "",
          selected_organization: selected_org,
          organizations: [],
          locations: locations,
          searching: false,
          page: 1,
          per_page: 20,
          total_locations: 50,  # More than per_page to trigger pagination
          recent_organizations: [],
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&LocationsSearchLive.render/1, socket.assigns)
      
      # Check pagination elements (pagination appears because 50 > 20)
      assert html =~ "Showing"
      assert html =~ "1" 
      assert html =~ "5" 
      assert html =~ "50 locations"
      assert html =~ "Show:"
      assert html =~ "Previous"
      assert html =~ "Next"
    end
    
    test "breadcrumb navigation is present" do
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          search_term: "",
          selected_organization: nil,
          organizations: [],
          locations: [],
          searching: false,
          page: 1,
          per_page: 20,
          total_locations: 0,
          recent_organizations: [],
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&LocationsSearchLive.render/1, socket.assigns)
      
      # Check breadcrumb navigation
      assert html =~ "Admin Dashboard"
      assert html =~ "Organization Locations"
      assert html =~ "aria-label=\"Breadcrumb\""
    end
    
    test "handles empty search results gracefully" do
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          search_term: "nonexistent",
          selected_organization: nil,
          organizations: [],  # No search results
          locations: [],
          searching: false,
          page: 1,
          per_page: 20,
          total_locations: 0,
          recent_organizations: [],
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&LocationsSearchLive.render/1, socket.assigns)
      
      # Should not show search results section when empty 
      # (the component shows "Search Results" only when organizations list is not empty)
      # But should still show the search interface
      assert html =~ "Search Organizations"
      assert html =~ "nonexistent"  # Search term should be preserved
    end
  end
end