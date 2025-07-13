defmodule SertantaiWeb.Organization.ProfileLiveTest do
  use SertantaiWeb.ConnCase

  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  import Sertantai.OrganizationsFixtures

  alias Sertantai.Organizations.Organization

  describe "mount/3" do
    test "redirects to registration when user has no organization", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/organizations/register", flash: flash}}} = 
        live(conn, ~p"/organizations")
      
      assert flash["info"] == "You haven't registered an organization yet."
    end

    test "shows organization profile when user has organization", %{conn: conn} do
      user = user_fixture()
      organization = organization_fixture(%{created_by_user_id: user.id})
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/organizations")

      assert html =~ "Organization Profile"
      assert html =~ organization.organization_name
      assert html =~ organization.email_domain
      refute html =~ "You haven&#39;t registered an organization yet."
    end

    test "shows profile completeness percentage", %{conn: conn} do
      user = user_fixture()
      
      organization = organization_fixture(%{
        created_by_user_id: user.id,
        organization_attrs: %{
          "organization_name" => "Test Company",
          "organization_type" => "limited_company",
          "industry_sector" => "technology",
          "headquarters_region" => "united_kingdom",
          "total_employees" => 50
        }
      })
      
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/organizations")

      assert html =~ "Profile Completeness"
      # Profile completeness percentage will be calculated automatically
      assert html =~ "%"
    end
  end

  describe "editing organization" do
    setup do
      user = user_fixture()
      organization = organization_fixture(%{
        created_by_user_id: user.id,
        organization_attrs: %{
          "organization_name" => "Original Company",
          "organization_type" => "limited_company",
          "industry_sector" => "construction",
          "headquarters_region" => "england"
        }
      })
      %{user: user, organization: organization}
    end

    test "toggles edit mode", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/organizations")

      # Initially in view mode
      assert html =~ "Edit Profile"
      refute html =~ "Save Changes"

      # Click edit button
      html = view |> element("button", "Edit Profile") |> render_click()

      assert html =~ "Save Changes"
      assert html =~ "Cancel"
      refute html =~ "Edit Profile"
    end

    test "cancels edit mode", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/organizations")

      # Enter edit mode
      view |> element("button", "Edit Profile") |> render_click()

      # Cancel editing
      html = view |> element("button", "Cancel") |> render_click()

      assert html =~ "Edit Profile"
      refute html =~ "Save Changes"
    end

    test "saves organization changes", %{conn: conn, user: user, organization: organization} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/organizations")

      # Enter edit mode
      view |> element("button", "Edit Profile") |> render_click()

      # Submit form with changes
      html = 
        view
        |> form("#org-form", form: %{
          organization_name: "Updated Company Name",
          organization_type: "partnership",
          industry_sector: "technology",
          headquarters_region: "scotland",
          total_employees: "150"
        })
        |> render_submit()

      assert html =~ "Organization profile updated successfully!"
      assert html =~ "Updated Company Name"
      assert html =~ "Partnership"
      assert html =~ "Technology"
      assert html =~ "Scotland"

      # Verify changes persisted
      updated_org = Ash.get!(Organization, organization.id, domain: Sertantai.Organizations)
      assert updated_org.organization_name == "Updated Company Name"
      assert updated_org.core_profile["organization_type"] == "partnership"
      assert updated_org.core_profile["industry_sector"] == "technology"
      assert updated_org.core_profile["headquarters_region"] == "scotland"
      assert updated_org.core_profile["total_employees"] == 150
    end

    test "shows validation errors on invalid data", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/organizations")

      # Enter edit mode
      view |> element("button", "Edit Profile") |> render_click()

      # Submit form with invalid data (empty organization name)
      html = 
        view
        |> form("#org-form", form: %{
          organization_name: "",
          organization_type: "limited_company",
          industry_sector: "technology",
          headquarters_region: "england"
        })
        |> render_submit()

      assert html =~ "Failed to update organization profile"
    end
  end

  describe "quick actions" do
    test "shows links to applicability screening and records", %{conn: conn} do
      user = user_fixture()
      organization = organization_fixture(%{created_by_user_id: user.id})
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/organizations")

      assert html =~ "Run Applicability Screening"
      assert html =~ "View Records"
      assert html =~ ~p"/applicability/progressive"
      assert html =~ ~p"/records"
    end
  end

  describe "formatting helpers" do
    test "formats organization type correctly", %{conn: conn} do
      user = user_fixture()
      
      organization = organization_fixture(%{
        created_by_user_id: user.id,
        organization_attrs: %{
          "organization_name" => "Test Company",
          "organization_type" => "limited_liability_partnership",
          "industry_sector" => "financial_services",
          "headquarters_region" => "northern_ireland"
        }
      })
      
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/organizations")

      assert html =~ "Limited Liability Partnership"
      assert html =~ "Financial Services"  
      assert html =~ "Northern Ireland"
    end

    test "shows employee count with formatting", %{conn: conn} do
      user = user_fixture()
      
      organization = organization_fixture(%{
        created_by_user_id: user.id,
        organization_attrs: %{
          "organization_name" => "Big Company",
          "organization_type" => "limited_company",
          "industry_sector" => "manufacturing",
          "headquarters_region" => "england",
          "total_employees" => 1500
        }
      })
      
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/organizations")

      assert html =~ "1,500"
    end

    test "shows 'Not specified' for missing optional fields", %{conn: conn} do
      user = user_fixture()
      
      organization = organization_fixture(%{
        created_by_user_id: user.id,
        organization_attrs: %{
          "organization_name" => "Minimal Company",
          "organization_type" => "sole_trader",
          "industry_sector" => "retail",
          "headquarters_region" => "wales"
          # No total_employees specified
        }
      })
      
      conn = log_in_user(conn, user)

      {:ok, view, html} = live(conn, ~p"/organizations")

      assert html =~ "Not specified"
    end
  end

  describe "navigation behavior" do
    test "navigation link points to correct route", %{conn: conn} do
      # Test that /organizations is the correct entry point
      user = user_fixture()
      conn = log_in_user(conn, user)

      # User without organization should be redirected to register
      assert {:error, {:redirect, %{to: "/organizations/register", flash: flash}}} = 
        live(conn, ~p"/organizations")
      
      assert flash["info"] == "You haven't registered an organization yet."
    end

    test "user with organization sees profile immediately", %{conn: conn} do
      user = user_fixture()
      organization = organization_fixture(%{created_by_user_id: user.id})
      conn = log_in_user(conn, user)

      # User with organization should see profile
      {:ok, view, html} = live(conn, ~p"/organizations")
      
      assert html =~ "Organization Profile"
      assert html =~ organization.organization_name
      refute html =~ "register"
    end
  end
end