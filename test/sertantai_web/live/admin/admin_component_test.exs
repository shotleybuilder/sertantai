defmodule SertantaiWeb.Admin.AdminComponentTest do
  @moduledoc """
  Safe component-level tests for admin interface.
  These tests use render_component and should not kill the terminal.
  
  See README.md in this directory for testing approach documentation.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  
  describe "admin component rendering" do
    test "admin users can render admin interface component" do
      # Create admin user
      admin = user_fixture(%{role: :admin})
      
      # Test the template renders correctly (we know this works)
      html = render_component(&SertantaiWeb.Admin.AdminLive.render/1, %{current_user: admin})
      
      # Verify admin interface content
      assert html =~ "Sertantai Admin"
      assert html =~ "Admin Dashboard"
      assert html =~ "Admin"  # Role badge
      assert html =~ "Welcome, #{admin.email}"
    end
    
    test "support users can render admin interface component" do
      # Create support user
      support = user_fixture(%{role: :support})
      
      # Test the template renders correctly for support users
      html = render_component(&SertantaiWeb.Admin.AdminLive.render/1, %{current_user: support})
      
      # Verify admin interface loads
      assert html =~ "Sertantai Admin"
      assert html =~ "Admin Dashboard" 
      assert html =~ "Support"  # Role badge
      assert html =~ "Welcome, #{support.email}"
      assert html =~ "As a support team member"
    end
    
    test "admin component shows all navigation sections" do
      admin = user_fixture(%{role: :admin})
      
      html = render_component(&SertantaiWeb.Admin.AdminLive.render/1, %{current_user: admin})
      
      # Check navigation items
      assert html =~ "Dashboard"
      assert html =~ "Users"
      assert html =~ "Organizations"
      assert html =~ "Sync Configurations"
      assert html =~ "Billing"
      assert html =~ "System"
    end
    
    test "support component shows limited navigation" do
      support = user_fixture(%{role: :support})
      
      html = render_component(&SertantaiWeb.Admin.AdminLive.render/1, %{current_user: support})
      
      # Check that support role is shown
      assert html =~ "Support"  # Role badge should show Support
      
      # Support users should NOT see billing and system navigation links
      # Look for the actual navigation links, not just the words
      refute html =~ ~r/<a[^>]*href="\/admin\/billing"[^>]*>.*Billing.*<\/a>/s
      refute html =~ ~r/<a[^>]*href="\/admin\/system"[^>]*>.*System.*<\/a>/s
      
      # But should see other sections as actual links
      assert html =~ ~r/<a[^>]*href="\/admin\/users"[^>]*>.*Users.*<\/a>/s
      assert html =~ ~r/<a[^>]*href="\/admin\/organizations"[^>]*>.*Organizations.*<\/a>/s
      assert html =~ ~r/<a[^>]*href="\/admin\/sync"[^>]*>.*Sync Configurations.*<\/a>/s
    end
  end
end