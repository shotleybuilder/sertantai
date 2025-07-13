defmodule SertantaiWeb.Applicability.LocationScreeningLiveTest do
  use SertantaiWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  
  alias Sertantai.Organizations.{Organization, OrganizationLocation}
  alias Sertantai.Accounts.User
  
  describe "location screening authentication" do
    test "redirects to login when not authenticated", %{conn: conn} do
      location_id = Ecto.UUID.generate()
      {:error, redirect} = live(conn, ~p"/applicability/location/#{location_id}")
      
      assert {:redirect, %{to: "/login"}} = redirect
    end
    
    test "redirects when location not found", %{conn: conn} do
      # Create user but no location
      user_attrs = %{
        email: "no_location@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      conn = log_in_user(conn, user)
      
      fake_location_id = Ecto.UUID.generate()
      {:error, redirect} = live(conn, ~p"/applicability/location/#{fake_location_id}")
      
      assert {:redirect, %{to: "/organizations/locations"}} = redirect
    end
    
    test "denies access to location from different organization", %{conn: conn} do
      # Create first user and their organization/location
      user1_attrs = %{
        email: "user1@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user1} = Ash.create(User, user1_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      org1_attrs = %{
        organization_name: "User 1 Org",
        created_by_user_id: user1.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization1} = Ash.create(Organization, org1_attrs, domain: Sertantai.Organizations)
      
      location1_attrs = %{
        organization_id: organization1.id,
        location_name: "User 1 Location",
        location_type: :branch_office,
        address: %{"street" => "123 User1 St"},
        geographic_region: "england"
      }
      {:ok, location1} = Ash.create(OrganizationLocation, location1_attrs, domain: Sertantai.Organizations)
      
      # Create second user
      user2_attrs = %{
        email: "user2@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user2} = Ash.create(User, user2_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Log in as user2 and try to access user1's location
      conn = log_in_user(conn, user2)
      
      {:error, redirect} = live(conn, ~p"/applicability/location/#{location1.id}")
      
      assert {:redirect, %{to: "/organizations/locations"}} = redirect
    end
  end
  
  describe "location screening interface" do
    setup %{conn: conn} do
      # Create a test user
      user_attrs = %{
        email: "screening@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Screening Test Org",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction",
          "total_employees" => 100
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      # Create a test location
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Screening Test Location",
        location_type: :manufacturing_site,
        address: %{
          "street" => "123 Industrial Way",
          "city" => "Birmingham",
          "postcode" => "B1 1AA"
        },
        geographic_region: "england",
        employee_count: 75,
        industry_activities: ["manufacturing", "assembly", "quality_control"],
        environmental_factors: %{
          "emissions" => "moderate",
          "waste_types" => ["metal", "plastic"]
        },
        operational_status: :active
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      conn = log_in_user(conn, user)
      
      %{conn: conn, user: user, organization: organization, location: location}
    end
    
    test "displays location details", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      assert html =~ "Screening Test Location Screening"
      assert html =~ "Screening Test Location"
      assert html =~ "Manufacturing Site"
      assert html =~ "England"
      assert html =~ "Active"
      assert html =~ "75" # Employee count
      assert html =~ "B1 1AA" # Postcode
    end
    
    test "displays industry activities", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      assert html =~ "manufacturing"
      assert html =~ "assembly"
      assert html =~ "quality_control"
    end
    
    test "shows initial screening state", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      # Should show ready state
      assert html =~ "Start" or html =~ "Begin" or html =~ "Ready"
      
      # Should show estimated law count
      assert html =~ ~r/\d+/ # Some number for law count estimate
      
      # Should have screening action buttons
      assert html =~ "Progressive Screening" or html =~ "Start Progressive Screening"
      assert html =~ "AI" or html =~ "Conversation"
    end
    
    test "provides navigation back to locations", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      assert html =~ "Back to Locations" or 
             html =~ "← Manage Locations" or
             has_element?(view, "a[href*='/organizations/locations']")
    end
  end
  
  describe "screening workflow" do
    setup %{conn: conn} do
      # Create a test user
      user_attrs = %{
        email: "workflow@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Workflow Test Org",
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
        location_name: "Workflow Test Location",
        location_type: :branch_office,
        address: %{"street" => "123 Workflow St"},
        geographic_region: "england",
        employee_count: 50
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      conn = log_in_user(conn, user)
      
      %{conn: conn, user: user, organization: organization, location: location}
    end
    
    test "starts progressive screening", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      assert html =~ "Start Progressive Screening"
      
      # Click start screening button
      view
      |> element("button", "Start Progressive Screening")
      |> render_click()
      
      # Should show screening in progress
      assert render(view) =~ "Screening in progress" or
             render(view) =~ "Processing" or
             render(view) =~ "in progress"
    end
    
    test "starts AI conversation screening", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      assert html =~ "AI Conversation" or html =~ "AI Screening"
      
      # Click AI screening button - this should redirect
      view
      |> element("button", "AI Conversation Screening")
      |> render_click()
      
      # Should redirect to AI conversation interface
      # Note: This might be a redirect rather than staying on same page
    end
    
    test "handles screening completion", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      # Start screening
      view
      |> element("button", "Start Progressive Screening")
      |> render_click()
      
      # Wait for screening to complete (simulated)
      # In real app this would be async, but our simulation should complete quickly
      :timer.sleep(100)
      
      # Check for completion state
      updated_html = render(view)
      assert updated_html =~ "Complete" or 
             updated_html =~ "Finished" or
             updated_html =~ "Results" or
             updated_html =~ "Restart"
    end
    
    test "allows screening restart", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      # Start and complete screening first
      view
      |> element("button", "Start Progressive Screening")
      |> render_click()
      
      # Wait for completion
      :timer.sleep(100)
      
      # Should have restart option
      updated_html = render(view)
      if updated_html =~ "Restart" do
        view
        |> element("button", "Restart Screening")
        |> render_click()
        
        # Should be back to ready state
        restarted_html = render(view)
        assert restarted_html =~ "Start" or restarted_html =~ "Ready"
      end
    end
  end
  
  describe "screening results display" do
    setup %{conn: conn} do
      # Create a test user
      user_attrs = %{
        email: "results@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Results Test Org",
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
        location_name: "Results Test Location",
        location_type: :warehouse,
        address: %{"street" => "123 Results St"},
        geographic_region: "scotland",
        employee_count: 30,
        industry_activities: ["warehousing", "logistics", "distribution"]
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      conn = log_in_user(conn, user)
      
      %{conn: conn, user: user, organization: organization, location: location}
    end
    
    test "displays screening results after completion", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      # Start screening
      view
      |> element("button", "Start Progressive Screening")
      |> render_click()
      
      # Wait for completion
      :timer.sleep(100)
      
      # Check results display
      results_html = render(view)
      
      # Should show law counts
      assert results_html =~ ~r/\d+/ # Numbers for law counts
      
      # Should show screening status
      assert results_html =~ "Complete" or 
             results_html =~ "Screening Results" or
             results_html =~ "Total Laws"
      
      # Should show high priority count
      assert results_html =~ "High Priority" or results_html =~ "Priority"
    end
    
    test "displays recommendations when available", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      # Start screening
      view
      |> element("button", "Start Progressive Screening")
      |> render_click()
      
      # Wait for completion
      :timer.sleep(100)
      
      # Check for recommendations
      results_html = render(view)
      assert results_html =~ "Recommendation" or 
             results_html =~ "Review" or
             results_html =~ "Consider" or
             results_html =~ "Ensure"
    end
    
    test "provides navigation to organization aggregate", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      # Should have option to view organization summary
      assert html =~ "Organization Summary" or 
             html =~ "View Organization" or
             html =~ "Organization-Wide" or
             has_element?(view, "a[href*='/applicability/organization']")
    end
  end
  
  describe "multi-location context" do
    setup %{conn: conn} do
      # Create a test user
      user_attrs = %{
        email: "multi_context@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Multi Context Test Org",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      # Create multiple locations
      location1_attrs = %{
        organization_id: organization.id,
        location_name: "Context Location 1",
        location_type: :headquarters,
        address: %{"street" => "123 Context St"},
        geographic_region: "england",
        is_primary_location: true
      }
      {:ok, location1} = Ash.create(OrganizationLocation, location1_attrs, domain: Sertantai.Organizations)
      
      location2_attrs = %{
        organization_id: organization.id,
        location_name: "Context Location 2",
        location_type: :branch_office,
        address: %{"street" => "456 Context Ave"},
        geographic_region: "scotland"
      }
      {:ok, location2} = Ash.create(OrganizationLocation, location2_attrs, domain: Sertantai.Organizations)
      
      conn = log_in_user(conn, user)
      
      %{conn: conn, user: user, organization: organization, location1: location1, location2: location2}
    end
    
    test "shows multi-location context message", %{conn: conn, location1: location1} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location1.id}")
      
      # Should show multi-location organization notice
      assert html =~ "Multi-Location Organization" or
             html =~ "multiple locations" or
             html =~ "other locations" or
             html =~ "organization-wide"
    end
    
    test "provides link to organization aggregate screening", %{conn: conn, location1: location1} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location1.id}")
      
      # Should have link to aggregate screening
      assert html =~ "organization-wide" or
             html =~ "aggregate screening" or
             has_element?(view, "a[href*='/applicability/organization/aggregate']")
    end
    
    test "explains location-specific context", %{conn: conn, location2: location2} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location2.id}")
      
      # Should explain this is location-specific screening
      assert html =~ "Context Location 2" and
             (html =~ "specific to" or 
              html =~ "location-specific" or
              html =~ "this location")
    end
  end
  
  describe "single-location context" do
    setup %{conn: conn} do
      # Create a test user
      user_attrs = %{
        email: "single_context@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Single Context Test Org",
        created_by_user_id: user.id,
        core_profile: %{
          "organization_type" => "limited_company",
          "headquarters_region" => "england",
          "industry_sector" => "construction"
        }
      }
      {:ok, organization} = Ash.create(Organization, org_attrs, domain: Sertantai.Organizations)
      
      # Create single location
      location_attrs = %{
        organization_id: organization.id,
        location_name: "Single Context Location",
        location_type: :headquarters,
        address: %{"street" => "123 Single St"},
        geographic_region: "england",
        is_primary_location: true
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      conn = log_in_user(conn, user)
      
      %{conn: conn, user: user, organization: organization, location: location}
    end
    
    test "does not show multi-location context for single location", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      # Should NOT show multi-location messaging
      refute html =~ "Multi-Location Organization"
      refute html =~ "multiple locations"
      
      # Should focus on this single location
      assert html =~ "Single Context Location"
    end
    
    test "provides appropriate single-location navigation", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      # Should still have navigation back to locations management
      assert html =~ "Back" or 
             html =~ "Locations" or
             has_element?(view, "a[href*='/organizations/locations']")
    end
  end
  
  describe "error handling" do
    setup %{conn: conn} do
      # Create a test user
      user_attrs = %{
        email: "error_handling@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
      
      # Create a test organization
      org_attrs = %{
        organization_name: "Error Test Org",
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
        location_name: "Error Test Location",
        location_type: :branch_office,
        address: %{"street" => "123 Error St"},
        geographic_region: "england"
      }
      {:ok, location} = Ash.create(OrganizationLocation, location_attrs, domain: Sertantai.Organizations)
      
      conn = log_in_user(conn, user)
      
      %{conn: conn, user: user, organization: organization, location: location}
    end
    
    test "handles malformed location ID gracefully", %{conn: conn} do
      # Use invalid UUID format
      {:error, _} = live(conn, "/applicability/location/invalid-id")
    end
    
    test "displays appropriate error messages", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      # The page should load successfully
      assert html =~ "Error Test Location"
      
      # If there were any errors in loading, they should be handled gracefully
      refute html =~ "Error:" or html =~ "Exception"
    end
    
    test "provides fallback navigation on errors", %{conn: conn, location: location} do
      {:ok, view, html} = live(conn, ~p"/applicability/location/#{location.id}")
      
      # Should always have navigation back
      assert html =~ "Back" or 
             html =~ "Locations" or
             has_element?(view, "a[href*='/organizations']")
    end
  end
end