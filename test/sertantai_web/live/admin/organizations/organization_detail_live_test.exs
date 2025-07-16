defmodule SertantaiWeb.Admin.Organizations.OrganizationDetailLiveTest do
  @moduledoc """
  Test organization detail functionality using safe component testing patterns.
  
  Uses direct component rendering to avoid router authentication issues.
  See README.md in admin/ directory for testing approach explanation.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  
  alias SertantaiWeb.Admin.Organizations.OrganizationDetailLive
  alias Phoenix.LiveView.Socket
  
  describe "organization detail component rendering" do
    test "renders organization overview tab" do
      admin = user_fixture(%{role: :admin})
      
      # Mock organization data
      organization = %{
        id: "test-org-1",
        organization_name: "ACME Construction Ltd",
        email_domain: "acme.com",
        verified: true,
        profile_completeness_score: 0.85,
        core_profile: %{
          "organization_type" => "limited_company",
          "industry_sector" => "construction",
          "headquarters_region" => "england",
          "registration_number" => "12345678",
          "total_employees" => 75,
          "primary_sic_code" => "41201"
        },
        inserted_at: ~U[2024-01-01 10:30:00Z]
      }
      
      # Mock location data
      locations = [
        %{
          id: "loc-1",
          location_name: "Head Office",
          location_type: :headquarters,
          geographic_region: "england",
          operational_status: :active,
          is_primary_location: true,
          employee_count: 50,
          address: %{"street" => "123 Main St", "city" => "London", "postcode" => "SW1A 1AA"}
        },
        %{
          id: "loc-2",
          location_name: "Birmingham Branch",
          location_type: :branch_office,
          geographic_region: "england",
          operational_status: :active,
          is_primary_location: false,
          employee_count: 25,
          address: %{"street" => "456 High St", "city" => "Birmingham", "postcode" => "B1 1AA"}
        }
      ]
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organization: organization,
          locations: locations,
          organization_users: [],
          show_location_modal: false,
          editing_location: nil,
          selected_tab: "overview",
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&OrganizationDetailLive.render/1, socket.assigns)
      
      # Check organization header
      assert html =~ "ACME Construction Ltd"
      assert html =~ "acme.com"
      assert html =~ "Verified"
      
      # Check overview tab content
      assert html =~ "Organization Profile"
      assert html =~ "limited company"
      assert html =~ "Construction"
      assert html =~ "england"
      assert html =~ "12345678"
      assert html =~ "75"
      assert html =~ "41201"
      
      # Check profile completeness
      assert html =~ "85%"
      assert html =~ "Profile is well-populated"
      
      # Check location summary
      assert html =~ "Total Locations"
      assert html =~ "2"
      assert html =~ "Head Office"
    end
    
    test "renders locations tab with location list" do
      admin = user_fixture(%{role: :admin})
      
      organization = %{
        id: "test-org-1",
        organization_name: "ACME Construction Ltd",
        email_domain: "acme.com",
        verified: true,
        profile_completeness_score: 0.85,
        core_profile: %{"industry_sector" => "construction"},
        inserted_at: ~U[2024-01-01 10:30:00Z]
      }
      
      locations = [
        %{
          id: "loc-1",
          location_name: "Head Office",
          location_type: :headquarters,
          geographic_region: "england",
          operational_status: :active,
          is_primary_location: true,
          employee_count: 50,
          address: %{"street" => "123 Main St", "city" => "London", "postcode" => "SW1A 1AA"}
        }
      ]
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organization: organization,
          locations: locations,
          organization_users: [],
          show_location_modal: false,
          editing_location: nil,
          selected_tab: "locations",
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&OrganizationDetailLive.render/1, socket.assigns)
      
      # Check locations tab content
      assert html =~ "Organization Locations"
      assert html =~ "Add Location"
      assert html =~ "Head Office"
      assert html =~ "Primary"
      assert html =~ "Active"
      assert html =~ "Headquarters"
      assert html =~ "123 Main St, London, SW1A 1AA"
      assert html =~ "Employees:"
    end
    
    test "renders empty locations tab" do
      admin = user_fixture(%{role: :admin})
      
      organization = %{
        id: "test-org-1",
        organization_name: "ACME Construction Ltd",
        email_domain: "acme.com",
        verified: false,
        profile_completeness_score: 0.4,
        core_profile: %{"industry_sector" => "construction"},
        inserted_at: ~U[2024-01-01 10:30:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organization: organization,
          locations: [],
          organization_users: [],
          show_location_modal: false,
          editing_location: nil,
          selected_tab: "locations",
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&OrganizationDetailLive.render/1, socket.assigns)
      
      # Check empty state
      assert html =~ "No locations"
      assert html =~ "This organization doesn't have any locations yet"
      assert html =~ "Add First Location"
    end
    
    test "renders users tab placeholder" do
      admin = user_fixture(%{role: :admin})
      
      organization = %{
        id: "test-org-1",
        organization_name: "ACME Construction Ltd",
        email_domain: "acme.com",
        verified: true,
        profile_completeness_score: 0.85,
        core_profile: %{"industry_sector" => "construction"},
        inserted_at: ~U[2024-01-01 10:30:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organization: organization,
          locations: [],
          organization_users: [],
          show_location_modal: false,
          editing_location: nil,
          selected_tab: "users",
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&OrganizationDetailLive.render/1, socket.assigns)
      
      # Check users tab placeholder
      assert html =~ "Organization Users"
      assert html =~ "Add User (Coming Soon)"
    end
    
    test "renders analytics tab with organization stats" do
      admin = user_fixture(%{role: :admin})
      
      organization = %{
        id: "test-org-1",
        organization_name: "ACME Construction Ltd",
        email_domain: "acme.com",
        verified: true,
        profile_completeness_score: 0.75,
        core_profile: %{"industry_sector" => "construction"},
        inserted_at: ~U[2024-01-01 10:30:00Z]
      }
      
      locations = [
        %{id: "loc-1", geographic_region: "england", operational_status: :active},
        %{id: "loc-2", geographic_region: "scotland", operational_status: :active},
        %{id: "loc-3", geographic_region: "england", operational_status: :inactive}
      ]
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organization: organization,
          locations: locations,
          organization_users: [],
          show_location_modal: false,
          editing_location: nil,
          selected_tab: "analytics",
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&OrganizationDetailLive.render/1, socket.assigns)
      
      # Check analytics content
      assert html =~ "Profile Analytics"
      assert html =~ "75%"  # Profile completeness
      assert html =~ "Location Distribution"
      assert html =~ "england"
      assert html =~ "scotland"
    end
    
    test "support user sees limited interface" do
      support = user_fixture(%{role: :support})
      
      organization = %{
        id: "test-org-1",
        organization_name: "ACME Construction Ltd",
        email_domain: "acme.com",
        verified: true,
        profile_completeness_score: 0.85,
        core_profile: %{"industry_sector" => "construction"},
        inserted_at: ~U[2024-01-01 10:30:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: support,
          organization: organization,
          locations: [],
          organization_users: [],
          show_location_modal: false,
          editing_location: nil,
          selected_tab: "locations",
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&OrganizationDetailLive.render/1, socket.assigns)
      
      # Support users should not see admin-only buttons
      refute html =~ "Mark Verified"
      refute html =~ "Mark Unverified"
      refute html =~ "Add Location"
      refute html =~ "Add First Location"
    end
    
    test "tab navigation shows correct counts" do
      admin = user_fixture(%{role: :admin})
      
      organization = %{
        id: "test-org-1",
        organization_name: "ACME Construction Ltd",
        email_domain: "acme.com",
        verified: true,
        profile_completeness_score: 0.85,
        core_profile: %{"industry_sector" => "construction"},
        inserted_at: ~U[2024-01-01 10:30:00Z]
      }
      
      locations = [
        %{
          id: "loc-1", 
          location_name: "Main Office",
          location_type: :headquarters,
          geographic_region: "england",
          operational_status: :active, 
          is_primary_location: true,
          employee_count: 25,
          address: %{"street" => "100 Test St", "city" => "London", "postcode" => "SW1A 1AA"}
        }, 
        %{
          id: "loc-2", 
          location_name: "Branch Office",
          location_type: :branch_office,
          geographic_region: "scotland",
          operational_status: :active, 
          is_primary_location: false,
          employee_count: 10,
          address: %{"street" => "200 Test St", "city" => "Edinburgh", "postcode" => "EH1 1AA"}
        }
      ]
      users = []
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          organization: organization,
          locations: locations,
          organization_users: users,
          show_location_modal: false,
          editing_location: nil,
          selected_tab: "overview",
          __changed__: %{},
          flash: %{}
        }
      }
      
      html = render_component(&OrganizationDetailLive.render/1, socket.assigns)
      
      # Check tab counts
      assert html =~ "Locations (2)"
      assert html =~ "Users (0)"
    end
  end
end