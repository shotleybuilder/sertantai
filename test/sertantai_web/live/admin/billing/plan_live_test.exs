defmodule SertantaiWeb.Admin.Billing.PlanLiveTest do
  use SertantaiWeb.ConnCase
  
  import Phoenix.LiveViewTest
  import Sertantai.BillingFixtures
  import Sertantai.AccountsFixtures
  
  alias Sertantai.Billing.Plan
  
  describe "Plan admin interface" do
    setup do
      admin_user = user_fixture(%{role: :admin})
      regular_user = user_fixture(%{role: :member})
      
      {:ok, admin_user: admin_user, regular_user: regular_user}
    end
    
    test "admin can access plan management", %{conn: conn, admin_user: admin_user} do
      conn = log_in_user(conn, admin_user)
      
      {:ok, _view, html} = live(conn, "/admin/billing/plans")
      
      assert html =~ "Billing Plans"
      assert html =~ "New Plan"
    end
    
    test "regular user cannot access plan management", %{conn: conn, regular_user: regular_user} do
      conn = log_in_user(conn, regular_user)
      
      # Should redirect to dashboard with error
      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, "/admin/billing/plans")
    end
    
    test "displays existing plans", %{conn: conn, admin_user: admin_user} do
      plan = plan_fixture(%{name: "Test Display Plan"})
      
      conn = log_in_user(conn, admin_user)
      {:ok, view, html} = live(conn, "/admin/billing/plans")
      
      assert html =~ "Test Display Plan"
      assert html =~ plan.stripe_price_id
      assert html =~ "$#{plan.amount}"
    end
    
    test "can create new plan", %{conn: conn, admin_user: admin_user} do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/billing/plans")
      
      # Click new plan button
      view |> element("a", "New Plan") |> render_click()
      
      # Fill out form
      view
      |> form("#plan-form", form: %{
        "name" => "New Test Plan",
        "stripe_price_id" => "price_new_test",
        "amount" => "39.99",
        "currency" => "usd",
        "interval" => "month",
        "user_role" => "professional",
        "active" => "true"
      })
      |> render_submit()
      
      # Should redirect back to index
      assert_redirect(view, "/admin/billing/plans")
      
      # Verify plan was created
      assert Plan |> Ash.Query.filter(name == "New Test Plan") |> Ash.read_one!()
    end
    
    test "validates required fields when creating plan", %{conn: conn, admin_user: admin_user} do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/billing/plans")
      
      view |> element("a", "New Plan") |> render_click()
      
      # Submit form with missing required fields
      html = view
        |> form("#plan-form", form: %{"name" => ""})
        |> render_submit()
      
      # Should show validation errors
      assert html =~ "is required"
    end
    
    test "can edit existing plan", %{conn: conn, admin_user: admin_user} do
      plan = plan_fixture(%{name: "Edit Test Plan"})
      
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/billing/plans")
      
      # Click edit button
      view |> element("a", "Edit") |> render_click()
      
      # Update plan
      view
      |> form("#plan-form", form: %{"name" => "Updated Plan Name"})
      |> render_submit()
      
      # Should redirect back to index
      assert_redirect(view, "/admin/billing/plans")
      
      # Verify plan was updated
      updated_plan = Ash.reload!(plan)
      assert updated_plan.name == "Updated Plan Name"
    end
    
    test "can toggle plan active status", %{conn: conn, admin_user: admin_user} do
      plan = plan_fixture(%{active: true})
      
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/billing/plans")
      
      # Click deactivate button
      view |> element("button", "Deactivate") |> render_click()
      
      # Verify plan was deactivated
      updated_plan = Ash.reload!(plan)
      assert updated_plan.active == false
      
      # Should show activate button now
      html = render(view)
      assert html =~ "Activate"
    end
    
    test "can delete plan", %{conn: conn, admin_user: admin_user} do
      plan = plan_fixture(%{name: "Delete Test Plan"})
      
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/billing/plans")
      
      # Click delete button (would need to handle confirmation)
      view |> element("button", "Delete") |> render_click()
      
      # Verify plan was deleted
      assert_raise Ash.Error.Query.NotFound, fn ->
        Ash.get!(Plan, plan.id)
      end
    end
    
    test "filters active plans correctly", %{conn: conn, admin_user: admin_user} do
      active_plan = plan_fixture(%{name: "Active Plan", active: true})
      inactive_plan = plan_fixture(%{name: "Inactive Plan", active: false})
      
      conn = log_in_user(conn, admin_user)
      {:ok, view, html} = live(conn, "/admin/billing/plans")
      
      # Both plans should be visible in admin view
      assert html =~ "Active Plan"
      assert html =~ "Inactive Plan"
      
      # Check status indicators
      assert html =~ "Active"
      assert html =~ "Inactive"
    end
  end
  
  # Helper function to simulate user login
  defp log_in_user(conn, user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Phoenix.ConnTest.put_session(:current_user_id, user.id)
    |> assign(:current_user, user)
  end
end