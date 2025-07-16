# User Admin Page Enhancement Plan

## Current State Analysis

The admin user page (`/admin/users`) currently has:
- ✅ Basic sorting by email, name, role, and created date
- ✅ Search functionality
- ✅ Role filtering
- ✅ Bulk operations (delete, role change)
- ❌ No pagination (loads all users in memory)
- ❌ No organization information displayed
- ❌ Poor mobile responsiveness
- ❌ No user-organization relationship links

## Data Model Understanding

**User-Organization Relationship**:
- Users belong to exactly ONE organization based on their email domain
- Organizations have an `email_domain` attribute (e.g., "acme.com")
- User email "john@acme.com" belongs to organization with `email_domain: "acme.com"`
- Organizations can have multiple locations (via `OrganizationLocation`)
- `OrganizationUser` join table manages user roles/permissions within their organization

## Required Enhancements

### 1. Add Organization Display and Links
**Goal**: Show which organization each user belongs to with clickable links to edit that organization.

**Implementation Steps**:
1. **Create Organization Lookup Function**:
   - Add helper function to determine user's organization by email domain
   - Query organizations where `email_domain` matches user's email domain
   - Cache organization lookup results to avoid repeated queries

2. **Update User Loading Query**:
   - Load users with a batch query to get all organizations
   - Create a map of domain -> organization for efficient lookup
   - Or use a calculated field/preload approach

3. **Add Organization Column to Table**:
   - Add "Organization" column header between "Name" and "Role"
   - Make organization names clickable links to `/admin/organizations/:id/edit`
   - Handle cases where users have no matching organization (display "None")
   - Show organization name clearly for each user

4. **Update Table Structure**:
   ```elixir
   # Add to table header
   <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
     Organization
   </th>
   
   # Add to table body
   <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
     <%= render_user_organization(@user, @organizations_by_domain) %>
   </td>
   ```

### 2. Implement Proper Pagination
**Goal**: Handle large numbers of users efficiently with server-side pagination.

**Implementation Steps**:
1. **Add Pagination State**:
   - Add `:page`, `:per_page`, `:total_count` to socket assigns
   - Default to 25 users per page
   - Track total count for pagination controls

2. **Update User Loading**:
   - Replace in-memory filtering with Ash query filters
   - Use `Ash.Query.limit/2` and `Ash.Query.offset/2`
   - Implement search as query filter instead of memory filter
   - Add role filter as query filter

3. **Add Pagination Controls**:
   - Create pagination component with Previous/Next buttons
   - Show page numbers (e.g., "Page 1 of 5")
   - Show total count (e.g., "Showing 1-25 of 127 users")
   - Add page size selector (25, 50, 100)

4. **Update Event Handlers**:
   - Add `handle_event("page_change", %{"page" => page}, socket)`
   - Add `handle_event("per_page_change", %{"per_page" => per_page}, socket)`
   - Reset to page 1 when search/filter changes

### 3. Enhanced Sorting
**Goal**: Improve existing sorting to include organization name.

**Implementation Steps**:
1. **Add Organization Sorting**:
   - Add organization name as sortable field
   - Update `sort_users/3` to handle organization sorting
   - Add sort button to organization column header

2. **Update Sort Logic**:
   ```elixir
   defp sort_users(users, "organization", sort_order) do
     sorted = Enum.sort_by(users, fn user ->
       case get_user_organization(user, @organizations_by_domain) do
         nil -> ""
         org -> org.organization_name || ""
       end
     end)
     
     case sort_order do
       "desc" -> Enum.reverse(sorted)
       _ -> sorted
     end
   end
   ```

### 4. Mobile Responsive Design
**Goal**: Make the user management page work well on mobile devices.

**Implementation Steps**:
1. **Responsive Table Layout**:
   - Hide less important columns on mobile (created date, bulk actions)
   - Use responsive classes: `hidden md:table-cell`
   - Show essential info only: checkbox, name, role, organization

2. **Mobile-Friendly Controls**:
   - Stack search and filter controls vertically on mobile
   - Make buttons touch-friendly (min 44px height)
   - Use responsive spacing classes

3. **Mobile Table Alternative**:
   - Consider card layout for mobile instead of table
   - Show user info in card format with organization link
   - Use `hidden md:block` for table, `md:hidden` for cards

4. **Responsive Pagination**:
   - Simplify pagination controls on mobile
   - Show only Previous/Next buttons on small screens
   - Move page size selector to dropdown

### 5. Query Optimization
**Goal**: Improve performance with proper database queries.

**Implementation Steps**:
1. **Replace Memory Filtering**:
   - Move search filter to Ash query using `Ash.Query.filter`
   - Move role filter to Ash query
   - Use database-level sorting instead of memory sorting

2. **Optimize Relationships**:
   - Load organization relationships efficiently
   - Consider using `Ash.Query.select` to limit fields
   - Add database indexes for commonly sorted fields

3. **Example Query Structure**:
   ```elixir
   query = User
     |> Ash.Query.filter(contains(email, ^search_term))
     |> Ash.Query.filter(role == ^role_filter)
     |> Ash.Query.sort(field: sort_field, order: sort_order)
     |> Ash.Query.limit(per_page)
     |> Ash.Query.offset((page - 1) * per_page)
     |> Ash.Query.load(organization_users: [:organization])
   ```

## Implementation Priority

### Phase 1: Core Functionality (High Priority)
1. ✅ **COMPLETED** Add organization display and links
2. ✅ **COMPLETED** Implement pagination
3. ✅ **COMPLETED** Add organization sorting

