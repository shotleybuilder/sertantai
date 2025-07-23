defmodule SertantaiDocsWeb.AlignmentDebugTest do
  use SertantaiDocsWeb.ConnCase, async: true

  test "debug the exact HTML structure causing misalignment", %{conn: conn} do
    conn = get(conn, ~p"/user/navigation-features")
    html = html_response(conn, 200)
    
    # Let's extract the exact structure around header, breadcrumb, and content
    lines = String.split(html, "\n")
    
    # Find lines containing our key elements
    header_lines = Enum.filter(lines, &(String.contains?(&1, "<header") or String.contains?(&1, "header_search_box")))
    breadcrumb_lines = Enum.filter(lines, &(String.contains?(&1, "breadcrumb") or String.contains?(&1, "Documentation")))
    content_lines = Enum.filter(lines, &(String.contains?(&1, "Navigation Features") or String.contains?(&1, "max-w-4xl")))
    
    IO.puts("\n=== HEADER STRUCTURE ===")
    Enum.each(header_lines, &IO.puts(String.trim(&1)))
    
    IO.puts("\n=== BREADCRUMB STRUCTURE ===") 
    Enum.each(breadcrumb_lines, &IO.puts(String.trim(&1)))
    
    IO.puts("\n=== CONTENT STRUCTURE ===")
    Enum.each(content_lines, &IO.puts(String.trim(&1)))
    
    # Check for any additional containers or padding that might cause offset
    container_lines = Enum.filter(lines, &(String.contains?(&1, "max-w-") or String.contains?(&1, "mx-auto") or String.contains?(&1, "px-")))
    
    IO.puts("\n=== ALL CONTAINER CLASSES ===")
    Enum.take(container_lines, 10) |> Enum.each(&IO.puts(String.trim(&1)))
  end
end