defmodule SertantaiDocsWeb.DocController do
  use SertantaiDocsWeb, :controller

  alias SertantaiDocs.MarkdownProcessor

  def index(conn, _params) do
    # Render the documentation home page
    case MarkdownProcessor.process_file("dev/index.md") do
      {:ok, html_content, frontmatter} ->
        render(conn, :index, 
          content: html_content, 
          frontmatter: frontmatter,
          page_title: Map.get(frontmatter, "title", "Documentation")
        )
      {:error, _reason} ->
        render(conn, :index, 
          content: "<h1>Welcome to Sertantai Documentation</h1><p>Documentation is being set up.</p>", 
          frontmatter: %{},
          page_title: "Documentation"
        )
    end
  end

  def show(conn, %{"category" => category, "page" => page}) do
    file_path = "#{category}/#{page}.md"
    
    case MarkdownProcessor.process_file(file_path) do
      {:ok, html_content, frontmatter} ->
        render(conn, :show,
          content: html_content,
          metadata: frontmatter,
          page_title: Map.get(frontmatter, "title", String.capitalize(page)),
          category: category,
          page: page
        )
      {:error, :file_not_found} ->
        conn
        |> put_status(:not_found)
        |> render(:not_found, 
          page_title: "Page Not Found",
          requested_path: file_path
        )
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> render(:error, 
          page_title: "Error",
          error: reason
        )
    end
  end

  def show(conn, %{"page" => page}) do
    # Default to dev category if no category specified
    show(conn, %{"category" => "dev", "page" => page})
  end

  def category_index(conn, %{"category" => category}) do
    case MarkdownProcessor.process_file("#{category}/index.md") do
      {:ok, html_content, frontmatter} ->
        render(conn, :category_index,
          content: html_content,
          frontmatter: frontmatter,
          page_title: Map.get(frontmatter, "title", String.capitalize(category) <> " Documentation"),
          category: category
        )
      {:error, _reason} ->
        render(conn, :category_index,
          content: "<h1>#{String.capitalize(category)} Documentation</h1><p>Coming soon...</p>",
          frontmatter: %{},
          page_title: "#{String.capitalize(category)} Documentation",
          category: category
        )
    end
  end
end