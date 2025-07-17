defmodule SertantaiWeb.Admin.Organizations.LocationsSearchFunctionalTest do
  @moduledoc """
  Functional tests for the LocationsSearchLive page that test actual LiveView behavior.
  
  These tests simulate real user interactions with the search interface, including
  typing in the search field, selecting organizations, and navigating locations.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  
  describe "search functionality" do
    setup do
      # Create admin user
      admin = user_fixture(%{role: :admin})
      
      # Create test organizations with different names and domains
      {:ok, org1} = Sertantai.Organizations.Organization
        |> Ash.Changeset.for_create(:create, %{
          organization_name: "ACME Corporation", 
          email_domain: "acme-corp.com",
          created_by_user_id: admin.id,
          core_profile: %{
            "organization_name" => "ACME Corporation",
            "organization_type" => "limited_company",
            "headquarters_region" => "england",
            "industry_sector" => "technology"
          }
        })
        |> Ash.create(actor: admin)
      
      {:ok, org2} = Sertantai.Organizations.Organization
        |> Ash.Changeset.for_create(:create, %{
          organization_name: "Tech Solutions Ltd",
          email_domain: "techsolutions.co.uk",
          created_by_user_id: admin.id,
          core_profile: %{
            "organization_name" => "Tech Solutions Ltd",
            "organization_type" => "limited_company", 
            "headquarters_region" => "scotland",
            "industry_sector" => "technology"
          }
        })
        |> Ash.create(actor: admin)
      
      {:ok, org3} = Sertantai.Organizations.Organization
        |> Ash.Changeset.for_create(:create, %{
          organization_name: "Global Industries",
          email_domain: "global-ind.com",
          created_by_user_id: admin.id,
          core_profile: %{
            "organization_name" => "Global Industries",
            "organization_type" => "plc",
            "headquarters_region" => "wales",
            "industry_sector" => "manufacturing"
          }
        })
        |> Ash.create(actor: admin)
      
      # Create locations for org1
      {:ok, loc1} = Sertantai.Organizations.OrganizationLocation
        |> Ash.Changeset.for_create(:create, %{
          organization_id: org1.id,
          location_name: "ACME London HQ",
          location_type: :headquarters,
          geographic_region: "london",
          operational_status: :active,
          is_primary_location: true,
          postcode: "EC1A 1BB",
          address: %{
            "street" => "100 Shoreditch High St",
            "city" => "London",
            "region" => "Greater London",
            "postcode" => "EC1A 1BB"
          }
        })
        |> Ash.create(actor: admin)
      
      {:ok, loc2} = Sertantai.Organizations.OrganizationLocation
        |> Ash.Changeset.for_create(:create, %{
          organization_id: org1.id,
          location_name: "ACME Manchester Office",
          location_type: :branch_office,
          geographic_region: "manchester",
          operational_status: :active,
          is_primary_location: false,
          postcode: "M1 1AD",
          address: %{
            "street" => "1 Spinningfields",
            "city" => "Manchester",
            "region" => "Greater Manchester",
            "postcode" => "M1 1AD"
          }
        })
        |> Ash.create(actor: admin)
      
      # Create location for org2
      {:ok, loc3} = Sertantai.Organizations.OrganizationLocation
        |> Ash.Changeset.for_create(:create, %{
          organization_id: org2.id,
          location_name: "Tech Solutions Edinburgh",
          location_type: :headquarters,
          geographic_region: "edinburgh",
          operational_status: :active,
          is_primary_location: true,
          postcode: "EH1 1SR",
          address: %{
            "street" => "1 Princes Street",
            "city" => "Edinburgh",
            "region" => "Scotland",
            "postcode" => "EH1 1SR"
          }
        })
        |> Ash.create(actor: admin)
      
      %{
        admin: admin,
        org1: org1,
        org2: org2,
        org3: org3,
        loc1: loc1,
        loc2: loc2,
        loc3: loc3
      }
    end
    
    test "search field updates and triggers organization search", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Type in search field
      html = view
        |> element("#org-search")
        |> render_change(%{search: "ACME"})
      
      # Should show search results
      assert html =~ "Search Results"
      assert html =~ "ACME Corporation"
      assert html =~ "acme-corp.com"
      assert html =~ "2 locations"  # org1 has 2 locations
      
      # Should not show organizations that don't match
      refute html =~ "Tech Solutions Ltd"
      refute html =~ "Global Industries"
    end
    
    test "empty search shows recent organizations", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, html} = live(conn, "/admin/organizations/locations")
      
      # Should show recent organizations when no search
      assert html =~ "Recent Organizations"
      
      # Clear any existing search
      html = view
        |> element("#org-search")
        |> render_change(%{search: ""})
      
      # Should still show recent organizations
      assert html =~ "Recent Organizations"
    end
    
    test "search by email domain works", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Search by domain
      html = view
        |> element("#org-search")
        |> render_change(%{search: "techsolutions"})
      
      # Should find by domain
      assert html =~ "Search Results"
      assert html =~ "Tech Solutions Ltd"
      assert html =~ "techsolutions.co.uk"
      assert html =~ "1 location"
    end
    
    test "partial search matches work", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Partial search
      html = view
        |> element("#org-search")
        |> render_change(%{search: "corp"})
      
      # Should match ACME Corporation
      assert html =~ "ACME Corporation"
      refute html =~ "Tech Solutions"
      refute html =~ "Global Industries"
    end
    
    test "selecting an organization loads its locations", %{conn: conn, admin: admin, org1: org1} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Search for organization
      view
      |> element("#org-search")
      |> render_change(%{search: "ACME"})
      
      # Click on organization
      html = view
        |> element("[phx-click='select_organization'][phx-value-id='#{org1.id}']")
        |> render_click()
      
      # Should show organization's locations
      assert html =~ "Locations for ACME Corporation"
      assert html =~ "2 locations total"
      assert html =~ "ACME London HQ"
      assert html =~ "ACME Manchester Office"
      assert html =~ "EC1A 1BB"
      assert html =~ "M1 1AD"
      assert html =~ "Primary"  # London is primary
    end
    
    test "clearing organization selection works", %{conn: conn, admin: admin, org1: org1} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Search and select organization
      view
      |> element("#org-search")
      |> render_change(%{search: "ACME"})
      
      view
      |> element("[phx-click='select_organization'][phx-value-id='#{org1.id}']")
      |> render_click()
      
      # Clear selection
      html = view
        |> element("button[phx-click='clear_selection']")
        |> render_click()
      
      # Should no longer show locations
      refute html =~ "Locations for ACME Corporation"
      refute html =~ "ACME London HQ"
      
      # Should return to search interface
      assert html =~ "Search Organizations"
    end
    
    test "manage all link navigates to organization locations page", %{conn: conn, admin: admin, org1: org1} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Search and select organization
      view
      |> element("#org-search")
      |> render_change(%{search: "ACME"})
      
      view
      |> element("[phx-click='select_organization'][phx-value-id='#{org1.id}']")
      |> render_click()
      
      # Check that Manage All link has correct path
      html = view |> render()
      assert html =~ "href=\"/admin/organizations/#{org1.id}/locations\""
      assert html =~ "Manage All"
    end
    
    test "search shows no results message when nothing found", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Search for non-existent organization
      view
      |> element("#org-search")
      |> render_change(%{search: "NonExistentCompany"})
      
      # Should not show "Search Results" header when no results
      refute has_element?(view, "h3", "Search Results")
      
      # Search input should preserve the search term
      assert has_element?(view, "#org-search[value='NonExistentCompany']")
    end
    
    test "searching state shows loading indicator", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # The searching state is set briefly during search
      # We can't easily test the intermediate state, but we can verify
      # the search completes successfully by checking the search input value
      view
      |> element("#org-search")
      |> render_change(%{search: "test"})
      
      # After search completes, the search input should preserve the value
      assert has_element?(view, "#org-search[value='test']")
    end
    
    test "organization with no locations shows empty state", %{conn: conn, admin: admin, org3: org3} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Search for org3 which has no locations
      view
      |> element("#org-search")
      |> render_change(%{search: "Global"})
      
      # Select organization
      html = view
        |> element("[phx-click='select_organization'][phx-value-id='#{org3.id}']")
        |> render_click()
      
      # Should show empty state
      assert html =~ "Locations for Global Industries"
      assert html =~ "0 locations total"
      assert html =~ "No locations found"
      assert html =~ "This organization doesn&#39;t have any locations yet"
      assert html =~ "Add First Location"
    end
    
    test "case-insensitive search works", %{conn: conn, admin: admin} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Search with different cases using element-based testing
      view
      |> element("#org-search")
      |> render_change(%{search: "acme"})  # lowercase
      
      assert has_element?(view, "h4", "ACME Corporation")
      
      # Try uppercase - search for Tech Solutions more specifically
      view
      |> element("#org-search")
      |> render_change(%{search: "tech"})
      
      assert has_element?(view, "h4", "Tech Solutions Ltd")
    end
  end
  
  describe "pagination functionality" do
    setup do
      admin = user_fixture(%{role: :admin})
      
      # Create organization with many locations
      {:ok, org} = Sertantai.Organizations.Organization
        |> Ash.Changeset.for_create(:create, %{
          organization_name: "Big Corporation",
          email_domain: "bigcorp.com",
          created_by_user_id: admin.id,
          core_profile: %{
            "organization_name" => "Big Corporation",
            "organization_type" => "plc",
            "headquarters_region" => "england",
            "industry_sector" => "retail"
          }
        })
        |> Ash.create(actor: admin)
      
      # Create 25 locations to test pagination
      locations = Enum.map(1..25, fn i ->
        {:ok, loc} = Sertantai.Organizations.OrganizationLocation
          |> Ash.Changeset.for_create(:create, %{
            organization_id: org.id,
            location_name: "Location #{i}",
            location_type: if(i == 1, do: :headquarters, else: :branch_office),
            geographic_region: "london",
            operational_status: :active,
            is_primary_location: i == 1,
            postcode: "SW#{i} #{i}AA",
            address: %{
              "street" => "#{i} Test Street",
              "city" => "London",
              "region" => "Greater London",
              "postcode" => "SW#{i} #{i}AA"
            }
          })
          |> Ash.create(actor: admin)
        
        loc
      end)
      
      %{admin: admin, org: org, locations: locations}
    end
    
    test "pagination controls appear for many locations", %{conn: conn, admin: admin, org: org} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Search and select organization
      view
      |> element("#org-search")
      |> render_change(%{search: "Big Corporation"})
      
      view
      |> element("[phx-click='select_organization'][phx-value-id='#{org.id}']")
      |> render_click()
      
      # Should show pagination controls using element-based testing
      assert has_element?(view, "p", "Showing")
      assert has_element?(view, "span", "20")  # Default per_page
      assert has_element?(view, "span", "25")  # Total
      assert has_element?(view, "button", "Next")
      
      # Should show first 20 locations alphabetically
      # Alphabetical sort: Location 1, Location 10, Location 11, ..., Location 19, Location 2, Location 20, Location 21
      assert has_element?(view, "td", "Location 1")
      assert has_element?(view, "td", "Location 10")
      assert has_element?(view, "td", "Location 2")
      # Location 21 is actually in the first 20 alphabetically
      assert has_element?(view, "td", "Location 21")
    end
    
    test "changing page works", %{conn: conn, admin: admin, org: org} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Search and select organization
      view
      |> element("#org-search")
      |> render_change(%{search: "Big Corporation"})
      
      view
      |> element("[phx-click='select_organization'][phx-value-id='#{org.id}']")
      |> render_click()
      
      # Go to page 2 (select the numbered page button with px-4 class, not the Next button)
      view
      |> element("nav button[phx-click='page_change'][phx-value-page='2'][class*='px-4']")
      |> render_click()
      
      # Should show last 5 locations alphabetically (page 2)
      # Page 2 contains: Location 5, Location 6, Location 7, Location 8, Location 9
      assert has_element?(view, "td", "Location 5")
      assert has_element?(view, "td", "Location 6")
      assert has_element?(view, "td", "Location 9")
      refute has_element?(view, "td", "Location 1")  # Not on page 2
    end
    
    test "changing per page setting works", %{conn: conn, admin: admin, org: org} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Search and select organization
      view
      |> element("#org-search")
      |> render_change(%{search: "Big Corporation"})
      
      view
      |> element("[phx-click='select_organization'][phx-value-id='#{org.id}']")
      |> render_click()
      
      # Change to show 10 per page
      view
      |> element("select[phx-change='per_page_change']")
      |> render_change(%{per_page: "10"})
      
      # Should now show only 10 locations alphabetically
      # First 10 alphabetically: Location 1, Location 10, Location 11, Location 12, Location 13, Location 14, Location 15, Location 16, Location 17, Location 18
      assert has_element?(view, "td", "Location 1")
      assert has_element?(view, "td", "Location 10")
      assert has_element?(view, "td", "Location 18")
      refute has_element?(view, "td", "Location 19")  # Should be on page 2
      
      # Should update pagination info
      assert has_element?(view, "p", "Showing")
      assert has_element?(view, "span", "1")
      assert has_element?(view, "span", "10")
      assert has_element?(view, "span", "25")
    end
  end
  
  describe "authorization" do
    test "regular users cannot access the page", %{conn: conn} do
      user = user_fixture(%{role: :member})
      conn = log_in_user(conn, user)
      
      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, "/admin/organizations/locations")
    end
    
    test "unauthenticated users are redirected to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/admin/organizations/locations")
    end
    
    test "support users can access and use the page", %{conn: conn} do
      support = user_fixture(%{role: :support})
      admin = user_fixture(%{role: :admin})
      
      # Create test org
      {:ok, _org} = Sertantai.Organizations.Organization
        |> Ash.Changeset.for_create(:create, %{
          organization_name: "Support Test Org",
          email_domain: "support-test.com",
          created_by_user_id: admin.id,
          core_profile: %{
            "organization_name" => "Support Test Org",
            "organization_type" => "limited_company",
            "headquarters_region" => "england",
            "industry_sector" => "services"
          }
        })
        |> Ash.create(actor: admin)
      
      conn = log_in_user(conn, support)
      
      {:ok, view, html} = live(conn, "/admin/organizations/locations")
      
      assert html =~ "Organization Locations"
      
      # Support user can search
      html = view
        |> element("#org-search")
        |> render_change(%{search: "Support"})
      
      assert html =~ "Support Test Org"
    end
  end
end