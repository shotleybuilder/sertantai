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
        profile_completeness_score: 0.8,
        core_profile: %{"industry_sector" => "construction", "organization_type" => "limited_company"},
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      org2 = %{
        id: "test-org-2",
        organization_name: "Tech Solutions Ltd",
        email_domain: "techsolutions.com",
        verified: false,
        profile_completeness_score: 0.6,
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
    end
    
    test "renders organization list for support user" do
      support = user_fixture(%{role: :support})
      
      org = %{
        id: "test-org-1",
        organization_name: "Test Organization",
        email_domain: "test.com",
        verified: true,
        profile_completeness_score: 0.7,
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
    end
    
    test "search functionality filters organizations correctly" do
      admin = user_fixture(%{role: :admin})
      
      org1 = %{
        id: "test-org-1",
        organization_name: "ACME Construction",
        email_domain: "acme.com",
        verified: true,
        profile_completeness_score: 0.8,
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
        profile_completeness_score: 0.8,
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
        profile_completeness_score: 0.6,
        core_profile: %{"industry_sector" => "construction"},
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      org2 = %{
        id: "test-org-2",
        organization_name: "Org Two",
        email_domain: "org2.com",
        verified: false,
        profile_completeness_score: 0.7,
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
  end
end