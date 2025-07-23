defmodule SertantaiDocs.TOCVisualVerificationTest do
  use ExUnit.Case, async: true
  
  alias SertantaiDocs.MarkdownProcessor
  
  test "TOC renders correctly with all features" do
    markdown = """
    ---
    title: TOC Test Page
    ---
    
    # TOC Test Page
    
    Testing table of contents functionality
    
    <!-- TOC -->
    
    ## First Section
    
    This is the first section of content.
    
    ### Subsection 1.1
    
    Some nested content here.
    
    ### Subsection 1.2
    
    More nested content.
    
    ## Second Section  
    
    This has a [User Resource](ash:Sertantai.Accounts.User) cross-reference.
    
    ## Third Section
    
    Final section with code:
    
    ```elixir
    def example do
      :ok
    end
    ```
    """
    
    assert {:ok, html, metadata} = MarkdownProcessor.process_content(markdown)
    
    # Verify TOC structure
    assert html =~ ~s(<nav class="table-of-contents")
    assert html =~ ~s(<h2 class="toc-title text-lg font-semibold mb-3">Table of Contents</h2>)
    assert html =~ ~s(<ul class="toc-list space-y-1">)
    
    # Verify TOC entries
    assert html =~ ~s(href="#first-section")
    assert html =~ ~s(href="#subsection-11")
    assert html =~ ~s(href="#subsection-12")
    assert html =~ ~s(href="#second-section")
    assert html =~ ~s(href="#third-section")
    
    # Verify TOC text
    assert html =~ "First Section"
    assert html =~ "Subsection 1.1"
    assert html =~ "Subsection 1.2"
    assert html =~ "Second Section"
    assert html =~ "Third Section"
    
    # Verify cross-references still work
    assert html =~ ~s(data-preview-enabled="true")
    assert html =~ ~s(class="cross-ref cross-ref-ash")
    
    # Verify code blocks still work
    assert html =~ ~s(sertantai-code-block)
    assert html =~ "Copy"
    
    # Print a sample for visual verification
    IO.puts("\n=== TOC HTML Sample ===")
    toc_section = html
      |> String.split("table-of-contents")
      |> Enum.at(1, "")
      |> String.split("</nav>")
      |> hd()
    IO.puts("...table-of-contents#{toc_section}</nav>")
    IO.puts("=== End Sample ===\n")
  end
end