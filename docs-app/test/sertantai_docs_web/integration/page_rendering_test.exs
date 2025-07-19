defmodule SertantaiDocsWeb.PageRenderingTest do
  use SertantaiDocsWeb.ConnCase

  @moduledoc """
  Integration tests that verify complete page rendering behavior.
  These tests reproduce actual user interactions to catch rendering errors
  that unit tests might miss.
  """

  describe "complete page rendering" do
    test "root page renders without errors", %{conn: conn} do
      # This should reproduce the BadMapError we're seeing in production
      conn = get(conn, "/")
      
      # Should not return an error page
      refute String.contains?(response(conn, 200), "BadMapError")
      assert response(conn, 200) =~ "<html"
      assert response(conn, 200) =~ "Documentation"
    end

    test "dev category index renders without errors", %{conn: conn} do
      conn = get(conn, "/dev")
      
      # Should not return an error page
      refute String.contains?(response(conn, 200), "BadMapError")
      assert response(conn, 200) =~ "<html"
      assert response(conn, 200) =~ "Developer Documentation"
    end

    test "dev documentation-system page renders without errors", %{conn: conn} do
      conn = get(conn, "/dev/documentation-system")
      
      # Should not return an error page
      refute String.contains?(response(conn, 200), "BadMapError")
      assert response(conn, 200) =~ "<html"
      assert response(conn, 200) =~ "How the Documentation System Works"
    end

    test "user category index renders without errors", %{conn: conn} do
      conn = get(conn, "/user")
      
      # Should not return an error page  
      refute String.contains?(response(conn, 200), "BadMapError")
      assert response(conn, 200) =~ "<html"
      assert response(conn, 200) =~ "User"
    end
  end

  describe "error handling" do
    test "nonexistent page returns proper 404", %{conn: conn} do
      conn = get(conn, "/nonexistent/page")
      
      # Should return 404, not a server error
      assert response(conn, 404)
      refute String.contains?(response(conn, 404), "BadMapError")
    end

    test "nonexistent category returns proper error", %{conn: conn} do
      conn = get(conn, "/badcategory")
      
      # Should handle gracefully, not crash with BadMapError
      # Could be 404 or show fallback content
      assert conn.status in [200, 404]
      refute String.contains?(response(conn, conn.status), "BadMapError")
    end
  end

  describe "component rendering" do
    test "doc_header component renders with all required attributes", %{conn: conn} do
      # Test that our Petal Components work correctly
      conn = get(conn, "/dev")
      
      response_body = response(conn, 200)
      
      # Should contain header elements from doc_header component
      assert response_body =~ "<header"
      assert response_body =~ "Developer Documentation"
      refute String.contains?(response_body, "BadMapError")
    end

    test "doc_content component renders with nested content", %{conn: conn} do
      conn = get(conn, "/dev/documentation-system")
      
      response_body = response(conn, 200)
      
      # Should contain content wrapped by doc_content component
      assert response_body =~ "markdown-content"
      assert response_body =~ "How the Documentation System Works"
      refute String.contains?(response_body, "BadMapError")
    end
  end

  describe "template variable validation" do
    test "all required template variables are provided to index template", %{conn: conn} do
      # This will fail if we're missing required assigns
      conn = get(conn, "/")
      
      assert response(conn, 200)
      response_body = response(conn, 200)
      
      # Verify expected content exists (proves variables were passed correctly)
      assert response_body =~ "Documentation"
      refute String.contains?(response_body, "BadMapError")
      refute String.contains?(response_body, "assign @")  # No unresolved assigns
    end

    test "category template receives all required variables", %{conn: conn} do
      conn = get(conn, "/dev")
      
      assert response(conn, 200)  
      response_body = response(conn, 200)
      
      # Should have category-specific content
      assert response_body =~ "Developer"
      refute String.contains?(response_body, "BadMapError")
      refute String.contains?(response_body, "assign @")  # No unresolved assigns
    end

    test "show template receives all required variables", %{conn: conn} do
      conn = get(conn, "/dev/documentation-system")
      
      assert response(conn, 200)
      response_body = response(conn, 200)
      
      # Should have page-specific content
      assert response_body =~ "documentation system"
      refute String.contains?(response_body, "BadMapError") 
      refute String.contains?(response_body, "assign @")  # No unresolved assigns
    end
  end
end