defmodule SertantaiDocsWeb.DebugW96Test do
  use SertantaiDocsWeb.ConnCase, async: true

  test "find all instances of w-96 in page HTML", %{conn: conn} do
    conn = get(conn, ~p"/user/navigation-features")
    html = html_response(conn, 200)
    
    # Find all w-96 matches with surrounding context
    matches = Regex.scan(~r/.{0,50}w-96.{0,50}/, html)
    
    IO.puts("\n=== ALL w-96 INSTANCES ===")
    Enum.with_index(matches) |> Enum.each(fn {match, index} ->
      IO.puts("#{index + 1}. #{inspect(match)}")
    end)
    
    # Also check for w-80 instances
    w80_matches = Regex.scan(~r/.{0,50}w-80.{0,50}/, html)
    
    IO.puts("\n=== ALL w-80 INSTANCES ===")
    Enum.with_index(w80_matches) |> Enum.each(fn {match, index} ->
      IO.puts("#{index + 1}. #{inspect(match)}")
    end)
    
    IO.puts("\nTotal w-96 instances: #{length(matches)}")
    IO.puts("Total w-80 instances: #{length(w80_matches)}")
  end
end