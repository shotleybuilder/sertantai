# Search Implementation Guide

## Overview

This guide documents the implementation of case-insensitive search functionality in the Sertantai application, including what works, what doesn't work, and the solutions that were implemented.

## Working Implementation

### Current Search Features ✅

1. **Case-insensitive search** using PostgreSQL `ILIKE` operator
2. **Multi-field search** across `title_en` and `number` fields
3. **Real-time search** with 300ms debounce
4. **Search combined with filters** - works alongside family, year, type_code, and status filters
5. **Empty search handling** - gracefully handles empty/null search terms

### Technical Implementation

The search is implemented using PostgreSQL's native `ILIKE` operator through Ash `fragment` functions:

```elixir
# In lib/sertantai/uk_lrt.ex - :paginated action filter
if is_nil(^arg(:search)) do
  true
else
  fragment("? ILIKE ?", title_en, fragment("'%' || ? || '%'", ^arg(:search))) or
  fragment("? ILIKE ?", number, fragment("'%' || ? || '%'", ^arg(:search)))
end
```

### Search Field Selection

**Included Fields:**
- `title_en` - Primary searchable field (English title of legal instruments)
- `number` - Secondary searchable field (record numbers like "c. 17", "no. 123")

**Excluded Fields:**
- `family` - Excluded because it's already filtered by the Family dropdown
- Other fields - Not included to keep search focused and performant

### UI Implementation

The search box is integrated within the main filter form to ensure proper event handling:

```heex
<form phx-change="filter_change" class="space-y-4">
  <div class="mb-4">
    <label class="block text-sm font-medium text-gray-700 mb-2">
      Search in Title or Number
    </label>
    <div class="relative max-w-md">
      <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
        <.icon name="hero-magnifying-glass" class="h-5 w-5 text-gray-400" />
      </div>
      <input
        type="text"
        name="search"
        value={@search}
        placeholder="Search by title or number..."
        phx-debounce="300"
        class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md..."
      />
    </div>
  </div>
  <!-- Other filters... -->
</form>
```

## What Doesn't Work ❌

### Ash CiString Implementation

**Problem**: The documented Ash approach using `CiString` does not work for case-insensitive search.

**What was tried:**
```elixir
# This approach FAILED
contains(title_en, ^Ash.CiString.new(arg(:search))) or
contains(number, ^Ash.CiString.new(arg(:search)))
```

**Results**: 
- `Ash.CiString.new("search term")` creates the CiString correctly
- The `contains` function still performs case-sensitive matching
- "energy conservation" does not match "Energy Conservation Act"

**Root Cause**: The Ash `contains` function documentation states it supports case-insensitive matching when "CiString is on either side," but in practice this doesn't work with PostgreSQL data layers.

### Alternative Approaches That Failed

1. **CiString conversion at LiveView level**:
   ```elixir
   # Also failed
   search: Ash.CiString.new(search_term)
   ```

2. **Fragment with LOWER() functions**:
   ```elixir
   # Previously tried, caused compilation errors
   fragment("LOWER(?) LIKE LOWER(?)", title_en, fragment("'%' || ? || '%'", ^arg(:search)))
   ```

3. **Sigil-based CiString creation**:
   ```elixir
   # Syntax errors
   contains(title_en, ~i[#{^arg(:search)}])
   ```

## Successful Solution: PostgreSQL ILIKE

### Why ILIKE Works

PostgreSQL's `ILIKE` operator is specifically designed for case-insensitive pattern matching:
- Native database-level case insensitivity
- Supports `%` wildcards for partial matching  
- No additional string processing required
- Optimal performance for PostgreSQL databases

### Implementation Pattern

```elixir
fragment("? ILIKE ?", field_name, fragment("'%' || ? || '%'", ^arg(:search_term)))
```

**Breakdown:**
- `fragment("? ILIKE ?", field_name, pattern)` - PostgreSQL ILIKE comparison
- `fragment("'%' || ? || '%'", ^arg(:search_term))` - Wraps search term with `%` wildcards
- `^arg(:search_term)` - Safely injects the search parameter

### Test Results

All case variations now work correctly:
- "Energy Conservation" → 1 result ✅
- "energy conservation" → 1 result ✅  
- "ENERGY CONSERVATION" → 1 result ✅
- "conservation" → 1 result ✅
- "Conservation" → 1 result ✅

## Testing Considerations

### Working Test Pattern

For testing search functionality, the following patterns work reliably:

```elixir
# Direct Ash query testing
{:ok, results} = Ash.read(
  UkLrt |> Ash.Query.for_read(:paginated, %{
    family: "💚 ENERGY",
    search: "energy conservation"  # lowercase works!
  }),
  domain: Sertantai.Domain
)
```

### LiveView Test Challenges

LiveView tests for search functionality encounter authentication boundary issues that are separate from the search implementation. The search logic itself works correctly when called directly.

## Database Compatibility

### PostgreSQL ✅
- Full support via `ILIKE` operator
- Case-insensitive matching
- Pattern matching with `%` wildcards
- Optimal performance

### Other Databases ⚠️
This implementation is PostgreSQL-specific. For other databases, alternative approaches would be needed:
- **MySQL**: `LIKE` with `COLLATE` or `LOWER()` functions
- **SQLite**: `LIKE` with `PRAGMA case_sensitive_like = OFF`
- **Generic**: Fragment with `LOWER()` functions (may have different syntax requirements)

## Performance Considerations

### Current Performance
- Search executes at database level (fast)
- Combined with existing filters efficiently
- 300ms debounce prevents excessive queries
- Pagination limits result sets

### Potential Optimizations
1. **Database Indexes**: Add indexes on searchable fields if needed
2. **Full-Text Search**: Consider PostgreSQL full-text search for complex queries
3. **Search Caching**: Could cache common searches if performance becomes an issue

## Key Learnings

1. **Ash documentation gap**: The `CiString` + `contains` approach doesn't work as documented
2. **Database-specific solutions**: PostgreSQL `ILIKE` is the most reliable approach
3. **Fragment functions**: Ash `fragment` provides access to native SQL capabilities
4. **Event handling**: Search input must be within the main filter form for proper event handling
5. **Testing isolation**: Search logic can be tested independently of LiveView authentication

## Recommendations

### For Future Development
1. **Use ILIKE for PostgreSQL**: Continue using the `fragment` + `ILIKE` pattern
2. **Database abstraction**: If supporting multiple databases, create database-specific implementations
3. **Test database queries directly**: Test search logic with direct Ash queries before LiveView integration
4. **Performance monitoring**: Monitor search query performance as data grows

### For Similar Features
1. **Start with database-native solutions**: Use database-specific features rather than framework abstractions
2. **Test early and often**: Verify case-insensitive behavior with actual test data
3. **Document workarounds**: Framework documentation may not always reflect real-world behavior