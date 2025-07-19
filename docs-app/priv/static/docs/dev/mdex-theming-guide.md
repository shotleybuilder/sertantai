---
title: "MDEx Custom Theming Guide"
description: "How to properly customize MDEx syntax highlighting themes and styling"
category: "development"
tags: ["mdex", "theming", "syntax-highlighting", "markdown"]
---

# MDEx Custom Theming Guide

This guide documents our learnings about properly customizing MDEx (the Markdown processor) for syntax highlighting and theming, based on implementation experience in the Sertantai documentation system.

## Overview

MDEx is a powerful Markdown processor that provides excellent syntax highlighting capabilities. However, customizing its appearance requires understanding its theming system rather than fighting against it.

## The Wrong Approach (What We Tried First)

Initially, we attempted to:

1. **Disable syntax highlighting entirely** (`syntax_highlight: false`)
2. **Strip all MDEx styling** with regex replacements
3. **Rebuild everything manually** with custom HTML templates

**Problems with this approach:**
- ❌ Lost beautiful syntax highlighting
- ❌ Complex content processing to remove spans and styling
- ❌ Alignment issues from content manipulation
- ❌ Fighting the framework instead of working with it

```elixir
# DON'T DO THIS - fights MDEx
mdex_options = [
  # ... other options
  syntax_highlight: false  # ❌ Loses all syntax highlighting
]

# Then trying to strip styling manually:
html
|> String.replace(~r/<span[^>]*style="[^"]*"/, "<span")  # ❌ Complex
|> String.replace(~r/background-color: #282c34/, "")     # ❌ Fragile
```

## The Right Approach (What Actually Works)

The key insight: **Work WITH MDEx's theming system, not against it.**

### 1. Choose the Right Base Theme

MDEx supports multiple themes. For light backgrounds, use `github_light`:

```elixir
syntax_highlight: [
  formatter: {:html_inline, 
    theme: "github_light",      # ✅ Light theme instead of dark
    pre_class: "custom-class"   # ✅ Add your own CSS class
  }
]
```

**Available themes include:**
- `"github_light"` - Light theme with white background
- `"github_dark"` - Dark theme (default)
- `"base16_ocean_light"` - Alternative light theme
- And many others...

### 2. Use pre_class for Custom Styling

The `pre_class` option adds your CSS class to the generated `<pre>` tag:

```elixir
syntax_highlight: [
  formatter: {:html_inline, 
    theme: "github_light",
    pre_class: "sertantai-code-block"  # Your custom class
  }
]
```

This generates:
```html
<pre class="athl sertantai-code-block" style="color: #1f2328; background-color: #ffffff;">
  <!-- Beautiful syntax highlighted content -->
</pre>
```

### 3. Override with CSS !important

Use CSS to override MDEx's inline styles while preserving syntax highlighting:

```css
.sertantai-code-block {
  background-color: #f9fafb !important; /* Override white with light grey */
  color: #1f2937 !important;            /* Ensure text contrast */
}
```

**Why this works:**
- ✅ Preserves all syntax highlighting colors
- ✅ Only overrides background/text colors as needed
- ✅ Uses CSS specificity properly
- ✅ Maintainable and clean

### 4. Enhance, Don't Replace

Instead of replacing MDEx output entirely, enhance it:

```elixir
defp enhance_code_blocks(html, code_block_languages) do
  # Match MDEx output with our custom class
  Regex.replace(
    ~r/<pre([^>]*class="[^"]*sertantai-code-block[^"]*"[^>]*)><code[^>]*>(.*?)<\/code><\/pre>/s,
    html,
    fn _full_match, pre_attributes, content ->
      # Clean up line wrappers but keep syntax spans
      cleaned_content = content
        |> String.replace(~r/<span class="line"[^>]*>/, "")
        |> String.replace(~r/<\/span>\n<\/span>/, "</span>\n")
        |> String.replace(~r/data-line="[^"]*"\s*/, "")
        |> String.trim()
      
      # Wrap with custom header but preserve MDEx <pre> tag
      render_enhanced_code_block(pre_attributes, cleaned_content, language, id)
    end
  )
end

defp render_enhanced_code_block(pre_attributes, content, language, block_id) do
  """
  <div class="custom-wrapper">
    <!-- Custom header with language and copy button -->
    <div class="header">#{language}</div>
    
    <!-- Preserve MDEx <pre> with all its styling -->
    <pre#{pre_attributes}><code id="#{block_id}-content">#{content}</code></pre>
  </div>
  """
end
```

