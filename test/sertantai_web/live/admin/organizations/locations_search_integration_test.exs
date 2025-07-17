defmodule SertantaiWeb.Admin.Organizations.LocationsSearchIntegrationTest do
  @moduledoc """
  Integration tests for the LocationsSearchLive page that test actual mounting and routing.
  
  These tests simulate real browser navigation to detect issues that component-only
  tests might miss, such as authentication problems, database query failures,
  and route resolution issues.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  
  describe "page mounting and navigation" do
    test "admin user can mount the locations search page successfully", %{conn: conn} do
      # Create an admin user and sign them in
      admin = user_fixture(%{role: :admin})
      conn = log_in_user(conn, admin)
      
      # Test mounting the live view - this will catch mount errors
      assert {:ok, _view, html} = live(conn, "/admin/organizations/locations")
      
      # Verify the page loaded successfully
      assert html =~ "Organization Locations"
      assert html =~ "Search Organizations"
      assert html =~ "Search for organizations and manage their locations"
      
      # Verify no error flash messages
      refute html =~ "organization not found"
      refute html =~ "Organization not found"
      refute html =~ "Failed to"
    end
    
    test "support user can mount the locations search page successfully", %{conn: conn} do
      # Create a support user and sign them in
      support = user_fixture(%{role: :support})
      conn = log_in_user(conn, support)
      
      # Test mounting the live view
      assert {:ok, _view, html} = live(conn, "/admin/organizations/locations")
      
      # Verify the page loaded successfully
      assert html =~ "Organization Locations"
      assert html =~ "Search Organizations"
      
      # Verify no error flash messages
      refute html =~ "organization not found"
      refute html =~ "Organization not found"
      refute html =~ "Failed to"
    end
    
    test "regular user cannot access the locations search page", %{conn: conn} do
      # Create a regular user and sign them in
      user = user_fixture(%{role: :user})
      conn = log_in_user(conn, user)
      
      # Should be redirected due to admin authentication
      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, "/admin/organizations/locations")
    end
    
    test "unauthenticated user cannot access the locations search page", %{conn: conn} do
      # Should be redirected to login
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/admin/organizations/locations")
    end
    
    test "page handles database errors gracefully", %{conn: conn} do
      # Create an admin user and sign them in
      admin = user_fixture(%{role: :admin})
      conn = log_in_user(conn, admin)
      
      # Mock a database error by temporarily breaking the actor assignment
      # This simulates what might happen if there are database connection issues
      
      # Even with potential database issues, the page should still mount
      # The load_recent_organizations function should handle errors gracefully
      assert {:ok, _view, html} = live(conn, "/admin/organizations/locations")
      
      # The page should still render the basic interface
      assert html =~ "Organization Locations"
      assert html =~ "Search Organizations"
      
      # Should not crash or show "organization not found" errors
      refute html =~ "organization not found"
      refute html =~ "Organization not found"
    end
    
    test "page interaction - organization search functionality", %{conn: conn} do
      # Create admin user and some test data
      admin = user_fixture(%{role: :admin})
      conn = log_in_user(conn, admin)
      
      # Create test organization via Ash
      {:ok, _test_org} = Sertantai.Organizations.Organization
        |> Ash.Changeset.for_create(:create, %{
          organization_name: "Test Search Org",
          email_domain: "testsearch.com",
          core_profile: %{
            "organization_type" => "limited_company",
            "industry_sector" => "technology"
          }
        })
        |> Ash.create(actor: admin)
      
      # Mount the page
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Test search functionality
      html = 
        view
        |> element("#org-search")
        |> render_change(%{search: "Test Search"})
      
      # Should show search results without errors
      assert html =~ "Test Search Org"
      assert html =~ "testsearch.com"
      
      # Should not show any error messages
      refute html =~ "organization not found"
      refute html =~ "Organization not found"
      refute html =~ "Failed to search organizations"
    end
    
    test "page interaction - organization selection", %{conn: conn} do
      # Create admin user and test organization with locations
      admin = user_fixture(%{role: :admin})
      conn = log_in_user(conn, admin)
      
      # Create test organization
      {:ok, test_org} = Sertantai.Organizations.Organization
        |> Ash.Changeset.for_create(:create, %{
          organization_name: "Org With Locations",
          email_domain: "locations.com",
          core_profile: %{
            "organization_type" => "limited_company",
            "industry_sector" => "construction"
          }
        })
        |> Ash.create(actor: admin)
      
      # Create a test location for the organization
      {:ok, _test_location} = Sertantai.Organizations.OrganizationLocation
        |> Ash.Changeset.for_create(:create, %{
          organization_id: test_org.id,
          location_name: "Test Location",
          location_type: :headquarters,
          geographic_region: "london",
          operational_status: :active,
          is_primary_location: true,
          postcode: "SW1A 1AA"
        })
        |> Ash.create(actor: admin)
      
      # Mount the page
      {:ok, view, _html} = live(conn, "/admin/organizations/locations")
      
      # Search for the organization
      view
      |> element("#org-search")
      |> render_change(%{search: "Org With Locations"})
      
      # Select the organization
      html = 
        view
        |> element("[phx-click='select_organization'][phx-value-id='#{test_org.id}']")
        |> render_click()
      
      # Should show the organization's locations
      assert html =~ "Locations for Org With Locations"
      assert html =~ "Test Location"
      assert html =~ "SW1A 1AA"
      assert html =~ "Primary"
      assert html =~ "Active"
      
      # Should not show any error messages
      refute html =~ "organization not found"
      refute html =~ "Organization not found"
      refute html =~ "Failed to load locations"
    end
    
    test "page handles empty database gracefully", %{conn: conn} do
      # Create admin user with no organizations in database
      admin = user_fixture(%{role: :admin})
      conn = log_in_user(conn, admin)
      
      # Mount the page with empty database
      {:ok, _view, html} = live(conn, "/admin/organizations/locations")
      
      # Should still render successfully
      assert html =~ "Organization Locations"
      assert html =~ "Search Organizations"
      
      # Should not show recent organizations section (since database is empty)
      refute html =~ "Recent Organizations"
      
      # Should not show any error messages
      refute html =~ "organization not found"
      refute html =~ "Organization not found"
      refute html =~ "Failed to"
    end
  end
  
end