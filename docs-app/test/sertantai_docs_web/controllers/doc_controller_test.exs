defmodule SertantaiDocsWeb.DocControllerTest do
  use SertantaiDocsWeb.ConnCase

  @test_content_path "test/fixtures/content"

  setup do
    # Create test content directory structure
    File.mkdir_p!(Path.join(@test_content_path, "dev"))
    File.mkdir_p!(Path.join(@test_content_path, "user"))
    
    # Create test content files
    File.write!(Path.join([@test_content_path, "index.md"]), """
    ---
    title: Documentation Home
    ---
    # Welcome to Sertantai Docs
    
    This is the main documentation page.
    """)
    
    File.write!(Path.join([@test_content_path, "dev", "index.md"]), """
    ---
    title: Developer Guide
    category: dev
    ---
    # Developer Documentation
    
    Guide for developers.
    """)
    
    File.write!(Path.join([@test_content_path, "dev", "setup.md"]), """
    ---
    title: Setup Guide
    category: dev
    ---
    # Setup Instructions
    
    How to set up the development environment.
    """)
    
    File.write!(Path.join([@test_content_path, "user", "index.md"]), """
    ---
    title: User Guide
    category: user
    ---
    # User Documentation
    
    Guide for end users.
    """)
    
    on_exit(fn ->
      File.rm_rf!(@test_content_path)
    end)
    
    :ok
  end

  describe "GET /" do
    test "renders the documentation home page", %{conn: conn} do
      with_mock_content_path do
        conn = get(conn, ~p"/")
        
        assert html_response(conn, 200)
        response_body = html_response(conn, 200)
        assert response_body =~ "Welcome to Sertantai Docs"
        assert response_body =~ "documentation-home"
      end
    end

    test "handles missing index.md gracefully", %{conn: conn} do
      # Remove the index file
      File.rm!(Path.join(@test_content_path, "index.md"))
      
      with_mock_content_path do
        conn = get(conn, ~p"/")
        
        assert html_response(conn, 200)
        response_body = html_response(conn, 200)
        assert response_body =~ "Documentation not found"
      end
    end
  end

  describe "GET /:category" do
    test "renders category index page", %{conn: conn} do
      with_mock_content_path do
        conn = get(conn, ~p"/dev")
        
        assert html_response(conn, 200)
        response_body = html_response(conn, 200)
        assert response_body =~ "Developer Documentation"
        assert response_body =~ "category-index"
      end
    end

    test "handles missing category index", %{conn: conn} do
      with_mock_content_path do
        conn = get(conn, ~p"/api")  # Non-existent category
        
        assert html_response(conn, 200)
        response_body = html_response(conn, 200)
        assert response_body =~ "Documentation not found"
      end
    end

    test "renders breadcrumb navigation", %{conn: conn} do
      with_mock_content_path do
        conn = get(conn, ~p"/dev")
        
        response_body = html_response(conn, 200)
        assert response_body =~ "Documentation"  # Root breadcrumb
        assert response_body =~ "Dev"           # Category breadcrumb
      end
    end
  end

  describe "GET /:category/:page" do
    test "renders specific documentation page", %{conn: conn} do
      with_mock_content_path do
        conn = get(conn, ~p"/dev/setup")
        
        assert html_response(conn, 200)
        response_body = html_response(conn, 200)
        assert response_body =~ "Setup Instructions"
        assert response_body =~ "How to set up the development environment"
      end
    end

    test "handles missing page gracefully", %{conn: conn} do
      with_mock_content_path do
        conn = get(conn, ~p"/dev/nonexistent")
        
        assert html_response(conn, 200)
        response_body = html_response(conn, 200)
        assert response_body =~ "Documentation not found"
      end
    end

    test "renders page with breadcrumb navigation", %{conn: conn} do
      with_mock_content_path do
        conn = get(conn, ~p"/dev/setup")
        
        response_body = html_response(conn, 200)
        assert response_body =~ "Documentation"  # Root breadcrumb
        assert response_body =~ "Dev"           # Category breadcrumb
        assert response_body =~ "Setup"         # Page breadcrumb
      end
    end

    test "processes markdown content correctly", %{conn: conn} do
      with_mock_content_path do
        conn = get(conn, ~p"/dev/setup")
        
        response_body = html_response(conn, 200)
        assert response_body =~ "<h1>Setup Instructions</h1>"
        assert response_body =~ "<p>How to set up"
        assert response_body =~ "markdown-content"  # Content wrapper
        assert response_body =~ ~s(data-title="Setup Guide")  # Metadata injection
      end
    end
  end

  describe "error handling" do
    test "handles file system errors gracefully", %{conn: conn} do
      # Remove entire content directory
      File.rm_rf!(@test_content_path)
      
      with_mock_content_path do
        conn = get(conn, ~p"/")
        
        assert html_response(conn, 200)
        response_body = html_response(conn, 200)
        assert response_body =~ "Documentation not found"
      end
    end

    test "handles invalid paths", %{conn: conn} do
      with_mock_content_path do
        # Test path with directory traversal attempt
        conn = get(conn, "/../../etc/passwd")
        
        # Should be handled by Phoenix routing, but let's ensure no errors
        assert response(conn, 404) || html_response(conn, 200)
      end
    end
  end

  describe "content metadata" do
    test "displays page title from frontmatter", %{conn: conn} do
      with_mock_content_path do
        conn = get(conn, ~p"/dev/setup")
        
        response_body = html_response(conn, 200)
        assert response_body =~ "Setup Guide"  # Title from frontmatter
      end
    end

    test "injects metadata as data attributes", %{conn: conn} do
      with_mock_content_path do
        conn = get(conn, ~p"/dev/setup")
        
        response_body = html_response(conn, 200)
        assert response_body =~ ~s(data-title="Setup Guide")
        assert response_body =~ ~s(data-category="dev")
      end
    end
  end

  describe "navigation integration" do
    test "includes sidebar navigation", %{conn: conn} do
      with_mock_content_path do
        conn = get(conn, ~p"/")
        
        response_body = html_response(conn, 200)
        assert response_body =~ "Sertantai Docs"  # Site title
        # Navigation should be rendered in the layout
      end
    end

    test "includes search functionality", %{conn: conn} do
      with_mock_content_path do
        conn = get(conn, ~p"/")
        
        response_body = html_response(conn, 200)
        assert response_body =~ "search"  # Search component
      end
    end
  end

  # Helper function to mock the content path
  defp with_mock_content_path(fun) do
    test_app_dir = File.cwd!()
    
    try do
      :meck.new(Application, [:passthrough])
      :meck.expect(Application, :app_dir, fn 
        :sertantai_docs -> test_app_dir
        app -> :meck.passthrough([app])
      end)
      fun.()
    after
      :meck.unload(Application)
    end
  end
end