defmodule SertantaiDocs.CrossRef.ExDocIntegrationTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.CrossRef.ExDocIntegration

  describe "setup_exdoc_integration/1" do
    test "configures ExDoc output path correctly" do
      config = %{
        output_path: "/docs/api",
        source_url: "https://github.com/example/project",
        homepage_url: "https://example.com",
        main: "README"
      }
      
      result = ExDocIntegration.setup_exdoc_integration(config)
      
      assert result.configured == true
      assert result.output_path == "/docs/api"
      assert result.base_url == "/api/docs"
      assert result.assets_path == "/docs/api/assets"
    end

    test "validates ExDoc configuration" do
      invalid_config = %{
        output_path: nil,
        source_url: "invalid-url"
      }
      
      result = ExDocIntegration.setup_exdoc_integration(invalid_config)
      
      assert result.configured == false
      assert result.errors != []
      assert "Invalid output_path" in result.errors
      assert "Invalid source_url" in result.errors
    end

    test "creates necessary directories and files" do
      config = %{
        output_path: "/tmp/test_docs/api",
        create_directories: true
      }
      
      result = ExDocIntegration.setup_exdoc_integration(config)
      
      assert result.directories_created == true
      assert File.exists?("/tmp/test_docs/api")
      
      # Cleanup
      File.rm_rf("/tmp/test_docs")
    end
  end

  describe "generate_exdoc_links/2" do
    test "generates correct links for Elixir core modules" do
      cross_refs = [
        %{type: :exdoc, target: "Enum"},
        %{type: :exdoc, target: "GenServer"},
        %{type: :exdoc, target: "Agent"}
      ]
      
      options = %{
        elixir_docs_url: "https://hexdocs.pm/elixir"
      }
      
      results = ExDocIntegration.generate_exdoc_links(cross_refs, options)
      
      enum_result = Enum.find(results, &(&1.target == "Enum"))
      assert enum_result.url == "https://hexdocs.pm/elixir/Enum.html"
      assert enum_result.external == true
      assert enum_result.core_module == true
      
      genserver_result = Enum.find(results, &(&1.target == "GenServer"))
      assert genserver_result.url == "https://hexdocs.pm/elixir/GenServer.html"
    end

    test "generates links for project modules" do
      cross_refs = [
        %{type: :exdoc, target: "SertantaiDocs.Navigation.Scanner"},
        %{type: :exdoc, target: "SertantaiDocs.TOC.Generator"}
      ]
      
      options = %{
        project_docs_path: "/api/docs",
        project_name: "sertantai_docs"
      }
      
      results = ExDocIntegration.generate_exdoc_links(cross_refs, options)
      
      scanner_result = Enum.find(results, &(&1.target == "SertantaiDocs.Navigation.Scanner"))
      assert scanner_result.url == "/api/docs/SertantaiDocs.Navigation.Scanner.html"
      assert scanner_result.external == false
      assert scanner_result.project_module == true
      
      generator_result = Enum.find(results, &(&1.target == "SertantaiDocs.TOC.Generator"))
      assert generator_result.url == "/api/docs/SertantaiDocs.TOC.Generator.html"
    end

    test "handles dependency modules correctly" do
      cross_refs = [
        %{type: :exdoc, target: "Phoenix.LiveView"},
        %{type: :exdoc, target: "Ecto.Schema"},
        %{type: :exdoc, target: "Plug.Conn"}
      ]
      
      options = %{
        dependency_docs: %{
          "phoenix_live_view" => "https://hexdocs.pm/phoenix_live_view",
          "ecto" => "https://hexdocs.pm/ecto",
          "plug" => "https://hexdocs.pm/plug"
        }
      }
      
      results = ExDocIntegration.generate_exdoc_links(cross_refs, options)
      
      liveview_result = Enum.find(results, &(&1.target == "Phoenix.LiveView"))
      assert liveview_result.url == "https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html"
      assert liveview_result.dependency == "phoenix_live_view"
      
      ecto_result = Enum.find(results, &(&1.target == "Ecto.Schema"))
      assert ecto_result.url == "https://hexdocs.pm/ecto/Ecto.Schema.html"
      assert ecto_result.dependency == "ecto"
    end

    test "detects missing modules and provides suggestions" do
      cross_refs = [
        %{type: :exdoc, target: "NonExistent.Module"},
        %{type: :exdoc, target: "Sertantai.Typo.Module"}  # Typo in existing module
      ]
      
      options = %{}
      
      results = ExDocIntegration.generate_exdoc_links(cross_refs, options)
      
      missing_result = Enum.find(results, &(&1.target == "NonExistent.Module"))
      assert missing_result.exists == false
      assert missing_result.error == "Module not found"
      assert missing_result.suggestions == []
      
      typo_result = Enum.find(results, &(&1.target == "Sertantai.Typo.Module"))
      assert typo_result.exists == false
      assert typo_result.suggestions != []
      assert "SertantaiDocs.Navigation.Scanner" in typo_result.suggestions
    end
  end

  describe "extract_module_info/2" do
    test "extracts information from Elixir core modules" do
      info = ExDocIntegration.extract_module_info("Enum", %{})
      
      assert info.exists == true
      assert info.module_type == "core"
      assert info.description != nil
      assert info.functions != []
      assert "map/2" in info.functions
      assert "filter/2" in info.functions
      assert info.examples != []
    end

    test "extracts information from project modules" do
      info = ExDocIntegration.extract_module_info("SertantaiDocs.Navigation.Scanner", %{})
      
      assert info.exists == true
      assert info.module_type == "project"
      assert info.description != nil
      assert info.functions != []
      assert info.source_file != nil
      assert info.documentation_available == true
    end

    test "handles missing modules gracefully" do
      info = ExDocIntegration.extract_module_info("NonExistent.Module", %{})
      
      assert info.exists == false
      assert info.error == "Module not found or not loaded"
      assert info.suggestions != nil
    end

    test "extracts function signatures and documentation" do
      info = ExDocIntegration.extract_module_info("Enum", %{include_functions: true})
      
      map_func = Enum.find(info.functions, &(&1.name == "map/2"))
      assert map_func != nil
      assert map_func.signature == "map(enumerable, fun)"
      assert map_func.description != nil
      assert map_func.examples != []
      assert map_func.since != nil
    end

    test "extracts type information when available" do
      info = ExDocIntegration.extract_module_info("GenServer", %{include_types: true})
      
      assert info.types != []
      server_type = Enum.find(info.types, &(&1.name == "server"))
      assert server_type != nil
      assert server_type.definition != nil
    end

    test "includes callback information for behaviour modules" do
      info = ExDocIntegration.extract_module_info("GenServer", %{include_callbacks: true})
      
      assert info.callbacks != []
      init_callback = Enum.find(info.callbacks, &(&1.name == "init/1"))
      assert init_callback != nil
      assert init_callback.required == true
      assert init_callback.description != nil
    end
  end

  describe "sync_with_exdoc_output/2" do
    test "syncs with generated ExDoc HTML files" do
      # Create mock ExDoc output
      output_dir = "/tmp/test_exdoc_output"
      File.mkdir_p!(output_dir)
      
      # Create sample HTML files
      File.write!("#{output_dir}/Enum.html", """
      <!DOCTYPE html>
      <html>
      <head><title>Enum</title></head>
      <body>
        <h1>Enum</h1>
        <p>Functions for working with collections</p>
        <div class="functions">
          <div class="function" id="map/2">
            <h3>map/2</h3>
            <p>Maps over enumerable</p>
          </div>
        </div>
      </body>
      </html>
      """)
      
      options = %{
        exdoc_output_path: output_dir,
        parse_html: true
      }
      
      result = ExDocIntegration.sync_with_exdoc_output(["Enum"], options)
      
      assert result.synced_modules == ["Enum"]
      assert result.parsed_files == 1
      
      enum_info = result.module_info["Enum"]
      assert enum_info.title == "Enum"
      assert enum_info.description == "Functions for working with collections"
      assert enum_info.functions == ["map/2"]
      
      # Cleanup
      File.rm_rf!(output_dir)
    end

    test "handles missing ExDoc output gracefully" do
      options = %{
        exdoc_output_path: "/nonexistent/path"
      }
      
      result = ExDocIntegration.sync_with_exdoc_output(["Enum"], options)
      
      assert result.synced_modules == []
      assert result.errors != []
      assert "ExDoc output path not found" in result.errors
    end

    test "parses function anchors from ExDoc HTML" do
      output_dir = "/tmp/test_exdoc_output"
      File.mkdir_p!(output_dir)
      
      File.write!("#{output_dir}/MyModule.html", """
      <div class="functions">
        <div class="function" id="my_function/2">
          <h3>my_function/2</h3>
        </div>
        <div class="function" id="another_function/1">
          <h3>another_function/1</h3>
        </div>
      </div>
      """)
      
      options = %{
        exdoc_output_path: output_dir,
        parse_function_anchors: true
      }
      
      result = ExDocIntegration.sync_with_exdoc_output(["MyModule"], options)
      
      module_info = result.module_info["MyModule"]
      assert "my_function/2" in module_info.function_anchors
      assert "another_function/1" in module_info.function_anchors
      
      File.rm_rf!(output_dir)
    end
  end

  describe "generate_preview_data/2" do
    test "generates comprehensive preview data for core modules" do
      preview = ExDocIntegration.generate_preview_data("Enum", %{})
      
      assert preview.module_name == "Enum"
      assert preview.module_type == "core"
      assert preview.description != nil
      assert preview.key_functions != []
      assert preview.examples != []
      assert preview.documentation_url != nil
      assert preview.since_version != nil
    end

    test "generates preview data for project modules" do
      preview = ExDocIntegration.generate_preview_data("SertantaiDocs.Navigation.Scanner", %{})
      
      assert preview.module_name == "SertantaiDocs.Navigation.Scanner"
      assert preview.module_type == "project"
      assert preview.description != nil
      assert preview.source_file != nil
      assert preview.functions != []
    end

    test "includes usage examples when available" do
      preview = ExDocIntegration.generate_preview_data("Enum", %{include_examples: true})
      
      assert preview.examples != []
      map_example = Enum.find(preview.examples, &String.contains?(&1, "Enum.map"))
      assert map_example != nil
    end

    test "handles modules with no documentation" do
      preview = ExDocIntegration.generate_preview_data("UndocumentedModule", %{})
      
      assert preview.module_name == "UndocumentedModule"
      assert preview.description == "No documentation available"
      assert preview.documentation_available == false
    end

    test "includes related modules suggestions" do
      preview = ExDocIntegration.generate_preview_data("Enum", %{include_related: true})
      
      assert preview.related_modules != []
      assert "Stream" in preview.related_modules
      assert "Enumerable" in preview.related_modules
    end
  end

  describe "link_validation" do
    test "validates ExDoc links against generated documentation" do
      cross_refs = [
        %{type: :exdoc, target: "Enum", url: "/api/docs/Enum.html"},
        %{type: :exdoc, target: "NonExistent", url: "/api/docs/NonExistent.html"}
      ]
      
      # Mock ExDoc output directory
      output_dir = "/tmp/test_validation"
      File.mkdir_p!(output_dir)
      File.write!("#{output_dir}/Enum.html", "<html>Mock ExDoc</html>")
      
      options = %{
        exdoc_output_path: output_dir,
        validate_against_filesystem: true
      }
      
      results = ExDocIntegration.validate_exdoc_links(cross_refs, options)
      
      enum_result = Enum.find(results, &(&1.target == "Enum"))
      assert enum_result.valid == true
      assert enum_result.file_exists == true
      
      missing_result = Enum.find(results, &(&1.target == "NonExistent"))
      assert missing_result.valid == false
      assert missing_result.file_exists == false
      
      File.rm_rf!(output_dir)
    end

    test "validates function anchor links" do
      cross_refs = [
        %{type: :exdoc, target: "Enum", anchor: "map/2"},
        %{type: :exdoc, target: "Enum", anchor: "nonexistent/1"}
      ]
      
      output_dir = "/tmp/test_anchors"
      File.mkdir_p!(output_dir)
      File.write!("#{output_dir}/Enum.html", """
      <div class="function" id="map/2">
        <h3>map/2</h3>
      </div>
      """)
      
      options = %{
        exdoc_output_path: output_dir,
        validate_anchors: true
      }
      
      results = ExDocIntegration.validate_exdoc_links(cross_refs, options)
      
      map_result = Enum.find(results, &(&1.anchor == "map/2"))
      assert map_result.anchor_exists == true
      
      missing_result = Enum.find(results, &(&1.anchor == "nonexistent/1"))
      assert missing_result.anchor_exists == false
      
      File.rm_rf!(output_dir)
    end
  end

  describe "exdoc_config_integration" do
    test "reads ExDoc configuration from mix.exs" do
      config = ExDocIntegration.read_exdoc_config("/fake/project/path")
      
      # Should use default values when mix.exs not found
      assert config.output_path == "doc"
      assert config.main == "README"
      assert config.source_ref == "main"
    end

    test "generates ExDoc configuration for cross-references" do
      options = %{
        cross_ref_base_url: "/docs",
        include_source_links: true,
        highlight_syntax: true
      }
      
      config = ExDocIntegration.generate_exdoc_config(options)
      
      assert config.extras != []
      assert config.groups_for_extras != []
      assert config.source_url_pattern != nil
      assert config.syntax_highlighting == true
    end

    test "integrates with existing ExDoc workflow" do
      # Test that our integration doesn't break existing ExDoc generation
      options = %{
        preserve_existing_config: true,
        add_cross_ref_support: true
      }
      
      result = ExDocIntegration.integrate_with_exdoc_workflow(options)
      
      assert result.integration_successful == true
      assert result.cross_ref_support_added == true
      assert result.existing_config_preserved == true
    end
  end

  describe "performance_optimization" do
    test "caches module information to avoid repeated lookups" do
      # First call should trigger module info extraction
      {time1, info1} = :timer.tc(fn ->
        ExDocIntegration.extract_module_info("Enum", %{cache: true})
      end)
      
      # Second call should use cache and be much faster
      {time2, info2} = :timer.tc(fn ->
        ExDocIntegration.extract_module_info("Enum", %{cache: true})
      end)
      
      assert info1 == info2
      assert time2 < time1 / 2  # Should be at least 2x faster
    end

    test "batch processes multiple modules efficiently" do
      modules = ["Enum", "GenServer", "Agent", "Task", "Process"]
      
      {time, results} = :timer.tc(fn ->
        ExDocIntegration.batch_extract_module_info(modules, %{})
      end)
      
      assert length(results) == 5
      assert time < 5000  # Should complete in reasonable time
      
      # All modules should have been processed
      for module <- modules do
        assert Map.has_key?(results, module)
        assert results[module].exists == true
      end
    end

    test "limits concurrent ExDoc parsing requests" do
      modules = Enum.map(1..100, &"Module#{&1}")
      
      options = %{
        max_concurrent: 5,
        timeout: 1000
      }
      
      result = ExDocIntegration.batch_extract_module_info(modules, options)
      
      # Should handle large batch without overwhelming system
      assert result.processed_count <= 100
      assert result.concurrent_limit_respected == true
    end
  end
end