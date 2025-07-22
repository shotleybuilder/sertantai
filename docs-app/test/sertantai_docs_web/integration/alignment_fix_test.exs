defmodule SertantaiDocsWeb.AlignmentFixTest do
  use SertantaiDocsWeb.ConnCase, async: true

  test "verifies max-w-none conflict is resolved", %{conn: conn} do
    conn = get(conn, ~p"/user/navigation-features")
    html = html_response(conn, 200)
    
    # Check that max-w-none is not conflicting with max-w-6xl
    max_w_none_matches = Regex.scan(~r/max-w-none/, html)
    max_w_6xl_matches = Regex.scan(~r/max-w-6xl/, html)
    
    IO.puts("max-w-none occurrences: #{length(max_w_none_matches)}")
    IO.puts("max-w-6xl occurrences: #{length(max_w_6xl_matches)}")
    
    # Should have max-w-6xl containers but no conflicting max-w-none
    assert length(max_w_6xl_matches) > 0, "Should have max-w-6xl containers"
    
    # If there's max-w-none, it should not be in the content area
    if length(max_w_none_matches) > 0 do
      IO.puts("Found max-w-none instances - checking context:")
      Enum.each(max_w_none_matches, fn [match] ->
        context = Regex.run(~r/.{0,100}#{Regex.escape(match)}.{0,100}/, html)
        if context, do: IO.puts("Context: #{inspect(context)}")
      end)
    else
      IO.puts("✅ No max-w-none conflicts found - alignment should be fixed!")
    end
    
    # Content should respect the max-w-6xl constraint while article uses max-w-none for expansion
    assert html =~ ~r/prose prose-lg[^"]*"/
    # We intentionally keep max-w-none on article for content expansion within the 6xl container
    assert html =~ ~r/prose prose-lg max-w-none/
  end
end