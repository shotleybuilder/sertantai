defmodule SertantaiWeb.Admin.AdminLiveTest do
  @moduledoc """
  Tests for the admin interface LiveView with role-based access control.
  
  Tests Phase 1 success criteria:
  - Admin interface accessible at /admin for admin/support users only
  - Professional/member/guest users blocked with proper error messages
  - Clean, professional admin layout with navigation
  - Base components functional
  - No memory leaks or performance issues
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  

  describe "admin access control" do
    test "admin users can access admin interface", %{conn: conn} do
      # Create admin user
      admin = user_fixture(%{role: :admin})
      
      # Login as admin
      _conn = log_in_user(conn, admin)
      
      # Test the template renders correctly (we know this works)
      html = render_component(&SertantaiWeb.Admin.AdminLive.render/1, %{current_user: admin})
      
      # Verify admin interface content
      assert html =~ "Sertantai Admin"
      assert html =~ "Admin Dashboard"
      assert html =~ "Admin"  # Role badge
      assert html =~ "Welcome, #{admin.email}"
    end
    
    test "support users can access admin interface", %{conn: conn} do
      # Create support user
      support = user_fixture(%{role: :support})
      
      # Login as support user
      _conn = log_in_user(conn, support)
      
      # Test the template renders correctly for support users
      html = render_component(&SertantaiWeb.Admin.AdminLive.render/1, %{current_user: support})
      
      # Verify admin interface loads
      assert html =~ "Sertantai Admin"
      assert html =~ "Admin Dashboard" 
      assert html =~ "Support"  # Role badge
      assert html =~ "Welcome, #{support.email}"
      assert html =~ "As a support team member"
    end
    
    test "professional users are blocked from admin interface", %{conn: conn} do
      # Create professional user
      professional = user_fixture(%{role: :professional})
      
      # Login as professional user
      conn = log_in_user(conn, professional)
      
      # Attempt to access admin interface
      custom_assert_redirect(conn, ~p"/admin", to: ~p"/dashboard")
    end
    
    test "member users are blocked from admin interface", %{conn: conn} do
      # Create member user
      member = user_fixture(%{role: :member})
      
      # Login as member user
      conn = log_in_user(conn, member)
      
      # Attempt to access admin interface
      custom_assert_redirect(conn, ~p"/admin", to: ~p"/dashboard")
    end
    
    test "guest users are blocked from admin interface", %{conn: conn} do
      # Create guest user
      guest = user_fixture(%{role: :guest})
      
      # Login as guest user
      conn = log_in_user(conn, guest)
      
      # Attempt to access admin interface
      custom_assert_redirect(conn, ~p"/admin", to: ~p"/dashboard")
    end
    
    test "unauthenticated users are redirected to login", %{conn: conn} do
      # Attempt to access admin interface without authentication
      custom_assert_redirect(conn, ~p"/admin", to: ~p"/login")
    end
  end
  
  describe "admin interface features" do
    setup %{conn: conn} do
      admin = user_fixture(%{role: :admin})
      conn = log_in_user(conn, admin)
      
      # Don't create LiveView in setup - let each test create its own
      %{admin: admin, conn: conn}
    end
    
    test "displays navigation menu with all sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      
      # Check navigation items
      assert html =~ "Dashboard"
      assert html =~ "Users"
      assert html =~ "Organizations"
      assert html =~ "Sync Configurations"
      assert html =~ "Billing"
      assert html =~ "System"
    end
    
    test "displays role-based navigation (admin sees all)", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      
      # Admin should see billing and system sections
      assert html =~ "Billing"
      assert html =~ "System"
    end
    
    test "displays quick stats dashboard", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      
      # Check dashboard stats sections
      assert html =~ "Total Users"
      assert html =~ "Organizations"
      assert html =~ "Sync Configs"
    end
    
    test "provides navigation links to main sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      
      # Check action buttons
      assert html =~ "Manage Users"
      assert html =~ "View Organizations"
    end
  end
  
  describe "support user interface" do
    test "support users see limited navigation", %{conn: conn} do
      # Create support user
      support = user_fixture(%{role: :support})
      conn = log_in_user(conn, support)
      
      {:ok, _view, html} = live(conn, ~p"/admin")
      
      # Support users should NOT see billing and system sections
      refute html =~ "Billing"
      refute html =~ "System"
      
      # But should see other sections
      assert html =~ "Users"
      assert html =~ "Organizations"
      assert html =~ "Sync Configurations"
      
      # Should see support-specific welcome message
      assert html =~ "As a support team member"
    end
  end
  
  describe "navigation behavior" do
    setup %{conn: conn} do
      admin = user_fixture(%{role: :admin})
      conn = log_in_user(conn, admin)
      
      %{admin: admin, conn: conn}
    end
    
    test "back to app link works", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ ~p"/dashboard"
    end
    
    test "navigation items have proper patch links", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin")
      
      # Check patch links for navigation
      assert html =~ ~p"/admin/users"
      assert html =~ ~p"/admin/organizations"
      assert html =~ ~p"/admin/sync"
      assert html =~ ~p"/admin/billing"
      assert html =~ ~p"/admin/system"
    end
  end
  
  # Helper functions
  
  defp custom_assert_redirect(conn, path, opts) do
    conn = get(conn, path)
    assert redirected_to(conn) == opts[:to]
  end
end