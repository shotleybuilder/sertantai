defmodule SertantaiDocsWeb.Navigation do
  @moduledoc """
  Provides navigation utilities for the documentation application.
  """

  alias SertantaiDocs.MarkdownProcessor

  @doc """
  Get the current navigation items. 
  This could be cached in the future for better performance.
  """
  def get_navigation_items do
    case MarkdownProcessor.generate_navigation() do
      {:ok, items} ->
        # Add a home item at the top
        [
          %{title: "Home", path: "/"}
          | items
        ]
        
      {:error, _reason} ->
        # Fallback navigation if file system reading fails
        [
          %{title: "Home", path: "/"},
          %{title: "Developer", path: "/dev", children: [
            %{title: "Getting Started", path: "/dev/index"},
            %{title: "Setup Guide", path: "/dev/setup"},
            %{title: "Architecture", path: "/dev/architecture"}
          ]},
          %{title: "User Guide", path: "/user", children: [
            %{title: "Overview", path: "/user/index"},
            %{title: "Getting Started", path: "/user/getting-started"},
            %{title: "Features", path: "/user/features"}
          ]}
        ]
    end
  end

  @doc """
  Get breadcrumb items for a given path.
  """
  def get_breadcrumbs(conn) do
    path_segments = String.split(conn.request_path, "/", trim: true)
    
    case path_segments do
      [] ->
        [%{title: "Documentation", path: nil}]
        
      [category] ->
        [
          %{title: "Documentation", path: "/"},
          %{title: String.capitalize(category), path: nil}
        ]
        
      [category, page] ->
        [
          %{title: "Documentation", path: "/"},
          %{title: String.capitalize(category), path: "/#{category}"},
          %{title: String.capitalize(page), path: nil}
        ]
        
      _ ->
        [%{title: "Documentation", path: "/"}]
    end
  end
end