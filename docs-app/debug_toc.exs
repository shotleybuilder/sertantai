# Debug TOC generation
alias SertantaiDocs.TOC.Extractor

# Test markdown content
markdown_content = """
# TOC Test Page

This page tests the table of contents functionality.

## First Section

This is the first section of content.

### Subsection 1.1

Some content in subsection 1.1.

### Subsection 1.2

Some content in subsection 1.2.

## Second Section

This is the second section.
"""

IO.puts("=== Extracting TOC ===")
toc = Extractor.extract_toc(markdown_content, [])
IO.inspect(toc, pretty: true)

IO.puts("\n=== TOC Headings ===")
Enum.each(toc.headings, fn heading ->
  IO.puts("Level #{heading.level}: #{heading.text} (id: #{heading.id})")
end)

IO.puts("\n=== TOC Tree ===")
IO.inspect(toc.tree, pretty: true)

# Test HTML generation
generate_toc_html = fn headings, opts ->
  tree = Extractor.build_toc_tree(headings)
  title = Keyword.get(opts, :title, "Table of Contents")
  
  toc_items = Enum.map_join(tree, "\n", fn node ->
    """
    <li class="toc-item" data-level="#{node.level}">
      <a href="##{node.id}" class="text-sm hover:text-indigo-600 transition-colors">#{node.text}</a>
    </li>
    """
  end)
  
  """
  <nav class="table-of-contents mb-6 p-4 bg-gray-50 rounded-lg border border-gray-200">
    <h2 class="toc-title text-lg font-semibold mb-3">#{title}</h2>
    <ul class="toc-list space-y-1">
      #{toc_items}
    </ul>
  </nav>
  """
end

toc_html = generate_toc_html.(toc.headings, [])
IO.puts("\n=== Generated TOC HTML ===")
IO.puts(toc_html)