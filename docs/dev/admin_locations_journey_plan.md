# Admin Location Management Journey Plan

## Current State Analysis

### Existing Routes
**User Routes (Working)**:
- `/organizations/locations` - User's own organization location management
- `/organizations/locations/new` - Create new location for user's organization
- `/organizations/locations/:id/edit` - Edit location for user's organization

**Admin Routes (Existing)**:
- `/admin/organizations` - List all organizations
- `/admin/organizations/:id` - Organization detail view
- `/admin/organizations/:id/locations/new` - Create location for specific organization
- `/admin/organizations/:id/locations/:location_id/edit` - Edit location for specific organization

**Admin Routes (Missing)**:
- `/admin/organizations/locations` - Global location management interface

## Proposed Admin Location Management Journeys

### 1. **Primary Journey: Organization-Specific Location Management**
**Route**: `/admin/organizations/:id/locations/`
**Purpose**: Manage locations for a specific organization
**Access**: From organization detail page or direct link

**Features**:
- List all locations for the specific organization
- Add new location for the organization
- Edit existing locations
- Delete locations (with confirmation)
- View location-specific statistics
- Bulk operations (if needed)

**Navigation Flow**:
```
/admin/organizations → Click Organization → /admin/organizations/:id → 
Click "Manage Locations" → /admin/organizations/:id/locations/
```

### 2. **Secondary Journey: Global Location Search Interface**
**Route**: `/admin/organizations/locations`
**Purpose**: Search and manage locations across all organizations
**Access**: From admin dashboard navigation

**Features**:
- **Organization Search**: Primary search by organization name/domain
- **Location Search**: Secondary search within selected organization
- **Filtered Results**: Show locations based on search criteria
- **Pagination**: Handle large numbers of locations efficiently
- **Quick Actions**: Direct links to edit locations or parent organizations

**Interface Design**:
```
┌─────────────────────────────────────────────────────────────┐
│ Organization Locations Management                           │
├─────────────────────────────────────────────────────────────┤
│ Search Organization: [_________________] [Search]           │
│                                                             │
│ ┌─ Selected: Example Corp (example.com) ─────────────────┐  │
│ │ Locations (3):                                        │  │
│ │ • London Office    - 123 Main St      [Edit] [View]  │  │
│ │ • Manchester Branch - 456 Oak Ave     [Edit] [View]  │  │
│ │ • Birmingham Hub   - 789 Elm St       [Edit] [View]  │  │
│ │                                       [+ New Location] │  │
│ └─────────────────────────────────────────────────────────┘  │
│                                                             │
│ Recent Organizations:                                       │
│ • Acme Corp (5 locations)                                  │
│ • Tech Solutions Ltd (2 locations)                         │
│ • Global Industries (8 locations)                          │
└─────────────────────────────────────────────────────────────┘
```

### 3. **Dashboard Integration Journey**
**Route**: `/admin` → Various location-related actions
**Purpose**: Quick access to location management from dashboard

**Features**:
- **Quick Stats**: Total locations, recent additions, locations needing attention
- **Recent Activity**: Recent location edits, new locations added
- **Quick Actions**: Search locations, add location, view problem locations

### 4. **User Support Journey**
**Route**: `/admin/users/:id` → Location context
**Purpose**: Help users with location-related issues

**Features**:
- **User's Organization Locations**: Show locations for the user's organization
- **Quick Links**: Direct links to manage user's organization locations
- **Context Switching**: Easy navigation between user admin and location admin

### 5. **System Monitoring Journey**
**Route**: `/admin/system` → Location metrics
**Purpose**: System-wide location analytics and monitoring

**Features**:
- **Location Statistics**: Distribution of locations by organization
- **Health Monitoring**: Locations with incomplete data
- **Usage Analytics**: Most/least used locations

## Implementation Plan

### Phase 1: Core Admin Location List (High Priority)
**Route**: `/admin/organizations/:id/locations/`
**File**: `lib/sertantai_web/live/admin/organizations/organization_locations_live.ex`

