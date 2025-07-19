defmodule SertantaiDocs.Navigation.Builder do
  @moduledoc """
  Builder module for constructing navigation structures, breadcrumbs,
  table of contents, and providing search/filter functionality.
  """

  @doc """
  Builds a complete navigation structure from scanner results.
  
  Returns a map with:
  - :categories - sorted list of categories with their files
  - :root_files - files that don't belong to specific categories
  - :total_files - total count of all files
  """
  def build_navigation(scan_result) do
    %{categories: categories_map, files: all_files} = scan_result
    
    # Extract root files (category "root" or files not in any category)
    root_files = 
      all_files
      |> Enum.filter(fn file ->
        file.category == "root" or file.category == "uncategorized" or
        not Map.has_key?(categories_map, file.category)
      end)
    
    # Convert categories map to sorted list and add category field
    categories = 
      categories_map
      |> Enum.map(fn {category_key, category_data} ->
        Map.put(category_data, :category, category_key)
      end)
      |> Enum.sort_by(& &1.title)
    
    # Calculate total files including those in categories
    total_files = 
      Enum.reduce(categories, length(root_files), fn category, acc ->
        acc + length(category.files)
      end)
    
    %{
      categories: categories,
      root_files: root_files,
      total_files: total_files
    }
  end

  @doc """
  Builds breadcrumb navigation for a given navigation item.
  
  Returns a list of breadcrumb items from root to current page.
  """
  def build_breadcrumbs(navigation_item) do
    path_segments = 
      navigation_item.path
      |> String.trim_leading("/")
      |> String.split("/")
      |> Enum.reject(&(&1 == ""))
    
    breadcrumbs = [%{title: "Home", path: "/"}]
    
    path_segments
    |> Enum.with_index()
    |> Enum.reduce(breadcrumbs, fn {segment, index}, acc ->
      # Build cumulative path
      current_path = "/" <> Enum.join(Enum.take(path_segments, index + 1), "/")
      
      # Generate title from segment
      title = if index == length(path_segments) - 1 do
        # Use the actual title for the final segment
        navigation_item.title
      else
        # Generate title from path segment with special handling for known categories
        case segment do
          "dev" -> "Developer Documentation"
          "user" -> "User Guide"
          "api" -> "API Reference"
          _ ->
            segment
            |> String.replace("-", " ")
            |> String.replace("_", " ")
            |> String.split()
            |> Enum.map(&String.capitalize/1)
            |> Enum.join(" ")
        end
      end
      
      acc ++ [%{title: title, path: current_path}]
    end)
  end

  @doc """
  Generates a table of contents from markdown content.
  
  Extracts headers (# ## ### ####) and creates anchored TOC.
  """
  def generate_toc(markdown_content) do
    markdown_content
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.starts_with?(&1, "#"))
    |> Enum.map(&parse_header/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Filters navigation by category.
  
  Returns filtered navigation showing only the specified category.
  """
  def filter_by_category(navigation, category_filter) do
    filtered_categories = 
      navigation.categories
      |> Enum.filter(&(&1.category == category_filter))
    
    total_files = 
      filtered_categories
      |> Enum.reduce(0, fn cat, acc -> acc + length(cat.files) end)
    
    %{
      categories: filtered_categories,
      root_files: [],
      total_files: total_files
    }
  end

  @doc """
  Searches navigation items by query string.
  
  Searches titles and tags, returns matching items.
  """
  def search_navigation(navigation, query) do
    query_lower = String.downcase(query)
    
    # Search in root files
    root_matches = 
      navigation.root_files
      |> Enum.filter(&matches_query?(&1, query_lower))
    
    # Search in category files
    category_matches = 
      navigation.categories
      |> Enum.flat_map(& &1.files)
      |> Enum.filter(&matches_query?(&1, query_lower))
    
    root_matches ++ category_matches
  end

  @doc """
  Converts file path to URL path.
  """
  def file_path_to_url_path(file_path) do
    cond do
      file_path == "index.md" ->
        "/"
      
      String.ends_with?(file_path, "/index.md") ->
        file_path
        |> String.replace(~r/\/index\.md$/, "")
        |> case do
          "" -> "/"
          path -> "/" <> path
        end
      
      String.ends_with?(file_path, ".md") ->
        "/" <> String.replace(file_path, ~r/\.md$/, "")
      
      true ->
        "/" <> file_path
    end
  end

  @doc """
  Converts title to URL-friendly slug.
  """
  def title_to_slug(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^\w\s.-]/, "")  # Keep dots, word chars, spaces, hyphens
    |> String.replace(~r/\s+/, "-")       # Replace spaces with hyphens
    |> String.replace(~r/\.+/, "-")       # Replace dots with hyphens
    |> String.replace(~r/-+/, "-")        # Collapse multiple hyphens
    |> String.trim("-")                   # Remove leading/trailing hyphens
  end

  # Private functions

  defp parse_header(line) do
    case Regex.run(~r/^(#+)\s+(.+)$/, line) do
      [_, hashes, title_text] ->
        level = String.length(hashes)
        title = String.trim(title_text)
        anchor = title_to_slug(title)
        
        %{
          level: level,
          title: title,
          anchor: anchor
        }
      
      _ ->
        nil
    end
  end

  defp matches_query?(item, query_lower) do
    title_match = String.contains?(String.downcase(item.title), query_lower)
    
    tag_match = 
      item.tags
      |> Enum.any?(&String.contains?(String.downcase(&1), query_lower))
    
    title_match or tag_match
  end
end