# Testing Best Practices for Phoenix LiveView

This document outlines the best practices for testing Phoenix LiveView applications, particularly when dealing with large HTML documents.

## Problem: HTML Truncation in LiveView Tests

When testing Phoenix LiveView applications, you may encounter issues where HTML output is truncated, causing test assertions to fail. This typically happens when:

1. The rendered HTML exceeds the default output limit (approximately 30,000 characters)
2. Tests use full HTML string assertions (`assert html =~ "some text"`)
3. The page includes headers, navigation, flash messages, and other layout elements that increase HTML size

## Solution: Element-Based Testing

The canonical approach recommended by the Phoenix LiveView documentation is to use **element-based testing** instead of full HTML assertions.

### Key Testing Helpers

- `has_element?/3`: Checks if a specific element exists on the page
- `element/3`: Scopes testing to specific page elements
- `render_click/2`: Simulates click events on elements
- `render_change/2`: Simulates form input changes
- `render_submit/2`: Tests form submissions

### Before (Problematic Approach)

```elixir
test "search displays results" do
  {:ok, view, _html} = live(conn, "/search")
  
  html = view
    |> element("#search-input")
    |> render_change(%{search: "test"})
  
  # This fails with large HTML documents due to truncation
  assert html =~ "Search Results"
  assert html =~ "Test Company"
end
```

### After (Canonical Approach)

```elixir
test "search displays results" do
  {:ok, view, _html} = live(conn, "/search")
  
  view
  |> element("#search-input")
  |> render_change(%{search: "test"})
  
  # Element-based testing - no HTML truncation issues
  assert has_element?(view, "h3", "Search Results")
  assert has_element?(view, "div", "Test Company")
end
```

## Testing Strategies

### 1. Target Specific Elements

Instead of searching through the entire HTML blob, target specific elements:

```elixir
# Instead of:
assert html =~ "Delete"

# Use:
assert has_element?(view, "button", "Delete")
assert has_element?(view, "#user-#{user.id} button", "Delete")
```

### 2. Test User Interactions

Focus on what users can see and interact with:

```elixir
# Click a button and verify the result
view
|> element("#increment-button")
|> render_click()

assert has_element?(view, "#counter", "1")
```

### 3. Test Form Interactions

```elixir
# Test form submission
view
|> element("#user-form")
|> render_submit(%{user: %{name: "John"}})

assert has_element?(view, ".flash-success", "User created")
```

### 4. Test Element Attributes

```elixir
# Check for specific attributes
assert has_element?(view, "#search-input[value='test']")
assert has_element?(view, "button[disabled]")
```

### 5. Test Element Presence/Absence

```elixir
# Check if elements exist or don't exist
assert has_element?(view, "#user-#{user.id}")
refute has_element?(view, "#deleted-user")
```

## Pagination Testing

When testing pagination with large datasets:

```elixir
test "pagination works correctly" do
  {:ok, view, _html} = live(conn, "/users")
  
  # Test page navigation
  view
  |> element("nav button[phx-value-page='2']")
  |> render_click()
  
  # Check specific page content
  assert has_element?(view, "td", "User 21")
  assert has_element?(view, "td", "User 40")
  refute has_element?(view, "td", "User 1")  # Not on page 2
end
```

## Testing Async Operations

For LiveViews with async operations:

```elixir
test "async data loads correctly" do
  {:ok, view, _html} = live(conn, "/dashboard")
  
  # Wait for async operations to complete
  html = render_async(view)
  
  assert has_element?(view, "#data-section", "Loaded data")
end
```

## HTML Entity Handling

When testing text that may contain HTML entities:

```elixir
# HTML entities like &#39; for apostrophes
assert has_element?(view, "p", "This organization doesn&#39;t have any locations yet")
```

## Common Anti-Patterns to Avoid

### ❌ Don't: Use full HTML assertions
```elixir
assert html =~ "Expected text"
```

### ❌ Don't: Test implementation details
```elixir
assert html =~ "<div class='specific-class'>"
```

### ❌ Don't: Rely on HTML structure
```elixir
assert html =~ "<table><tr><td>Data</td></tr></table>"
```

### ✅ Do: Use element-based testing
```elixir
assert has_element?(view, "table td", "Data")
```

### ✅ Do: Test from user perspective
```elixir
assert has_element?(view, "button", "Submit")
```

### ✅ Do: Test behavior, not markup
```elixir
view |> element("button", "Delete") |> render_click()
refute has_element?(view, "#item-#{item.id}")
```

## Testing Complex Selectors

For complex element selection:

```elixir
# Target specific elements within containers
assert has_element?(view, "#user-list tr:first-child td", "John")

# Use attribute selectors
assert has_element?(view, "button[phx-click='delete'][phx-value-id='#{id}']")

# Combine selectors
assert has_element?(view, "nav button[phx-value-page='2'][class*='px-4']")
```

## Performance Benefits

Element-based testing provides several advantages:

1. **No HTML truncation**: Tests work regardless of HTML document size
2. **Faster execution**: No need to search through large HTML strings
3. **Better error messages**: More specific feedback when tests fail
4. **More maintainable**: Less brittle when HTML structure changes
5. **User-focused**: Tests what users actually see and interact with

## Testing State Transitions

Focus on testing how the UI responds to state changes:

```elixir
test "form validation shows errors" do
  {:ok, view, _html} = live(conn, "/users/new")
  
  # Submit invalid form
  view
  |> element("#user-form")
  |> render_submit(%{user: %{name: ""}})
  
  # Check for error state
  assert has_element?(view, ".field-error", "Name is required")
  assert has_element?(view, "#user-form input[name='user[name]'].error")
end
```

## Conclusion

By using element-based testing instead of full HTML assertions, you can:
- Avoid HTML truncation issues
- Write more reliable and maintainable tests
- Focus on user behavior rather than implementation details
- Improve test performance and clarity

This approach aligns with the Phoenix LiveView documentation and provides a more robust testing strategy for large applications.