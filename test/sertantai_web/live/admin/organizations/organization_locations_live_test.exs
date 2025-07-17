defmodule SertantaiWeb.Admin.Organizations.OrganizationLocationsLiveTest do
  @moduledoc """
  Tests for the OrganizationLocationsLive page that manages locations for a specific organization.
  
  Tests the new UI with clickable location names and conditional edit buttons.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  
  describe "organization locations management" do
    setup do
      # Create admin user
      admin = user_fixture(%{role: :admin})
      
      # Create test organization
      {:ok, organization} = Sertantai.Organizations.Organization
        |> Ash.Changeset.for_create(:create, %{
          organization_name: "Test Organization",
          email_domain: "test.com",
          created_by_user_id: admin.id,
          core_profile: %{
            "organization_name" => "Test Organization",
            "organization_type" => "limited_company",
            "headquarters_region" => "england",
            "industry_sector" => "technology"
          }
        })
        |> Ash.create(actor: admin)
      
      # Create test location
      {:ok, location} = Sertantai.Organizations.OrganizationLocation
        |> Ash.Changeset.for_create(:create, %{
          organization_id: organization.id,
          location_name: "Test Location",
          location_type: :headquarters,
          geographic_region: "london",
          operational_status: :active,
          is_primary_location: true,
          postcode: "SW1A 1AA",
          address: %{
            "street" => "123 Main Street",
            "city" => "London",
            "region" => "Greater London",
            "postcode" => "SW1A 1AA"
          }
        })
        |> Ash.create(actor: admin)
      
      %{admin: admin, organization: organization, location: location}
    end
    
    test "admin can mount organization locations page", %{conn: conn, admin: admin, organization: organization} do
      conn = log_in_user(conn, admin)
      
      assert {:ok, _view, html} = live(conn, "/admin/organizations/#{organization.id}/locations")
      
      assert html =~ "Location Management"
      assert html =~ organization.organization_name
      assert html =~ "Test Location"
    end
    
    test "location names are clickable links to edit modal", %{conn: conn, admin: admin, organization: organization, location: location} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/#{organization.id}/locations")
      
      # Click on the location name link
      html = view
        |> element("a[href*='/admin/organizations/#{organization.id}/locations/#{location.id}/edit']")
        |> render_click()
      
      # Should show the edit modal
      assert html =~ "Edit Location"
      assert html =~ "Test Location"
    end
    
    test "actions column is removed from table", %{conn: conn, admin: admin, organization: organization} do
      conn = log_in_user(conn, admin)
      
      {:ok, _view, html} = live(conn, "/admin/organizations/#{organization.id}/locations")
      
      # Should not have Actions column header in table
      refute html =~ "<th class=\"px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider\">\n                Actions\n              </th>"
      
      # Should not have standalone Edit or Delete buttons in table rows
      refute html =~ "<td class=\"px-6 py-4 whitespace-nowrap text-right text-sm font-medium"
    end
    
    test "single location selection shows edit button in bulk actions", %{conn: conn, admin: admin, organization: organization, location: location} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/#{organization.id}/locations")
      
      # Select a single location
      html = view
        |> element("input[type='checkbox'][phx-value-id='#{location.id}']")
        |> render_click()
      
      # Should show the Edit Location button in bulk actions
      assert html =~ "Edit Location"
      assert html =~ "1 location(s) selected"
      
      # The Edit Location button should link to the correct edit page
      assert html =~ "href=\"/admin/organizations/#{organization.id}/locations/#{location.id}/edit\""
    end
    
    test "multiple location selection does not show edit button", %{conn: conn, admin: admin, organization: organization} do
      conn = log_in_user(conn, admin)
      
      # Create a second location
      {:ok, _location2} = Sertantai.Organizations.OrganizationLocation
        |> Ash.Changeset.for_create(:create, %{
          organization_id: organization.id,
          location_name: "Second Location",
          location_type: :branch_office,
          geographic_region: "manchester",
          operational_status: :active,
          is_primary_location: false,
          postcode: "M1 1AA",
          address: %{
            "street" => "456 Oak Avenue",
            "city" => "Manchester",
            "region" => "Greater Manchester",
            "postcode" => "M1 1AA"
          }
        })
        |> Ash.create(actor: admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/#{organization.id}/locations")
      
      # Select both locations
      view
      |> element("input[type='checkbox'][phx-click='select_all']")
      |> render_click()
      
      html = view |> render()
      
      # Should show bulk actions but not the Edit Location button
      assert html =~ "2 location(s) selected"
      assert html =~ "Delete Selected"
      assert html =~ "Clear Selection"
      refute html =~ "Edit Location"
    end
    
    test "location names have proper hover styling", %{conn: conn, admin: admin, organization: organization} do
      conn = log_in_user(conn, admin)
      
      {:ok, _view, html} = live(conn, "/admin/organizations/#{organization.id}/locations")
      
      # Location names should be styled as clickable links
      assert html =~ "text-blue-600 hover:text-blue-900 hover:underline"
      assert html =~ "Test Location"
    end
    
    test "edit modal parameter mismatch is fixed", %{conn: conn, admin: admin, organization: organization, location: location} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/#{organization.id}/locations")
      
      # Navigate to edit modal via location name click - this should trigger the :edit action
      result = view
        |> element("a[href*='/admin/organizations/#{organization.id}/locations/#{location.id}/edit']")
        |> render_click()
      
      # The navigation should work without errors (no parameter mismatch)
      # If there was a parameter mismatch, this would raise an error
      assert result != nil
      
      # The page should still render correctly after the navigation
      html = view |> render()
      assert html =~ "Test Location"
    end
    
    test "bulk actions include icons for better UX", %{conn: conn, admin: admin, organization: organization, location: location} do
      conn = log_in_user(conn, admin)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/#{organization.id}/locations")
      
      # Select a location to show bulk actions
      html = view
        |> element("input[type='checkbox'][phx-value-id='#{location.id}']")
        |> render_click()
      
      # Should have SVG icons for Edit, Delete, and Clear actions
      assert html =~ "<svg class=\"mr-1 h-3 w-3\""
      assert html =~ "stroke-linecap=\"round\""
    end
    
    test "support user cannot delete locations but can edit", %{conn: conn, organization: organization, location: location} do
      support = user_fixture(%{role: :support})
      conn = log_in_user(conn, support)
      
      {:ok, view, _html} = live(conn, "/admin/organizations/#{organization.id}/locations")
      
      # Select a location
      html = view
        |> element("input[type='checkbox'][phx-value-id='#{location.id}']")
        |> render_click()
      
      # Should show Edit Location but not Delete Selected
      assert html =~ "Edit Location"
      refute html =~ "Delete Selected"
      assert html =~ "Clear Selection"
    end
  end
end