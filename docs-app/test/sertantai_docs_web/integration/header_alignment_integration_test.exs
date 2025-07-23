defmodule SertantaiDocsWeb.HeaderAlignmentIntegrationTest do
  use SertantaiDocsWeb.ConnCase, async: true

  describe "header and content alignment integration" do
    test "documentation page shows aligned header and content", %{conn: conn} do
      # Request an actual documentation page 
      conn = get(conn, ~p"/user/navigation-features")
      
      # Should get a successful response
      assert html_response(conn, 200)
      
      html = html_response(conn, 200)
      
      # Debug: print the relevant parts of the HTML structure 
      header_section = String.slice(html, String.length(html) - 4000, 4000)
      |> String.split("\n")
      |> Enum.filter(&(String.contains?(&1, "header") or String.contains?(&1, "max-w-4xl") or String.contains?(&1, "breadcrumb") or String.contains?(&1, "search")))
      |> Enum.take(20)
      
      IO.puts("\n=== RELEVANT HTML LINES ===")
      Enum.each(header_section, &IO.puts/1)
      IO.puts("=== END RELEVANT HTML ===\n")
      
      # Check that we have the expected elements
      assert html =~ "Navigation Features: Search, Filter &amp; Sort"
      assert html =~ "Documentation"  # Breadcrumb
      assert html =~ "User"          # Breadcrumb 
      assert html =~ "search"        # Search box
      
      # Check for the layout structure we expect
      assert html =~ ~r/max-w-4xl/    # Should have proper container width
      assert html =~ ~r/header/       # Should have header element
      assert html =~ ~r/main/         # Should have main element
    end

    test "app layout structure uses consistent containers", %{conn: conn} do
      # Test the actual rendered page to see the structure
      conn = get(conn, ~p"/user/navigation-features")
      html = html_response(conn, 200)
      
      # Count occurrences of different max-width classes
      max_w_4xl_count = length(Regex.scan(~r/max-w-4xl/, html))
      max_w_7xl_count = length(Regex.scan(~r/max-w-7xl/, html))
      
      IO.puts("max-w-4xl occurrences: #{max_w_4xl_count}")
      IO.puts("max-w-7xl occurrences: #{max_w_7xl_count}")
      
      # We should use max-w-4xl consistently, not max-w-7xl
      assert max_w_4xl_count > 0, "Should use max-w-4xl containers"
      assert max_w_7xl_count == 0, "Should not use max-w-7xl containers (causes misalignment)"
    end

    test "identifies potential alignment issues with search box width", %{conn: conn} do
      # The search box is w-96 (384px) which might cause visual misalignment
      # Let's check the structure
      conn = get(conn, ~p"/user/navigation-features")
      html = html_response(conn, 200)
      
      # Check for search box width class
      has_wide_search_box = html =~ ~r/w-96/
      has_header_container = html =~ ~r/max-w-4xl.*mx-auto.*px-4/
      has_content_container = html =~ ~r/max-w-4xl.*mx-auto.*px-4/
      
      IO.puts("Has wide search box (w-96): #{has_wide_search_box}")
      IO.puts("Has header container with max-w-4xl: #{has_header_container}")
      IO.puts("Has content container with max-w-4xl: #{has_content_container}")
      
      # The issue might be that the w-96 search box creates visual misalignment
      # even though the containers are correctly sized
      if has_wide_search_box do
        IO.puts("POTENTIAL ISSUE: w-96 search box might extend beyond container alignment")
      end
      
      assert has_header_container, "Header should use max-w-4xl container"
      assert has_content_container, "Content should use max-w-4xl container"
    end
  end
end