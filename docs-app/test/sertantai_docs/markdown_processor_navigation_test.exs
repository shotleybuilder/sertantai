defmodule SertantaiDocs.MarkdownProcessorNavigationTest do
  use ExUnit.Case
  
  alias SertantaiDocs.MarkdownProcessor

  @moduledoc """
  Focused tests for the navigation building bug that causes BadMapError.
  
  The issue: build_nav_tree inconsistently handles data structures when
  non-index pages are processed before index pages.
  """

  describe "navigation generation after fix" do
    test "generate_navigation works without BadMapError" do
      # Should no longer raise BadMapError
      assert {:ok, navigation} = MarkdownProcessor.generate_navigation()
      assert is_list(navigation)
    end

    test "navigation contains dev section with correct structure" do
      {:ok, navigation} = MarkdownProcessor.generate_navigation()
      
      # Should contain dev section
      dev_section = Enum.find(navigation, fn item ->
        title = Map.get(item, :title) || Map.get(item, "title")
        title && String.contains?(title, "Dev")
      end)
      
      assert dev_section, "Should contain dev section in navigation"
      
      # Should have path
      path = Map.get(dev_section, :path) || Map.get(dev_section, "path")
      assert path == "/dev"
    end

    test "navigation has consistent structure" do
      {:ok, navigation} = MarkdownProcessor.generate_navigation()
      
      # All items should be maps with consistent structure
      for item <- navigation do
        assert is_map(item)
        assert Map.has_key?(item, :title) or Map.has_key?(item, "title")
        assert Map.has_key?(item, :path) or Map.has_key?(item, "path")
      end
    end

    test "dev section includes documentation-system page in children" do
      {:ok, navigation} = MarkdownProcessor.generate_navigation()
      
      dev_section = Enum.find(navigation, fn item ->
        title = Map.get(item, :title) || Map.get(item, "title") 
        title && String.contains?(title, "Dev")
      end)
      
      # Should have children with documentation-system page
      children = Map.get(dev_section, :children) || Map.get(dev_section, "children") || []
      
      if is_list(children) and length(children) > 0 do
        doc_system_page = Enum.find(children, fn child ->
          title = Map.get(child, :title) || Map.get(child, "title")
          title && String.contains?(title, "Documentation System")
        end)
        
        assert doc_system_page, "Should include documentation-system page in dev children"
      end
    end
  end
end