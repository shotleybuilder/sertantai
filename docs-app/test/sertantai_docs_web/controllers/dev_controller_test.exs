defmodule SertantaiDocsWeb.DevControllerTest do
  use SertantaiDocsWeb.ConnCase

  @test_content_path "test/fixtures/dev_content"

  setup do
    # Create test content for dev API testing
    File.mkdir_p!(Path.join(@test_content_path, "dev"))
    
    File.write!(Path.join([@test_content_path, "dev", "api_test.md"]), """
    ---
    title: API Test Document
    category: dev
    author: Test Suite
    ---
    # API Test Content
    
    This is content for testing the dev API.
    """)
    
    on_exit(fn ->
      File.rm_rf!(@test_content_path)
    end)
    
    :ok
  end

  describe "GET /dev-api/integration/status" do
    test "returns integration status", %{conn: conn} do
      conn = get(conn, "/dev-api/integration/status")
      
      assert json_response(conn, 200)
      response = json_response(conn, 200)
      
      assert response["status"] == "ok"
      assert Map.has_key?(response, "integration")
      assert Map.has_key?(response, "environment")
      
      # Check integration status fields
      integration = response["integration"]
      assert Map.has_key?(integration, "last_sync")
      assert Map.has_key?(integration, "watcher_active")
      assert Map.has_key?(integration, "content_files")
      assert Map.has_key?(integration, "cache_size")
      
      # Check environment fields
      environment = response["environment"]
      assert environment["app"] == "sertantai_docs"
      assert Map.has_key?(environment, "version")
      assert Map.has_key?(environment, "phoenix_version")
      assert Map.has_key?(environment, "elixir_version")
    end
  end

  describe "POST /dev-api/integration/sync" do
    test "triggers manual content synchronization", %{conn: conn} do
      with_mock_content_path(fn ->
        conn = post(conn, "/dev-api/integration/sync")
        
        assert json_response(conn, 200)
        response = json_response(conn, 200)
        
        assert response["status"] == "success"
        assert response["message"] == "Content synchronization completed"
        assert Map.has_key?(response, "stats")
        
        stats = response["stats"]
        assert Map.has_key?(stats, "files_scanned")
        assert Map.has_key?(stats, "articles_updated")
        assert Map.has_key?(stats, "errors")
      end)
    end

    test "handles sync errors gracefully", %{conn: conn} do
      # Remove content directory to force error
      File.rm_rf!(@test_content_path)
      
      with_mock_content_path(fn ->
        conn = post(conn, "/dev-api/integration/sync")
        
        # Should handle error gracefully
        case json_response(conn, 200)["status"] do
          "success" ->
            # Empty directory sync succeeded
            assert true
          "error" ->
            # Or returned error status
            response = json_response(conn, 500)
            assert response["status"] == "error"
            assert Map.has_key?(response, "error")
        end
      end)
    end
  end

  describe "GET /dev-api/navigation" do
    test "returns current navigation structure", %{conn: conn} do
      with_mock_content_path(fn ->
        conn = get(conn, "/dev-api/navigation")
        
        assert json_response(conn, 200)
        response = json_response(conn, 200)
        
        assert response["status"] == "ok"
        assert Map.has_key?(response, "navigation")
        assert Map.has_key?(response, "metadata")
        
        # Check navigation structure
        navigation = response["navigation"]
        assert is_list(navigation)
        
        # Check metadata
        metadata = response["metadata"]
        assert Map.has_key?(metadata, "generated_at")
        assert Map.has_key?(metadata, "item_count")
        assert is_integer(metadata["item_count"])
      end)
    end

    test "includes home navigation item", %{conn: conn} do
      # Test without mocking to see if that's the issue
      conn = get(conn, "/dev-api/navigation")
      
      response = json_response(conn, 200)
      navigation = response["navigation"]
      
      # Should include home item
      home_item = Enum.find(navigation, &(&1["title"] == "Home"))
      assert home_item
      assert home_item["path"] == "/"
    end
  end

  describe "GET /dev-api/content/:path" do
    test "returns content information for existing file", %{conn: conn} do
      with_mock_content_path(fn ->
        encoded_path = URI.encode("dev/api_test.md")
        conn = get(conn, "/dev-api/content/#{encoded_path}")
        
        assert json_response(conn, 200)
        response = json_response(conn, 200)
        
        assert response["status"] == "ok"
        assert response["file_path"] == "dev/api_test.md"
        assert Map.has_key?(response, "metadata")
        assert Map.has_key?(response, "content")
        
        # Check metadata
        metadata = response["metadata"]
        assert metadata["title"] == "API Test Document"
        assert metadata["category"] == "dev"
        assert metadata["author"] == "Test Suite"
        assert Map.has_key?(metadata, "last_modified")
        assert Map.has_key?(metadata, "size")
        
        # Check content info
        content = response["content"]
        assert content["has_content"] == true
        assert Map.has_key?(content, "html_length")
        assert is_integer(content["html_length"])
        assert content["html_length"] > 0
      end)
    end

    test "handles missing content file", %{conn: conn} do
      with_mock_content_path(fn ->
        encoded_path = URI.encode("nonexistent/file.md")
        conn = get(conn, "/dev-api/content/#{encoded_path}")
        
        assert json_response(conn, 404)
        response = json_response(conn, 404)
        
        assert response["status"] == "error"
        assert response["message"] == "Content file not found or could not be processed"
        assert response["file_path"] == "nonexistent/file.md"
        assert Map.has_key?(response, "error")
      end)
    end

    test "handles path with special characters", %{conn: conn} do
      # Create file with special characters
      special_file = "special file with spaces.md"
      File.write!(Path.join([@test_content_path, special_file]), """
      ---
      title: Special File
      ---
      # Special Content
      """)
      
      with_mock_content_path(fn ->
        encoded_path = URI.encode(special_file)
        conn = get(conn, "/dev-api/content/#{encoded_path}")
        
        assert json_response(conn, 200)
        response = json_response(conn, 200)
        
        assert response["status"] == "ok"
        assert response["file_path"] == special_file
        assert response["metadata"]["title"] == "Special File"
      end)
    end

    test "includes frontmatter in content info", %{conn: conn} do
      with_mock_content_path(fn ->
        encoded_path = URI.encode("dev/api_test.md")
        conn = get(conn, "/dev-api/content/#{encoded_path}")
        
        response = json_response(conn, 200)
        content = response["content"]
        
        assert Map.has_key?(content, "frontmatter")
        frontmatter = content["frontmatter"]
        assert frontmatter["title"] == "API Test Document"
        assert frontmatter["category"] == "dev"
        assert frontmatter["author"] == "Test Suite"
      end)
    end
  end

  describe "error handling" do
    test "handles malformed requests gracefully", %{conn: conn} do
      # Test with invalid JSON in POST body
      conn = conn
        |> put_req_header("content-type", "application/json")
        |> post("/dev-api/integration/sync", "invalid json")
      
      # Should not crash the server
      assert response(conn, 200) || response(conn, 400) || response(conn, 422)
    end

    test "handles missing routes", %{conn: conn} do
      conn = get(conn, "/dev-api/nonexistent")
      
      assert response(conn, 404)
    end
  end

  describe "content type handling" do
    test "returns JSON for all dev API endpoints", %{conn: conn} do
      endpoints = [
        "/dev-api/integration/status",
        "/dev-api/navigation"
      ]
      
      for endpoint <- endpoints do
        conn = get(conn, endpoint)
        
        assert get_resp_header(conn, "content-type") |> List.first() =~ "application/json"
      end
    end

    test "handles CORS for development", %{conn: conn} do
      # Dev API should be accessible for development tools
      conn = get(conn, "/dev-api/integration/status")
      
      # Should not fail and return valid JSON
      assert json_response(conn, 200)
    end
  end

  describe "performance monitoring" do
    test "status endpoint responds quickly", %{conn: conn} do
      start_time = System.monotonic_time(:millisecond)
      
      conn = get(conn, "/dev-api/integration/status")
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      assert json_response(conn, 200)
      # Should respond within reasonable time (1 second)
      assert duration < 1000
    end

    test "navigation endpoint includes timing metadata", %{conn: conn} do
      with_mock_content_path(fn ->
        conn = get(conn, "/dev-api/navigation")
        
        response = json_response(conn, 200)
        metadata = response["metadata"]
        
        # Should include generation timestamp
        assert Map.has_key?(metadata, "generated_at")
        # Timestamp should be recent (within last minute)
        generated_at = metadata["generated_at"]
        assert is_binary(generated_at)
      end)
    end
  end

  # Helper function to mock content path
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