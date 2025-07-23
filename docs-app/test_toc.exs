# Test script to verify TOC processing
alias SertantaiDocs.MarkdownProcessor

# Test with the TOC test file
case MarkdownProcessor.process_file("test/toc-test.md") do
  {:ok, html, metadata} ->
    IO.puts("=== Metadata ===")
    IO.inspect(metadata, pretty: true)
    
    IO.puts("\n=== HTML Output (first 3000 chars) ===")
    IO.puts(String.slice(html, 0, 3000))
    
    # Check for the TOC placeholder
    if String.contains?(html, "<!-- TOC -->") do
      IO.puts("\n✅ TOC placeholder found in HTML")
    else
      IO.puts("\n❌ TOC placeholder NOT found in HTML - MDEx may have removed it")
    end
    
    # Check if TOC was injected
    if String.contains?(html, "table-of-contents") do
      IO.puts("\n✅ SUCCESS: TOC was injected into the HTML!")
    else
      IO.puts("\n❌ ERROR: TOC was NOT found in the HTML!")
    end
    
    # Check for specific TOC content
    if String.contains?(html, "First Section") and String.contains?(html, "href=\"#first-section\"") do
      IO.puts("✅ TOC contains expected links")
    else
      IO.puts("❌ TOC links not found or incorrect")
    end
    
  {:error, reason} ->
    IO.puts("Error processing file: #{inspect(reason)}")
end