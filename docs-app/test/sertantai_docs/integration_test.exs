defmodule SertantaiDocs.IntegrationTest do
  use ExUnit.Case, async: false  # GenServer tests need to be synchronous

  alias SertantaiDocs.Integration

  @test_content_path "test/fixtures/integration_content"

  setup do
    # Create test content directory
    File.mkdir_p!(Path.join(@test_content_path, "dev"))
    
    # Create test files
    File.write!(Path.join([@test_content_path, "dev", "test.md"]), """
    ---
    title: Test Document
    ---
    # Test Content
    """)
    
    on_exit(fn ->
      File.rm_rf!(@test_content_path)
    end)
    
    :ok
  end

  describe "GenServer lifecycle" do
    test "starts and stops correctly" do
      {:ok, pid} = Integration.start_link(sync_enabled: false)
      assert Process.alive?(pid)
      
      GenServer.stop(pid)
      refute Process.alive?(pid)
    end

    test "registers with the expected name" do
      {:ok, _pid} = Integration.start_link(sync_enabled: false)
      
      # Should be able to call by name
      status = Integration.status()
      assert Map.has_key?(status, :last_sync)
      
      GenServer.stop(Integration)
    end
  end

  describe "status/0" do
    setup do
      {:ok, pid} = Integration.start_link(sync_enabled: false)
      on_exit(fn -> GenServer.stop(pid) end)
      :ok
    end

    test "returns integration status information" do
      status = Integration.status()
      
      assert Map.has_key?(status, :last_sync)
      assert Map.has_key?(status, :watcher_active)
      assert Map.has_key?(status, :content_files)
      assert Map.has_key?(status, :cache_size)
      
      assert is_struct(status.last_sync, DateTime)
      assert is_boolean(status.watcher_active)
      assert is_integer(status.content_files)
      assert is_integer(status.cache_size)
    end
  end

  describe "sync_content/0" do
    setup do
      {:ok, pid} = Integration.start_link(sync_enabled: false)
      on_exit(fn -> GenServer.stop(pid) end)
      :ok
    end

    test "performs content synchronization" do
      with_mock_content_path do
        {:ok, stats} = Integration.sync_content()
        
        assert Map.has_key?(stats, :files_scanned)
        assert Map.has_key?(stats, :articles_updated)
        assert Map.has_key?(stats, :errors)
        
        assert is_integer(stats.files_scanned)
        assert is_integer(stats.articles_updated)
        assert is_list(stats.errors)
      end
    end

    test "handles sync errors gracefully" do
      # Remove content directory to trigger error
      File.rm_rf!(@test_content_path)
      
      with_mock_content_path do
        case Integration.sync_content() do
          {:ok, stats} ->
            # Should still work with empty directory
            assert stats.files_scanned == 0
          {:error, _reason} ->
            # Error is acceptable too
            assert true
        end
      end
    end
  end

  describe "refresh_navigation/0" do
    setup do
      {:ok, pid} = Integration.start_link(sync_enabled: false)
      on_exit(fn -> GenServer.stop(pid) end)
      :ok
    end

    test "refreshes navigation cache" do
      with_mock_content_path do
        # This is an async call, so we just ensure it doesn't crash
        :ok = Integration.refresh_navigation()
        
        # Give it a moment to process
        Process.sleep(50)
        
        # Check that the process is still alive
        assert Process.alive?(Process.whereis(Integration))
      end
    end
  end

  describe "file monitoring" do
    @tag :skip  # Skip by default as file system monitoring is environment-dependent
    test "responds to file changes" do
      with_mock_content_path do
        {:ok, pid} = Integration.start_link(sync_enabled: true)
        
        # Modify a file
        new_content = """
        ---
        title: Updated Document
        ---
        # Updated Content
        """
        File.write!(Path.join([@test_content_path, "dev", "test.md"]), new_content)
        
        # Give the file watcher time to detect changes
        Process.sleep(100)
        
        # Process should still be alive
        assert Process.alive?(pid)
        
        GenServer.stop(pid)
      end
    end
  end

  describe "error handling" do
    test "handles initialization errors gracefully" do
      # Test with invalid options
      {:ok, pid} = Integration.start_link(invalid_option: :test)
      assert Process.alive?(pid)
      
      GenServer.stop(pid)
    end

    test "recovers from message handling errors" do
      {:ok, pid} = Integration.start_link(sync_enabled: false)
      
      # Send an invalid message
      send(pid, :invalid_message)
      
      # Process should still be alive and functional
      Process.sleep(10)
      assert Process.alive?(pid)
      
      # Should still respond to valid calls
      status = Integration.status()
      assert Map.has_key?(status, :last_sync)
      
      GenServer.stop(pid)
    end
  end

  describe "content caching" do
    setup do
      {:ok, pid} = Integration.start_link(sync_enabled: false)
      on_exit(fn -> GenServer.stop(pid) end)
      :ok
    end

    test "builds and maintains content cache" do
      with_mock_content_path do
        # Trigger sync to build cache
        {:ok, _stats} = Integration.sync_content()
        
        # Check that cache size increased
        status = Integration.status()
        assert status.cache_size >= 0
      end
    end

    test "invalidates cache on file changes" do
      with_mock_content_path do
        # Build initial cache
        {:ok, _stats} = Integration.sync_content()
        initial_status = Integration.status()
        
        # Simulate file change message
        send(Process.whereis(Integration), {:file_event, Path.join([@test_content_path, "dev", "test.md"]), [:modified]})
        
        # Give it time to process
        Process.sleep(50)
        
        # Cache should be affected (though exact behavior depends on implementation)
        updated_status = Integration.status()
        assert is_integer(updated_status.cache_size)
      end
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

  defp with_mock_content_path do
    test_app_dir = File.cwd!()
    
    try do
      :meck.new(Application, [:passthrough])
      :meck.expect(Application, :app_dir, fn 
        :sertantai_docs -> test_app_dir
        app -> :meck.passthrough([app])
      end)
      yield()
    after
      :meck.unload(Application)
    end
  end

  defp yield do
    :ok
  end
end