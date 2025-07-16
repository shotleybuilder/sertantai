defmodule SertantaiWeb.Admin.AdminRouteIntegrationTest do
  @moduledoc """
  Integration tests for admin route authentication.
  
  These tests use the actual route and authentication pipeline to verify that
  admin users can access /admin routes and non-admin users cannot.
  
  Previously avoided due to memory issues, but now safe to test.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Sertantai.AccountsFixtures
  
  describe "admin route authentication" do
    test "admin user can access /admin route", %{conn: conn} do
      admin = user_fixture(%{role: :admin})
      
      conn = 
        conn
        |> log_in_user(admin)
        |> get(~p"/admin")
      
      # Should successfully access admin dashboard
      assert html_response(conn, 200)
      assert html_response(conn, 200) =~ "Admin Dashboard"
    end
    
    test "support user can access /admin route", %{conn: conn} do
      support = user_fixture(%{role: :support})
      
      conn = 
        conn
        |> log_in_user(support)
        |> get(~p"/admin")
      
      # Should successfully access admin dashboard
      assert html_response(conn, 200)
      assert html_response(conn, 200) =~ "Admin Dashboard"
    end
    
    test "professional user cannot access /admin route", %{conn: conn} do
      professional = user_fixture(%{role: :professional})
      
      conn = 
        conn
        |> log_in_user(professional)
        |> get(~p"/admin")
      
      # Should be redirected away from admin
      assert redirected_to(conn) == "/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "permission"
    end
    
    test "member user cannot access /admin route", %{conn: conn} do
      member = user_fixture(%{role: :member})
      
      conn = 
        conn
        |> log_in_user(member)
        |> get(~p"/admin")
      
      # Should be redirected away from admin
      assert redirected_to(conn) == "/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "permission"
    end
    
    test "guest user cannot access /admin route", %{conn: conn} do
      guest = user_fixture(%{role: :guest})
      
      conn = 
        conn
        |> log_in_user(guest)
        |> get(~p"/admin")
      
      # Should be redirected away from admin
      assert redirected_to(conn) == "/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "permission"
    end
    
    test "unauthenticated user cannot access /admin route", %{conn: conn} do
      conn = get(conn, ~p"/admin")
      
      # Should be redirected to login
      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "log in"
    end
  end
end