**Features**:
- List all locations for specific organization
- Add/Edit/Delete locations
- Proper breadcrumb navigation
- Integration with existing organization admin

### Phase 2: Global Location Search (Medium Priority)
**Route**: `/admin/organizations/locations`
**File**: `lib/sertantai_web/live/admin/organizations/locations_search_live.ex`

**Features**:
- Organization search interface
- Dynamic location loading
- Search-driven workflow
- Pagination and filtering

### Phase 3: Dashboard Integration (Low Priority)
**Enhancement**: Add location widgets to admin dashboard
**Features**:
- Location statistics
- Quick actions
- Recent activity

## Technical Implementation Details

### Database Queries
```elixir
# For organization-specific locations
def load_organization_locations(organization_id, opts \\ []) do
  OrganizationLocation
  |> Ash.Query.filter(organization_id == ^organization_id)
  |> Ash.Query.load([:organization])
  |> apply_pagination(opts)
  |> Ash.read(actor: actor)
end

# For global location search
def search_locations_by_organization(search_term, opts \\ []) do
  # First find matching organizations
  organizations = Organization
    |> Ash.Query.filter(contains(organization_name, ^search_term) or 
                       contains(email_domain, ^search_term))
    |> Ash.read(actor: actor)
  
  # Then load their locations
  organization_ids = Enum.map(organizations, & &1.id)
  
  OrganizationLocation
  |> Ash.Query.filter(organization_id in ^organization_ids)
  |> Ash.Query.load([:organization])
  |> apply_pagination(opts)
  |> Ash.read(actor: actor)
end
```

### Route Structure
```elixir
# Add to router.ex admin scope
live "/organizations/:id/locations", Organizations.OrganizationLocationsLive, :index
live "/organizations/:id/locations/new", Organizations.OrganizationLocationsLive, :new
live "/organizations/:id/locations/:location_id/edit", Organizations.OrganizationLocationsLive, :edit
live "/organizations/locations", Organizations.LocationsSearchLive, :index
```

### Navigation Updates
```elixir
# Admin menu - update to point to search interface
<.link patch={~p"/admin/organizations/locations"}>
  Organization Locations
</.link>

# Organization detail page - add locations tab
<.link patch={~p"/admin/organizations/#{@organization.id}/locations"}>
  Manage Locations (#{length(@organization.locations)})
</.link>
```

## User Experience Considerations

### 1. **Search-First Approach**
- Primary interface uses search to find organizations
- Prevents overwhelming admins with all locations at once
- Provides context-aware results

### 2. **Breadcrumb Navigation**
- Clear path: Admin → Organizations → [Org Name] → Locations
- Easy return to parent organization
- Consistent with existing admin patterns

### 3. **Contextual Information**
- Show organization context in location management
- Display location counts and statistics
- Provide quick links to related admin functions

### 4. **Performance Optimization**
- Lazy loading of locations
- Search-driven data fetching
- Efficient pagination
- Proper caching strategies

## Success Criteria

1. **Organization-Specific Location Management**: Admins can efficiently manage locations for any organization
2. **Global Location Discovery**: Admins can search and find locations across all organizations
3. **Intuitive Navigation**: Clear, logical flow between organization and location management
4. **Performance**: Fast search and efficient data loading
5. **Consistency**: Matches existing admin interface patterns and standards

## Migration Strategy

### Step 1: Implement Organization-Specific Route
- Create `/admin/organizations/:id/locations/` route
- Implement basic CRUD operations
- Add navigation from organization detail page

### Step 2: Implement Global Search Interface
- Create `/admin/organizations/locations` route
- Implement organization search functionality
- Add to admin menu navigation

### Step 3: Integration and Polish
- Add dashboard widgets
- Implement user support features
- Add system monitoring components

This approach provides a comprehensive solution that addresses both the immediate need for location management and the broader admin workflow requirements.