---
title: "Cross-Reference Links Guide"
description: "Complete guide to using interactive cross-reference links for seamless navigation between documentation, API references, and resources"
category: "user"
tags: ["cross-references", "navigation", "links", "documentation", "api"]
priority: "high"
last_modified: "2024-01-21"
---

# Cross-Reference Links Guide

The documentation system includes powerful cross-reference linking that creates interactive connections between different types of content. These special links provide instant previews and seamless navigation throughout the documentation ecosystem.

## What are Cross-Reference Links?

Cross-reference links are enhanced hyperlinks that:
- **Show instant previews** when you hover over them
- **Validate automatically** to catch broken references
- **Connect different content types** (documentation, API, resources)
- **Provide rich metadata** about the linked content

## Link Types Available

### 1. Ash Resource Links `ash:`

Link to Ash framework resources with detailed resource information.

**Syntax:**
```markdown
[User Resource](ash:Sertantai.Accounts.User)
[Organization Resource](ash:Sertantai.Organizations.Organization)
```

**What you get:**
- Resource type and domain information
- Available actions (create, read, update, destroy)
- Attributes and relationships
- Rich hover previews with metadata

**Example:**
When you hover over [User Resource](ash:Sertantai.Accounts.User), you'll see:
- Domain: Sertantai.Accounts
- Actions: create, read, update, destroy, sign_in
- Attributes: email, name, role
- Relationships: user_identities, organizations

### 2. ExDoc Module Links `exdoc:`

Link to Elixir module documentation with function information.

**Syntax:**
```markdown
[Enum Module](exdoc:Enum)
[GenServer Module](exdoc:GenServer)
[Custom Module](exdoc:Sertantai.Accounts.User)
```

**What you get:**
- Module description and documentation
- Key functions and their arities
- Code examples where available
- Version information

**Example:**
Hovering over [Enum Module](exdoc:Enum) shows:
- Description: "Functions for working with collections"
- Functions: map/2, filter/2, reduce/3
- Examples: `Enum.map([1, 2, 3], &(&1 * 2))`

### 3. Internal Documentation Links `dev:`

Link to developer documentation with content previews.

**Syntax:**
```markdown
[Setup Guide](dev:setup-guide)
[Architecture Overview](dev:architecture)
[API Documentation](dev:api-reference)
```

**What you get:**
- Document title and description
- Content category and tags
- Section overview
- Last modified date

### 4. User Guide Links `user:`

Link to user-facing documentation and guides.

**Syntax:**
```markdown
[Getting Started](user:getting-started)
[Feature Overview](user:features/overview)
[Troubleshooting](user:support/troubleshooting)
```

**What you get:**
- Guide title and description
- Content category
- Available sections
- Related tags

## Interactive Preview Features

### Hover Previews

Simply hover your mouse over any cross-reference link to see:
- **Rich metadata** about the target content
- **Quick overview** without leaving the page
- **Related information** like functions, actions, or sections
- **Loading states** for dynamically fetched content

### Keyboard Navigation

Cross-reference links are fully accessible:
- **Tab navigation**: Use Tab to focus on links
- **Enter/Space**: Press to activate preview or follow link
- **Escape**: Close any open preview
- **Screen reader support**: Full ARIA attributes for accessibility

### Error Handling

When links are broken or content is missing:
- **Visual indicators**: Broken links are styled differently
- **Error messages**: Clear explanation of what went wrong
- **Suggestions**: Alternative links you might have meant
- **Graceful degradation**: Links still work as regular HTML links

## Advanced Features

### Lazy Loading

Preview data is loaded efficiently:
- **On-demand loading**: Content loaded only when needed
- **Caching**: Previously loaded content is cached
- **Performance optimization**: Debounced hover events prevent excessive requests

### Dark Mode Support

The preview system automatically adapts to:
- **System preferences**: Follows your OS dark mode setting
- **Custom themes**: Integrates with site theming
- **High contrast**: Enhanced visibility for accessibility

### Mobile Responsiveness

Cross-reference previews work on all devices:
- **Touch-friendly**: Tap to show preview on mobile
- **Responsive sizing**: Previews scale to screen size
- **Optimized content**: Mobile-appropriate information density

## Writing Cross-Reference Links

### Best Practices

1. **Use descriptive text**: Make link text meaningful
   ```markdown
   ✅ [User authentication resource](ash:Sertantai.Accounts.User)
   ❌ [Click here](ash:Sertantai.Accounts.User)
   ```

2. **Choose appropriate link types**: Match the link type to the target
   ```markdown
   ✅ [User Module API](exdoc:Sertantai.Accounts.User)  # For API docs
   ✅ [User Resource](ash:Sertantai.Accounts.User)      # For Ash resources
   ```

3. **Verify your links**: The system will catch broken links automatically
   - Green underline = valid link
   - Red strikethrough = broken link

### Common Link Patterns

**API Documentation:**
```markdown
See the [User API](exdoc:Sertantai.Accounts.User) for detailed function documentation.
```

**Resource References:**
```markdown
The [Organization resource](ash:Sertantai.Organizations.Organization) manages company information.
```

**Internal Documentation:**
```markdown
For setup instructions, see the [Development Setup Guide](dev:setup-guide).
```

**User Guides:**
```markdown
Learn more in the [Getting Started Guide](user:getting-started).
```

## Troubleshooting

### Common Issues

**Preview not showing:**
- Check that you're hovering long enough (150ms delay)
- Verify the link syntax is correct
- Look for any console errors

**Broken link styling:**
- The target content may have been moved or renamed
- Check the suggestions in the error preview
- Verify the module/resource exists

**Slow preview loading:**
- Large modules may take longer to load
- Network connectivity could affect loading times
- Cached content will load instantly on repeat visits

### Getting Help

If you encounter issues with cross-reference links:

1. **Check the link syntax** - Ensure you're using the correct format
2. **Verify the target exists** - Make sure the referenced content is available
3. **Look for suggestions** - Broken link previews often suggest alternatives
4. **Report persistent issues** - Contact the documentation team for recurring problems

## Technical Details

### Link Validation

The system automatically:
- **Validates all links** during content processing
- **Reports broken references** with helpful error messages
- **Suggests alternatives** when possible
- **Maintains link health metrics** for monitoring

### Performance Optimization

Cross-reference links are optimized for:
- **Fast rendering**: Minimal impact on page load time
- **Efficient caching**: Smart caching of preview data
- **Debounced interactions**: Prevents excessive API calls
- **Concurrent processing**: Multiple links validated simultaneously

### Security

The preview system includes:
- **XSS protection**: All content is properly escaped
- **Input validation**: Link targets are validated before processing
- **Safe rendering**: HTML content is sanitized before display

---

This cross-reference system makes documentation navigation seamless and provides rich context without interrupting your reading flow. The interactive previews help you understand connections between different parts of the system while maintaining excellent performance and accessibility.