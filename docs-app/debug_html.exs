# Debug HTML processing step by step
alias SertantaiDocs.MarkdownProcessor
alias SertantaiDocs.TOC.Extractor

# Simple test content
test_content = """
---
title: "Test Page"
---

# Test Page

This is a test.

<!-- TOC -->

## Section One

Content for section one.

## Section Two

Content for section two.
"""

IO.puts("=== Original Content ===")
IO.puts(test_content)

# Extract frontmatter (call private function through public interface)
# {frontmatter, markdown} = MarkdownProcessor.extract_frontmatter(test_content)
# Let's manually extract for testing
[_, frontmatter_yaml, markdown] = String.split(test_content, "---", parts: 3)
markdown = String.trim(markdown)
IO.puts("\n=== Extracted Markdown ===")
IO.puts(markdown)

# Extract TOC
toc = Extractor.extract_toc(markdown, [])
IO.puts("\n=== TOC Headings ===")
IO.inspect(toc.headings, pretty: true)

# Generate simple TOC HTML (without the complex styling)
simple_toc_html = """
<div class="toc">
<h3>Table of Contents</h3>
<ul>
<li><a href="#section-one">Section One</a></li>
<li><a href="#section-two">Section Two</a></li>
</ul>
</div>
"""

IO.puts("\n=== Simple TOC HTML ===")
IO.puts(simple_toc_html)

# Replace placeholder
content_with_toc = String.replace(markdown, "<!-- TOC -->", simple_toc_html)
IO.puts("\n=== Content with TOC Replaced ===")
IO.puts(content_with_toc)

# Process with MDEx
alias MDEx
html_result = MDEx.to_html!(content_with_toc, unsafe: true)
IO.puts("\n=== Final MDEx HTML (unsafe: true) ===")
IO.puts(html_result)