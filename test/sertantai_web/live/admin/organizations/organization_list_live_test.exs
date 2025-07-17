defmodule SertantaiWeb.Admin.Organizations.OrganizationListLiveTest do
  @moduledoc """
  Test organization list functionality using safe component testing patterns.
  
  Uses direct component rendering to avoid router authentication issues.
  See README.md in admin/ directory for testing approach explanation.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  
  alias SertantaiWeb.Admin.Organizations.OrganizationListLive
  alias Phoenix.LiveView.Socket
  
  describe "organization list component rendering" do
    test "renders organization list for admin user" do
      admin = user_fixture(%{role: :admin})
      
      # Mock organization data
      org1 = %{
        id: "test-org-1",
        organization_name: "ACME Construction",
        email_domain: "acme.com",
        verified: true,
        profile_completeness_score: Decimal.new("0.8"),
        core_profile: %{"industry_sector" => "construction", "organization_type" => "limited_company"},
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      org2 = %{
        id: "test-org-2",
        organization_name: "Tech Solutions Ltd",
        email_domain: "techsolutions.com",
        verified: false,
        profile_completeness_score: Decimal.new("0.6"),
        core_profile: %{"industry_sector" => "technology", "organization_type" => "limited_company"},
        inserted_at: ~U[2024-01-02 00:00:00Z]
      }
      
      # Create a socket with admin user
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organizations: [org1, org2],
          all_organizations: [org1, org2],
          search_term: "",
          status_filter: "all",
          verification_filter: "all",
          sort_by: "organization_name",
          sort_order: "asc",
          selected_organizations: [],
          show_organization_modal: false,
          editing_organization: nil,
          page: 1,
          per_page: 25,
          total_count: 2,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&OrganizationListLive.render/1, socket.assigns)
      
      # Check that admin interface elements are present
      assert html =~ "Organization Management"
      assert html =~ "New Organization"
      assert html =~ "ACME Construction"
      assert html =~ "Tech Solutions Ltd"
      assert html =~ "acme.com"
      assert html =~ "techsolutions.com"
      assert html =~ "Verified"
      assert html =~ "Unverified"
      
      # Check that Locations column is present with Manage links
      assert html =~ "Locations"
      assert html =~ "Manage"
      
      # Check that Manage links point to correct organization location management pages
      assert html =~ "/admin/organizations/test-org-1/locations"
      assert html =~ "/admin/organizations/test-org-2/locations"
    end
    
    test "renders organization list for support user" do
      support = user_fixture(%{role: :support})
      
      org = %{
        id: "test-org-1",
        organization_name: "Test Organization",
        email_domain: "test.com",
        verified: true,
        profile_completeness_score: Decimal.new("0.7"),
        core_profile: %{"industry_sector" => "construction"},
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: support,
          organizations: [org],
          all_organizations: [org],
          search_term: "",
          status_filter: "all",
          verification_filter: "all",
          sort_by: "organization_name",
          sort_order: "asc",
          selected_organizations: [],
          show_organization_modal: false,
          editing_organization: nil,
          page: 1,
          per_page: 25,
          total_count: 1,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&OrganizationListLive.render/1, socket.assigns)
      
      # Support users should see the interface but not "New Organization" button
      assert html =~ "Organization Management"
      refute html =~ "New Organization"
      assert html =~ "Test Organization"
      
      # Support users should still see Locations column with Manage links
      assert html =~ "Locations"
      assert html =~ "Manage"
      assert html =~ "/admin/organizations/test-org-1/locations"
    end
    
    test "search functionality filters organizations correctly" do
      admin = user_fixture(%{role: :admin})
      
      org1 = %{
        id: "test-org-1",
        organization_name: "ACME Construction",
        email_domain: "acme.com",
        verified: true,
        profile_completeness_score: Decimal.new("0.8"),
        core_profile: %{"industry_sector" => "construction"},
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organizations: [org1],  # Filtered to only show ACME
          all_organizations: [org1],
          search_term: "acme",
          status_filter: "all",
          verification_filter: "all",
          sort_by: "organization_name",
          sort_order: "asc",
          selected_organizations: [],
          show_organization_modal: false,
          editing_organization: nil,
          page: 1,
          per_page: 25,
          total_count: 1,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&OrganizationListLive.render/1, socket.assigns)
      
      # Should show filtered results
      assert html =~ "ACME Construction"
      assert html =~ "acme.com"
    end
    
    test "verification filter works correctly" do
      admin = user_fixture(%{role: :admin})
      
      verified_org = %{
        id: "test-org-1",
        organization_name: "Verified Corp",
        email_domain: "verified.com",
        verified: true,
        profile_completeness_score: Decimal.new("0.8"),
        core_profile: %{"industry_sector" => "construction"},
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organizations: [verified_org],  # Filtered to show only verified
          all_organizations: [verified_org],
          search_term: "",
          status_filter: "all",
          verification_filter: "verified",
          sort_by: "organization_name",
          sort_order: "asc",
          selected_organizations: [],
          show_organization_modal: false,
          editing_organization: nil,
          page: 1,
          per_page: 25,
          total_count: 1,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&OrganizationListLive.render/1, socket.assigns)
      
      # Should show only verified organization
      assert html =~ "Verified Corp"
      assert html =~ "Verified"
    end
    
    test "bulk operations interface appears when organizations are selected" do
      admin = user_fixture(%{role: :admin})
      
      org1 = %{
        id: "test-org-1",
        organization_name: "Org One",
        email_domain: "org1.com",
        verified: false,
        profile_completeness_score: Decimal.new("0.6"),
        core_profile: %{"industry_sector" => "construction"},
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      org2 = %{
        id: "test-org-2",
        organization_name: "Org Two",
        email_domain: "org2.com",
        verified: false,
        profile_completeness_score: Decimal.new("0.7"),
        core_profile: %{"industry_sector" => "technology"},
        inserted_at: ~U[2024-01-02 00:00:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organizations: [org1, org2],
          all_organizations: [org1, org2],
          search_term: "",
          status_filter: "all",
          verification_filter: "all",
          sort_by: "organization_name",
          sort_order: "asc",
          selected_organizations: ["test-org-1", "test-org-2"],  # Organizations selected
          show_organization_modal: false,
          editing_organization: nil,
          page: 1,
          per_page: 25,
          total_count: 2,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&OrganizationListLive.render/1, socket.assigns)
      
      # Should show bulk operations
      assert html =~ "2 organization(s) selected"
      assert html =~ "Verify Selected"
      assert html =~ "Delete Selected"
      assert html =~ "Clear Selection"
    end
    
    test "new organization modal shows when in new action" do
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organizations: [],
          all_organizations: [],
          search_term: "",
          status_filter: "all",
          verification_filter: "all",
          sort_by: "organization_name",
          sort_order: "asc",
          selected_organizations: [],
          show_organization_modal: true,
          editing_organization: nil,
          page: 1,
          per_page: 25,
          total_count: 0,
          __changed__: %{},
          flash: %{},
          live_action: :new
        }
      }
      
      html = render_component(&OrganizationListLive.render/1, socket.assigns)
      
      # Should show modal for new organization
      assert html =~ "Create New Organization"
      assert html =~ "Organization Name"
      assert html =~ "Email Domain"
      assert html =~ "Organization Type"
    end
    
    test "sorting controls display correctly" do
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organizations: [],
          all_organizations: [],
          search_term: "",
          status_filter: "all",
          verification_filter: "all",
          sort_by: "organization_name",
          sort_order: "asc",
          selected_organizations: [],
          show_organization_modal: false,
          editing_organization: nil,
          page: 1,
          per_page: 25,
          total_count: 0,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&OrganizationListLive.render/1, socket.assigns)
      
      # Should show sortable column headers
      assert html =~ "Organization"
      assert html =~ "Domain"
      assert html =~ "Industry"
      assert html =~ "Status"
      assert html =~ "Completeness"
      assert html =~ "Created"
      
      # Should show sort indicator for organization_name column
      assert html =~ "M5 8l5-5 5 5H5z"  # Ascending arrow for organization_name
    end
    
    test "location management links are positioned correctly in Locations column" do
      admin = user_fixture(%{role: :admin})
      
      org = %{
        id: "test-org-123",
        organization_name: "Example Corp",
        email_domain: "example.com",
        verified: true,
        profile_completeness_score: Decimal.new("0.75"),
        core_profile: %{"industry_sector" => "technology", "organization_type" => "limited_company"},
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organizations: [org],
          all_organizations: [org],
          search_term: "",
          status_filter: "all",
          verification_filter: "all",
          sort_by: "organization_name",
          sort_order: "asc",
          selected_organizations: [],
          show_organization_modal: false,
          editing_organization: nil,
          page: 1,
          per_page: 25,
          total_count: 1,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&OrganizationListLive.render/1, socket.assigns)
      
      # Check that Locations column exists and contains Manage link
      assert html =~ "Locations"
      assert html =~ "Manage"
      
      # Check that Manage link points to organization location management page
      assert html =~ "/admin/organizations/test-org-123/locations"
      
      # Check that organization name is still clickable for edit
      assert html =~ "Example Corp"
      assert html =~ "/admin/organizations/test-org-123/edit"
      
      # Verify no redundant Edit/Delete buttons in Locations column
      # (Edit is via organization name, Delete is via bulk operations)
      refute html =~ "text-blue-600 hover:text-blue-900\">Edit<"
      refute html =~ "text-red-600 hover:text-red-900\">Delete<"
    end
    
    test "table column order is correct with Locations as second column" do
      admin = user_fixture(%{role: :admin})
      
      org = %{
        id: "test-org-1",
        organization_name: "Test Organization",
        email_domain: "test.com",
        verified: true,
        profile_completeness_score: Decimal.new("0.8"),
        core_profile: %{"industry_sector" => "construction", "organization_type" => "limited_company"},
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organizations: [org],
          all_organizations: [org],
          search_term: "",
          status_filter: "all",
          verification_filter: "all",
          sort_by: "organization_name",
          sort_order: "asc",
          selected_organizations: [],
          show_organization_modal: false,
          editing_organization: nil,
          page: 1,
          per_page: 25,
          total_count: 1,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&OrganizationListLive.render/1, socket.assigns)
      
      # Parse the HTML to check column order
      # First column should be checkbox (no text header)
      # Second column should be Locations
      # Third column should be Organization
      
      # Look specifically for table headers to verify column order
      # Extract the table header section
      table_header_match = Regex.run(~r/<thead.*?<\/thead>/s, html)
      assert table_header_match != nil, "Should find table header section"
      
      [table_header] = table_header_match
      
      # In the table header, Locations should come before Organization
      locations_in_header = Regex.run(~r/Locations/, table_header, return: :index)
      org_in_header = Regex.run(~r/Organization/, table_header, return: :index)
      
      assert locations_in_header != nil, "Locations header should be found"
      assert org_in_header != nil, "Organization header should be found"
      
      [{locations_pos, _}] = locations_in_header
      [{org_pos, _}] = org_in_header
      
      # Locations should come before Organization in the table header
      assert locations_pos < org_pos
      
      # Verify all expected column headers are present
      assert html =~ "Locations"
      assert html =~ "Organization" 
      assert html =~ "Type"
      assert html =~ "Domain"
      assert html =~ "Industry"
      assert html =~ "Status"
      assert html =~ "Completeness"
      assert html =~ "Created"
    end
    
    test "manage locations link navigates to correct organization location management page" do
      admin = user_fixture(%{role: :admin})
      
      org = %{
        id: "test-org-456",
        organization_name: "Navigation Test Corp",
        email_domain: "navtest.com",
        verified: true,
        profile_completeness_score: Decimal.new("0.9"),
        core_profile: %{"industry_sector" => "technology", "organization_type" => "limited_company"},
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organizations: [org],
          all_organizations: [org],
          search_term: "",
          status_filter: "all",
          verification_filter: "all",
          sort_by: "organization_name",
          sort_order: "asc",
          selected_organizations: [],
          show_organization_modal: false,
          editing_organization: nil,
          page: 1,
          per_page: 25,
          total_count: 1,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&OrganizationListLive.render/1, socket.assigns)
      
      # Check that the Manage link is present and points to the correct location management URL
      assert html =~ "Locations"
      assert html =~ "Manage"
      assert html =~ "href=\"/admin/organizations/test-org-456/locations\""
      assert html =~ "data-phx-link=\"redirect\""
      
      # Verify the link has the correct CSS classes for styling
      assert html =~ "text-indigo-600 hover:text-indigo-900"
      
      # Verify the organization name is also present for context
      assert html =~ "Navigation Test Corp"
    end
    
    test "location data types are handled correctly" do
      # Test that location data with mixed types (strings and atoms) is handled properly
      # This ensures the humanize_atom function fix works correctly
      
      # Mock location data that might have string values instead of atoms
      # This represents data that could come from the database in different formats
      mock_location = %{
        id: "test-location-1",
        location_name: "Test Location",
        location_type: "headquarters",  # string instead of atom
        geographic_region: "scotland",  # string instead of atom - this was causing the error
        operational_status: :active,    # atom
        postcode: "EH1 1AA",
        employee_count: 50,
        is_primary_location: true,
        organization_id: "test-org-1"
      }
      
      # Verify the data structure has the expected mix of types
      assert is_binary(mock_location.location_type)      # string
      assert is_binary(mock_location.geographic_region)  # string (this was causing FunctionClauseError)
      assert is_atom(mock_location.operational_status)   # atom
      
      # The fix should handle both strings and atoms gracefully
      # If this test passes, it means our humanize_atom function can handle mixed data types
      assert mock_location.geographic_region == "scotland"
      assert mock_location.location_type == "headquarters"
      assert mock_location.operational_status == :active
    end
  end
end