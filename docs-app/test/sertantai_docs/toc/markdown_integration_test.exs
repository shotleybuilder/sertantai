defmodule SertantaiDocs.TOCMarkdownIntegrationTest do
  use ExUnit.Case, async: true
  
  alias SertantaiDocs.MarkdownProcessor
  
  describe "TOC placeholder processing debug" do
    test "traces TOC processing steps" do
      markdown = """
      # Test Document
      
      This is a test.
      
      <!-- TOC -->
      
      ## Section One
      
      Content.
      
      ## Section Two
      
      More content.
      """
      
      # Let's trace what happens step by step
      IO.puts("\n=== TOC Processing Debug ===")
      IO.puts("1. Original markdown contains TOC placeholder: #{String.contains?(markdown, "<!-- TOC -->")}")
      
      # Check if the TOC extractor works
      toc = SertantaiDocs.TOC.Extractor.extract_toc(markdown, [min_level: 2])
      IO.puts("2. TOC extracted headings: #{inspect(Enum.map(toc.headings, & &1.text))}")
      
      # Process the content
      case MarkdownProcessor.process_content(markdown) do
        {:ok, html, _metadata} ->
          IO.puts("3. Processing succeeded")
          IO.puts("4. HTML contains 'table-of-contents': #{String.contains?(html, "table-of-contents")}")
          IO.puts("5. HTML contains 'toc-placeholder': #{String.contains?(html, "toc-placeholder")}")
          IO.puts("6. HTML contains '<!-- TOC -->': #{String.contains?(html, "<!-- TOC -->")}")
          IO.puts("7. HTML contains 'Section One': #{String.contains?(html, "Section One")}")
          
          # Look for any TOC-related content
          if String.contains?(html, "toc") do
            IO.puts("\n8. Found 'toc' in HTML - extracting context:")
            html
            |> String.split("toc")
            |> Enum.take(3)
            |> Enum.each(fn part ->
              IO.puts("   ...#{String.slice(part, -50..-1)}[TOC]#{String.slice(part, 0..50)}...")
            end)
          else
            IO.puts("\n8. No 'toc' found in HTML at all")
          end
          
          # Print a sample of the HTML
          IO.puts("\n9. HTML sample (first 500 chars):")
          IO.puts(String.slice(html, 0..500))
          
        {:error, reason} ->
          IO.puts("3. Processing failed: #{inspect(reason)}")
      end
      
      IO.puts("=== End Debug ===\n")
    end
  end
end