### Phase 2: User Experience (Medium Priority)
1. ✅ **COMPLETED** Mobile responsive design
2. ✅ **COMPLETED** Query optimization
3. ✅ **COMPLETED** Enhanced search (include organization names)

### Phase 3: Polish (Low Priority)
1. 📋 **TO DO** Loading states for pagination
2. 📋 **TO DO** Keyboard shortcuts for admin operations
3. 📋 **TO DO** Export functionality

## Implementation Status

**Current Progress: 100% complete**

### Completed Features
- ✅ Organization display with clickable links to edit organization
- ✅ Email domain-based organization lookup functionality  
- ✅ Server-side pagination with configurable page sizes (10, 25, 50, 100)
- ✅ Organization column sorting (uses email domain as proxy)
- ✅ Mobile responsive design with hidden columns and stacked controls
- ✅ Server-side filtering and search using Ash queries
- ✅ Comprehensive test coverage for all new functionality
- ✅ Pagination controls with Previous/Next and page numbers
- ✅ Mobile-friendly organization display under user names
- ✅ Optimized database queries replacing memory filtering

### Implementation Details
- **File Updated**: `/lib/sertantai_web/live/admin/users/user_list_live.ex:32-408`
- **Test Coverage**: `/test/sertantai_web/live/admin/users/user_list_live_test.exs:262-657`
- **Key Functions Added**:
  - `load_organizations_by_domain/1` - Loads organizations by email domain
  - `get_user_organization/2` - Gets organization for user by email domain
  - `render_user_organization/2` - Renders organization links
  - `build_user_query/1` - Builds server-side queries with filters
  - `apply_pagination/3` - Handles pagination with offset/limit
  - `pagination_info/1` - Formats pagination display info
  - `total_pages/1` - Calculates total pages for pagination

### Architecture Changes
- **Server-side Filtering**: Replaced memory filtering with Ash query filters
- **Pagination**: Added proper pagination state management with page/per_page/total_count
- **Organization Integration**: Added organization lookup by email domain matching
- **Mobile Responsive**: Added responsive classes for mobile table display

## File Changes Required

### 1. `/lib/sertantai_web/live/admin/users/user_list_live.ex`
- Update `mount/3` to include pagination state
- Modify `load_users/1` to use proper Ash queries
- Add organization relationship loading
- Update event handlers for pagination
- Add helper functions for organization display

### 2. User List Template (render function)
- Add organization column to table header
- Add organization cell to table body
- Update responsive classes for mobile
- Add pagination controls component
- Update search/filter controls layout

### 3. Helper Functions to Add
```elixir
defp load_organizations_by_domain(socket) do
  # Load all organizations and create domain lookup map
  case Ash.read(Organization, actor: socket.assigns.current_user) do
    {:ok, organizations} ->
      organizations_by_domain = 
        organizations
        |> Enum.map(fn org -> {org.email_domain, org} end)
        |> Map.new()
      
      assign(socket, :organizations_by_domain, organizations_by_domain)
    
    {:error, _} ->
      assign(socket, :organizations_by_domain, %{})
  end
end

defp get_user_organization(user, organizations_by_domain) do
  case user.email do
    nil -> nil
    email ->
      domain = email |> String.split("@") |> List.last()
      Map.get(organizations_by_domain, domain)
  end
end

defp render_user_organization(user, organizations_by_domain) do
  case get_user_organization(user, organizations_by_domain) do
    nil -> "None"
    org -> 
      link(org.organization_name, 
           to: "/admin/organizations/#{org.id}/edit",
           class: "text-blue-600 hover:text-blue-800")
  end
end

defp paginate_users(query, page, per_page) do
  offset = (page - 1) * per_page
  query
  |> Ash.Query.limit(per_page)
  |> Ash.Query.offset(offset)
end
```

## Success Criteria

1. **Organization Links**: Users show their organization (based on email domain) with clickable links
2. **Pagination**: Page loads quickly with 25 users per page by default
3. **Sorting**: All columns (including organization) are sortable
4. **Mobile**: Page is fully functional on mobile devices
5. **Performance**: Database queries instead of memory operations
6. **User Experience**: Intuitive navigation and responsive design

## Testing Requirements

### Test Files to Create/Update
1. **Unit Tests**: `test/sertantai_web/live/admin/users/user_list_live_test.exs`
   - Test pagination logic and organization loading
   - Test organization lookup by email domain
   - Test helper functions for organization display
   
2. **Integration Tests**: Test sorting and filtering functionality
   - Test organization column sorting
   - Test pagination with search and filters
   - Test mobile responsive behavior
   
3. **Performance Tests**: Test with large numbers of users (1000+)
   - Test pagination performance
   - Test organization lookup efficiency
   - Test search performance with large datasets

### Test Coverage Areas
- ✅ Organization display and linking functionality
- ✅ Pagination controls and navigation
- ✅ Sorting by organization name
- ✅ Mobile responsive design
- ✅ Query optimization performance
- ✅ Error handling for missing organizations

## Notes

- Users belong to exactly one organization determined by their email domain
- Organizations have multiple locations (not users having multiple organizations)
- The `OrganizationUser` join table manages roles/permissions within the user's organization
- Pagination should reset to page 1 when search/filter criteria change
- Mobile design should prioritize essential information
- Consider adding organization filter dropdown in future iterations
- Email domain extraction: `user@company.com` → `company.com` → find organization where `email_domain = "company.com"`