# Action Plan: UK LRT Record Selection Feature

## Objective
Extend the existing Elixir Phoenix + Ash application to allow users to select record sets from the 'uk_lrt' table using 'family' and 'family_ii' fields, preparing for future one-way sync to no-code databases.

## Action Plan

### Phase 1: Ash Resource & API Setup
1. **Ash Resource Configuration**
   - Review/update existing UkLrt Ash resource definition
   - Ensure 'family' and 'family_ii' fields are properly configured
   - Add read actions for filtering by family fields
   - Create aggregates for distinct family values if needed

2. **API Layer**
   - Add GraphQL/JSON API endpoints for UkLrt resource
   - Create queries for distinct 'family' and 'family_ii' values
   - Implement filtered record queries with pagination
   - Add bulk selection/filtering capabilities

### Phase 2: LiveView Interface
3. **LiveView Component Setup**
   - Create new LiveView: `UkLrtWeb.RecordSelectionLive`
   - Set up route in router.ex
   - Create basic page layout and navigation

4. **Selection Interface**
   - Build filter components for 'family' field (dropdown/multiselect)
   - Build filter components for 'family_ii' field (dropdown/multiselect)
   - Implement real-time filtering with LiveView updates
   - Add record count display and selection summary

5. **Results Display**
   - Create results table component with Phoenix LiveView
   - Implement pagination using Ash's built-in pagination
   - Add individual record selection (checkboxes)
   - Add bulk select/deselect functionality
   - Show selected records summary panel

### Phase 3: Data Management
6. **Selection State Management**
   - Store selected record IDs in LiveView state
   - Implement session persistence for selections
   - Add export functionality (CSV/JSON) for selected records
   - Create selection validation and limits

7. **Sync Preparation Layer**
   - Create Ash actions for preparing sync data
   - Add data transformation functions for Baserow/Airtable formats
   - Design sync configuration storage (future ElectricSQL integration)
   - Add sync job scheduling placeholder (Oban integration ready)

### Phase 4: Testing & Polish
8. **Testing**
   - Write ExUnit tests for Ash resource queries
   - Test LiveView interactions and state management
   - Add property-based tests for family field combinations
   - Test with large datasets and edge cases

9. **UI/UX Polish**
   - Add loading states and error handling
   - Implement proper Phoenix flash messages
   - Add responsive design for mobile/tablet
   - Create user feedback for all actions

## Technical Implementation Details
- **Ash Resource**: Extend existing UkLrt resource with selection-specific actions
- **LiveView**: Use Phoenix LiveView for real-time filtering and selection
- **Database**: Leverage existing Supabase connection through Ash
- **Styling**: Use existing CSS framework (Tailwind/Phoenix default)
- **Future Sync**: Prepare Ash actions for ElectricSQL integration

## File Structure Expected
```
lib/
├── your_app/
│   ├── uk_lrt/
│   │   ├── uk_lrt.ex (Ash resource)
│   │   └── selection.ex (selection logic)
├── your_app_web/
│   ├── live/
│   │   └── record_selection_live.ex
│   └── components/
│       ├── filter_component.ex
│       └── results_table_component.ex
```

## Success Criteria
- Users can filter uk_lrt records by family fields in real-time
- Selected records are clearly managed and exportable
- Interface is responsive and handles large datasets well
- Architecture supports future sync functionality
- All interactions work seamlessly with Phoenix LiveView

## Dependencies to Verify
- Ash GraphQL/JSON API extensions installed
- Phoenix LiveView properly configured
- Existing Supabase connection working through Ash
- Pagination and filtering capabilities in current Ash setup

Start with Phase 1 to ensure the Ash resource layer is properly configured, then move to the LiveView interface.
