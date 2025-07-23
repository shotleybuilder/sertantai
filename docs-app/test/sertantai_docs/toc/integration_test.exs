defmodule SertantaiDocs.TOCIntegrationTest do
  use ExUnit.Case, async: true

  alias SertantaiDocs.MarkdownProcessor
  alias SertantaiDocs.CrossRef.Processor

  describe "TOC integration with CrossRef processing" do
    test "TOC placeholder is handled correctly through the full processing pipeline" do
      markdown = """
      # Test Document

      <!-- TOC -->

      ## First Section
      
      Content here.
      
      ## Second Section
      
      More content.
      """

      # Test that the full processing pipeline handles TOC correctly
      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(markdown)
      
      # The final output should have the TOC, not the placeholder
      assert html =~ "table-of-contents"
      refute html =~ "<!-- TOC -->"
      
      # The TOC should contain the section headings
      assert html =~ "First Section"
      assert html =~ "Second Section"
      assert html =~ "href=\"#first-section\""
      assert html =~ "href=\"#second-section\""
    end

    test "full TOC generation works with CrossRef integration" do
      markdown = """
      # Documentation Page

      This page has cross-references and a TOC.

      <!-- TOC -->

      ## Getting Started

      Check the [User Resource](ash:Sertantai.Accounts.User) for authentication.

      ## Advanced Topics

      See the [Enum Module](exdoc:Enum) for collection operations.

      ### Subsection

      More details here.
      """

      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(markdown)
      
      # Should have TOC elements
      assert html =~ "table-of-contents" or html =~ "toc-list"
      
      # Should NOT have the raw placeholder
      refute html =~ "<!-- TOC -->"
      
      # Should have the actual TOC content with the headings
      assert html =~ "Getting Started"
      assert html =~ "Advanced Topics"
      assert html =~ "Subsection"
      
      # Should also have cross-references working
      assert html =~ "data-preview-enabled=\"true\""
      assert html =~ "class=\"cross-ref"
    end

    test "TOC links are generated correctly" do
      markdown = """
      # Test

      <!-- TOC -->

      ## Section One

      Content.

      ## Section Two

      More content.
      """

      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(markdown)
      
      # Should have anchor links in TOC
      assert html =~ "href=\"#section-one\""
      assert html =~ "href=\"#section-two\""
      
      # Should have corresponding heading IDs
      assert html =~ "id=\"section-one\""
      assert html =~ "id=\"section-two\""
    end

    test "empty TOC when no headings after H1" do
      markdown = """
      # Only H1 Heading

      <!-- TOC -->

      Just content, no other headings.
      """

      assert {:ok, html, _metadata} = MarkdownProcessor.process_content(markdown)
      
      # Should not have the placeholder
      refute html =~ "<!-- TOC -->"
      
      # Might have empty TOC or no TOC at all
      # This is acceptable behavior
    end
  end
end