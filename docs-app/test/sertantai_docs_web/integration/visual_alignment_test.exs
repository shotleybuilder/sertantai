defmodule SertantaiDocsWeb.VisualAlignmentTest do
  use SertantaiDocsWeb.ConnCase, async: true

  describe "visual alignment validation" do
    test "header search box left edge aligns with content left edge", %{conn: conn} do
      # This test validates the actual CSS classes being used create proper alignment
      
      conn = get(conn, ~p"/user/navigation-features")
      html = html_response(conn, 200)
      
      # Extract the structure we care about
      # 1. Header container classes
      header_match = Regex.run(~r/<header[^>]*>.*?<div class="([^"]*)"[^>]*>/s, html)
      header_classes = if header_match, do: Enum.at(header_match, 1), else: ""
      
      # 2. Search box classes  
      search_match = Regex.run(~r/<input[^>]*class="([^"]*)"[^>]*placeholder="Search/s, html)
      search_classes = if search_match, do: Enum.at(search_match, 1), else: ""
      
      # 3. Content container classes (from doc_content)
      content_match = Regex.run(~r/<div class="([^"]*max-w-6xl[^"]*)"[^>]*>[^<]*<nav[^>]*aria-label="Breadcrumb"/s, html)
      content_classes = if content_match, do: Enum.at(content_match, 1), else: ""
      
      IO.puts("Header container classes: '#{header_classes}'")
      IO.puts("Search input classes: '#{search_classes}'")
      IO.puts("Content container classes: '#{content_classes}'")
      
      # Both header and content should use identical container classes for alignment
      expected_container_classes = "max-w-6xl mx-auto px-4 sm:px-6 lg:px-8"
      
      assert header_classes =~ "max-w-6xl", "Header should use max-w-6xl container"
      assert header_classes =~ "mx-auto", "Header should be centered with mx-auto"
      assert header_classes =~ "px-4 sm:px-6 lg:px-8", "Header should use responsive padding"
      
      assert content_classes =~ "max-w-6xl", "Content should use max-w-6xl container" 
      assert content_classes =~ "mx-auto", "Content should be centered with mx-auto"
      assert content_classes =~ "px-4 sm:px-6 lg:px-8", "Content should use responsive padding"
    end

    test "documents the fix needed for perfect alignment", %{conn: conn} do
      # This test documents what needs to be fixed
      
      conn = get(conn, ~p"/user/navigation-features")
      html = html_response(conn, 200)
      
      # Check current search box width  
      search_box_width_match = Regex.run(~r/header_search_box class="([^"]*)"/, html)
      search_width = if search_box_width_match, do: Enum.at(search_box_width_match, 1), else: ""
      
      # Also check for w-80 or w-96 anywhere in the header
      has_w80 = html =~ ~r/w-80/
      has_w96 = html =~ ~r/w-96/
      
      IO.puts("Current search box width class: '#{search_width}'")
      IO.puts("Has w-80 in HTML: #{has_w80}")
      IO.puts("Has w-96 in HTML: #{has_w96}")
      
      # For perfect alignment, the issue might be:
      # 1. Search box is too wide and visually dominates the header space
      # 2. Content text starts at the natural text flow position
      # 3. This creates a visual misalignment even if containers are technically aligned
      
      cond do
        has_w96 ->
          IO.puts("ISSUE: Search box is w-96 (384px) - too wide, should be w-80 or smaller")
        has_w80 ->
          IO.puts("GOOD: Search box is w-80 (320px) - should be better balanced")
        search_width =~ "w-" ->
          IO.puts("Search box width: #{search_width}")
        true ->
          IO.puts("Could not detect search box width")
      end
      
      # The containers should use the same classes
      assert html =~ ~r/max-w-6xl mx-auto px-4 sm:px-6 lg:px-8/
    end
  end
end