## Complete Working Example

Here's our full implementation:

### 1. MDEx Configuration

```elixir
# lib/app/markdown_processor.ex
defp mdex_options do
  [
    extension: [
      strikethrough: true,
      table: true,
      autolink: true,
      # ... other extensions
    ],
    parse: [
      smart: true,
      # ... other parse options
    ],
    render: [
      unsafe: false,
      escape: false,
      github_pre_lang: true,
      # ... other render options
    ],
    # ✅ The key theming configuration
    syntax_highlight: [
      formatter: {:html_inline, 
        theme: "github_light",
        pre_class: "sertantai-code-block"
      }
    ]
  ]
end
```

### 2. CSS Overrides

```css
/* assets/css/app.css */
.sertantai-code-block {
  background-color: #f9fafb !important; /* Tailwind bg-gray-50 */
  color: #1f2937 !important;            /* Tailwind text-gray-800 */
}
```

### 3. Enhancement Processing

```elixir
defp enhance_code_blocks(html, languages) do
  Regex.replace(
    ~r/<pre([^>]*sertantai-code-block[^>]*)><code[^>]*>(.*?)<\/code><\/pre>/s,
    html,
    fn _full, pre_attrs, content ->
      cleaned = clean_content_preserve_syntax(content)
      render_enhanced_block(pre_attrs, cleaned, language, id)
    end
  )
end
```

## Key Learnings

### ✅ What Works
1. **Use appropriate base themes** - `github_light` for light UIs
2. **Add custom classes** - `pre_class` option for styling hooks
3. **Override with CSS** - Use `!important` to override inline styles
4. **Enhance, don't replace** - Wrap MDEx output instead of rebuilding
5. **Preserve syntax highlighting** - Keep the beautiful colors MDEx provides

### ❌ What Doesn't Work
1. **Disabling syntax highlighting** - Loses all color information
2. **Regex stripping of styles** - Complex, fragile, error-prone
3. **Complete HTML reconstruction** - Breaks alignment and spacing
4. **Fighting inline styles** - CSS specificity battles

## Advanced Customization Options

### Available Formatter Options

```elixir
syntax_highlight: [
  formatter: {:html_inline, [
    theme: "github_light",
    pre_class: "custom-class",
    # Other available options:
    # italic: true,              # Use italic for emphasis
    # include_highlights: true,  # Include highlight markers
    # highlight_lines: [1, 3],   # Highlight specific lines
    # header: "Custom Header"    # Add header content
  ]}
]
```

### Content Cleaning Strategy

When enhancing MDEx output, be surgical about what you clean:

```elixir
# ✅ Safe to remove - structural elements
content
|> String.replace(~r/<span class="line"[^>]*>/, "")     # Line wrappers
|> String.replace(~r/data-line="[^"]*"\s*/, "")        # Line numbers

# ❌ Don't remove - syntax highlighting
# |> String.replace(~r/<span style="color:[^"]*">/, "") # Syntax colors
# |> String.replace(~r/style="[^"]*"/, "")              # All styling
```

## Future Enhancements

Consider these possibilities for further customization:

1. **Multiple themes** - Switch between light/dark themes
2. **Language-specific styling** - Different colors per programming language
3. **Line highlighting** - Highlight specific lines for emphasis
4. **Custom syntax extensions** - Add highlighting for custom languages

## Debugging Tips

When working with MDEx theming:

1. **Check raw output** - See what MDEx generates before processing
2. **Test theme options** - Try different themes to find the right base
3. **Inspect CSS specificity** - Use browser dev tools to debug overrides
4. **Validate regex patterns** - Ensure you're matching the right elements

```elixir
# Debug raw MDEx output
raw_html = MDEx.to_html!(markdown, mdex_options)
IO.puts("Raw MDEx: #{raw_html}")
```

## Conclusion

The key to successful MDEx customization is understanding and working with its theming system rather than against it. By choosing appropriate base themes, using custom CSS classes, and enhancing rather than replacing the output, you can achieve beautiful, maintainable syntax highlighting that fits your design requirements.

This approach gives you:
- ✅ Professional syntax highlighting
- ✅ Custom styling control  
- ✅ Maintainable code
- ✅ Future flexibility
- ✅ Proper alignment and spacing