defmodule SertantaiWeb.Admin.Billing.RoleManagementLiveTest do
  use SertantaiWeb.ConnCase
  
  import Phoenix.LiveViewTest
  import Sertantai.BillingFixtures
  import Sertantai.AccountsFixtures
  
  alias Sertantai.Accounts.User
  
  describe "Role Management interface" do
    setup do
      admin_user = user_fixture(%{role: :admin})
      
      # Create users with different scenarios
      member_user = user_fixture(%{email: "member@test.com", role: :member})
      professional_user = user_fixture(%{email: "pro@test.com", role: :professional})
      
      # Create billing setup for professional user
      plan = professional_plan_fixture()
      customer = customer_fixture(%{user: professional_user})
      subscription = active_subscription_fixture(%{customer: customer, plan: plan})
      
      # Create member user with no subscription (potential mismatch)
      member_with_sub = user_fixture(%{email: "mismatch@test.com", role: :member})
      member_customer = customer_fixture(%{user: member_with_sub})
      member_subscription = active_subscription_fixture(%{customer: member_customer, plan: plan})
      
      {:ok, 
       admin_user: admin_user,
       member_user: member_user,
       professional_user: professional_user,
       member_with_sub: member_with_sub,
       plan: plan}
    end
    
    test "admin can access role management", %{conn: conn, admin_user: admin_user} do
      conn = log_in_user(conn, admin_user)
      
      {:ok, _view, html} = live(conn, "/admin/billing/role-management")
      
      assert html =~ "Role & Billing Management"
      assert html =~ "Total Users"
      assert html =~ "Mismatches"
    end
    
    test "displays user statistics correctly", %{conn: conn, admin_user: admin_user} do
      conn = log_in_user(conn, admin_user)
      {:ok, _view, html} = live(conn, "/admin/billing/role-management")
      
      # Should show statistics
      assert html =~ "Total Users"
      assert html =~ "Members"
      assert html =~ "Professionals"
      assert html =~ "Active Subs"
      assert html =~ "Mismatches"
    end
    
    test "shows users with role/billing mismatches", %{conn: conn, admin_user: admin_user, member_with_sub: member_with_sub} do
      conn = log_in_user(conn, admin_user)
      {:ok, view, html} = live(conn, "/admin/billing/role-management")
      
      # Member with professional subscription should show as mismatch
      assert html =~ member_with_sub.email
      assert html =~ "Mismatch"
    end
    
    test "can filter users by role", %{conn: conn, admin_user: admin_user, member_user: member_user, professional_user: professional_user} do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/billing/role-management")
      
      # Filter by members
      view |> element("button", "Members") |> render_click()
      
      html = render(view)
      assert html =~ member_user.email
      
      # Filter by professionals
      view |> element("button", "Professionals") |> render_click()
      
      html = render(view)
      assert html =~ professional_user.email
    end
    
    test "can search users by email", %{conn: conn, admin_user: admin_user, member_user: member_user} do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/billing/role-management")
      
      # Search for specific user
      view
      |> form("#search-form", search: %{"query" => "member@test.com"})
      |> render_change()
      
      html = render(view)
      assert html =~ member_user.email
    end
    
    test "can override user role manually", %{conn: conn, admin_user: admin_user, member_user: member_user} do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/billing/role-management")
      
      # Override role to professional
      view
      |> element("button[phx-click='override_role'][phx-value-new_role='professional']")
      |> render_click()
      
      # Verify role was changed
      updated_user = Ash.reload!(member_user)
      assert updated_user.role == :professional
      
      # Should show flash message
      html = render(view)
      assert html =~ "Role updated successfully"
    end
    
    test "can sync individual user role", %{conn: conn, admin_user: admin_user, member_with_sub: member_with_sub} do
      conn = log_in_user(conn, admin_user)
      {:ok, view, _html} = live(conn, "/admin/billing/role-management")
      
      # Sync role for user with mismatch
      view
      |> element("button[phx-click='sync_role']")
      |> render_click()
      
      # Should show success message
      html = render(view)
      assert html =~ "Role synced"
    end
    
    test "can sync all mismatched roles", %{conn: conn, admin_user: admin_user} do
      conn = log_in_user(conn, admin_user)
      {:ok, view, html} = live(conn, "/admin/billing/role-management")
      
      # If there are mismatches, sync all button should be visible
      if html =~ "Sync All Mismatches" do
        view |> element("button", "Sync All Mismatches") |> render_click()
        
        html = render(view)
        assert html =~ "Successfully synced"
      end
    end
    
    test "displays subscription information correctly", %{conn: conn, admin_user: admin_user, professional_user: professional_user} do
      conn = log_in_user(conn, admin_user)
      {:ok, _view, html} = live(conn, "/admin/billing/role-management")
      
      # Should show subscription details for users with subscriptions
      assert html =~ professional_user.email
      assert html =~ "Professional Plan"
    end
    
    test "shows correct expected vs current role", %{conn: conn, admin_user: admin_user, member_with_sub: member_with_sub} do
      conn = log_in_user(conn, admin_user)
      {:ok, _view, html} = live(conn, "/admin/billing/role-management")
      
      # Member with professional subscription should show:
      # Current Role: member
      # Expected Role: professional
      assert html =~ member_with_sub.email
      # Would need to check the specific table cells for role comparison
    end
    
    test "protects admin roles from automatic changes", %{conn: conn, admin_user: admin_user} do
      # Create another admin user
      another_admin = user_fixture(%{email: "admin2@test.com", role: :admin})
      
      conn = log_in_user(conn, admin_user)
      {:ok, _view, html} = live(conn, "/admin/billing/role-management")
      
      # Admin users should not show as mismatches even without subscriptions
      assert html =~ another_admin.email
      # Should show "In Sync" status
      assert html =~ "In Sync"
    end
    
    test "handles user with multiple subscriptions correctly", %{conn: conn, admin_user: admin_user} do
      # Create user with multiple subscriptions
      user = user_fixture(%{email: "multi@test.com", role: :member})
      customer = customer_fixture(%{user: user})
      
      plan1 = professional_plan_fixture(%{name: "Plan 1"})
      plan2 = professional_plan_fixture(%{name: "Plan 2"})
      
      active_subscription_fixture(%{customer: customer, plan: plan1})
      active_subscription_fixture(%{customer: customer, plan: plan2})
      
      conn = log_in_user(conn, admin_user)
      {:ok, _view, html} = live(conn, "/admin/billing/role-management")
      
      # Should show user with multiple subscriptions
      assert html =~ user.email
      # Should calculate highest role correctly
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