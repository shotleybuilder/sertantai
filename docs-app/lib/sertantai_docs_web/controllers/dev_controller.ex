defmodule SertantaiDocsWeb.DevController do
  @moduledoc """
  Development controller for integration testing and debugging.
  
  This controller provides API endpoints for development and testing:
  - Integration status monitoring
  - Manual content synchronization
  - Navigation structure inspection
  - Content metadata debugging
  """

  use SertantaiDocsWeb, :controller

  alias SertantaiDocs.Integration
  alias SertantaiDocs.MarkdownProcessor
  alias SertantaiDocsWeb.Navigation

  @doc """
  Get the current status of the integration system.
  """
  def integration_status(conn, _params) do
    status = Integration.status()
    
    json(conn, %{
      status: "ok",
      integration: status,
      environment: %{
        app: :sertantai_docs,
        version: Application.spec(:sertantai_docs, :vsn) || "dev",
        phoenix_version: Application.spec(:phoenix, :vsn),
        elixir_version: System.version()
      }
    })
  end

  @doc """
  Manually trigger content synchronization.
  """
  def trigger_sync(conn, _params) do
    case Integration.sync_content() do
      {:ok, stats} ->
        json(conn, %{
          status: "success",
          message: "Content synchronization completed",
          stats: stats
        })
        
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          status: "error",
          message: "Content synchronization failed",
          error: inspect(reason)
        })
    end
  end

  @doc """
  Get the current navigation structure.
  """
  def navigation(conn, _params) do
    navigation_items = Navigation.get_navigation_items()
    
    json(conn, %{
      status: "ok",
      navigation: navigation_items,
      metadata: %{
        generated_at: DateTime.utc_now(),
        item_count: count_navigation_items(navigation_items)
      }
    })
  end

  @doc """
  Get detailed information about a specific content file.
  """
  def content_info(conn, %{"path" => path}) do
    # Handle wildcard path parameter (it's a list)
    file_path = case path do
      [single_path] -> single_path
      multiple_parts when is_list(multiple_parts) -> Path.join(multiple_parts)
      single_string when is_binary(single_string) -> single_string
    end
    
    # Decode the path parameter
    decoded_path = URI.decode(file_path)
    
    case MarkdownProcessor.get_metadata(decoded_path) do
      {:ok, metadata} ->
        # Try to get the actual content for additional info
        content_info = case MarkdownProcessor.process_file(decoded_path) do
          {:ok, html, frontmatter} ->
            %{
              html_length: String.length(html),
              frontmatter: frontmatter,
              has_content: true
            }
            
          {:error, reason} ->
            %{
              content_error: inspect(reason),
              has_content: false
            }
        end
        
        json(conn, %{
          status: "ok",
          file_path: decoded_path,
          metadata: metadata,
          content: content_info
        })
        
      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          status: "error",
          message: "Content file not found or could not be processed",
          file_path: decoded_path,
          error: inspect(reason)
        })
    end
  end

  # Helper function to count navigation items recursively
  defp count_navigation_items(items) when is_list(items) do
    Enum.reduce(items, 0, fn item, acc ->
      base_count = 1
      children_count = case Map.get(item, :children) do
        children when is_list(children) -> count_navigation_items(children)
        _ -> 0
      end
      acc + base_count + children_count
    end)
  end
  
  defp count_navigation_items(_), do: 0
end