# Records View Improvements Plan

## Overview
This document outlines the improvements needed for the /records view table and filtering functionality. Each phase will be implemented using Test-Driven Development (TDD).

## TDD Approach
For each phase:
1. Write failing tests that describe the desired behavior
2. Run tests to confirm they fail
3. Implement the minimum code to make tests pass
4. Refactor while keeping tests green
5. Run full test suite to ensure no regressions

## Phase 1: Table Column Reorganization

### Tests to Write
- [ ] Test that table headers appear in correct order: SELECT | DETAIL | FAMILY | TITLE | YEAR | NUMBER | TYPE | STATUS
- [ ] Test that TITLE column displays `title_en` field value
- [ ] Test that law description (md_description) is not rendered in table
- [ ] Test that TYPE column displays `type_code` value
- [ ] Test that all column data aligns with headers

### Implementation Tasks
- [ ] Reorder columns to: SELECT | DETAIL | FAMILY | TITLE | YEAR | NUMBER | TYPE | STATUS
- [ ] Note: DETAIL column will be implemented in Phase 6
- [ ] Change NAME column to TITLE and use `title_en` field
- [ ] Remove the law description (md_description) from the table view
- [ ] Use `type_code` field for TYPE column instead of `type_desc`
- [ ] Ensure STATUS remains as the last column

## Phase 2: Filter Updates

### Tests to Write
- [ ] Test that Secondary Family filter is not rendered
- [ ] Test that Year filter is present and functional
- [ ] Test that Type Code filter shows distinct type codes
- [ ] Test that Status filter shows available status options
- [ ] Test that applying filters updates the records displayed
- [ ] Test that filter line separator is removed

### Implementation Tasks
- [ ] Remove Secondary Family filter (family_ii) as it's not displayed in the table
- [ ] Add Year filter (dropdown or range selector)
- [ ] Add Type Code filter (dropdown with distinct type codes)
- [ ] Add Status filter (dropdown with status options)
- [ ] Remove the horizontal line under filter controls

## Phase 3: Search Functionality

### Tests to Write
- [ ] Test that search box is rendered in the UI
- [ ] Test that entering search text filters records
- [ ] Test search across title_en field
- [ ] Test search across family field
- [ ] Test search across number field
- [ ] Test that search is case-insensitive
- [ ] Test that clearing search shows all records
- [ ] Test search interaction with other filters

### Implementation Tasks
- [ ] Add record search box above or within the filters section
- [ ] Implement search across relevant fields (title_en, family, number, etc.)
- [ ] Look at existing search implementations in the app for consistency
  - Check admin pages for search patterns
  - Reuse search components if available

## Phase 4: Row Selection Enhancement

### Tests to Write
- [ ] Test that clicking anywhere on a row toggles selection
- [ ] Test that row shows hover state on mouse over
- [ ] Test that checkbox reflects row selection state
- [ ] Test that clicking checkbox still works
- [ ] Test that selected rows have visual highlighting
- [ ] Test that row selection updates the selection count
- [ ] Test accessibility - row click with keyboard navigation

### Implementation Tasks
- [ ] Make entire table row clickable for selection/deselection
- [ ] Add hover state to indicate clickable rows
- [ ] Maintain checkbox for visual feedback but allow row click anywhere
- [ ] Ensure row highlighting when selected

## Phase 5: Sortable Columns

### Tests to Write
- [ ] Test that column headers show sort indicators
- [ ] Test clicking FAMILY header sorts alphabetically
- [ ] Test clicking TITLE header sorts alphabetically
- [ ] Test clicking YEAR header sorts numerically
- [ ] Test clicking NUMBER header sorts alphanumerically
- [ ] Test clicking TYPE header sorts by type code
- [ ] Test clicking STATUS header sorts by status order
- [ ] Test that clicking header toggles between ASC/DESC
- [ ] Test that current sort column is visually indicated
- [ ] Test that sorting maintains current filter/search state
- [ ] Test pagination resets to page 1 on sort change

### Implementation Tasks
- [ ] Add sort indicators to column headers
- [ ] Implement sorting for all columns:
  - FAMILY (alphabetical)
  - TITLE (alphabetical)
  - YEAR (numerical)
  - NUMBER (alphanumerical)
  - TYPE (alphabetical by code)
  - STATUS (by status order)
- [ ] Look at existing sortable table implementations in admin pages
- [ ] Add visual indicators for current sort column and direction

## Phase 6: Record Detail Modal

### Tests to Write
- [ ] Test that detail view control appears after SELECT column and before FAMILY
- [ ] Test that clicking detail control opens a modal
- [ ] Test that modal displays record details (placeholder content for now)
- [ ] Test that modal can be closed via close button
- [ ] Test that modal can be closed via escape key
- [ ] Test that modal can be closed by clicking outside
- [ ] Test that opening modal doesn't affect row selection
- [ ] Test that modal is accessible (proper ARIA attributes)
- [ ] Test that only one modal can be open at a time

### Implementation Tasks
- [ ] Add detail view control column after SELECT, before FAMILY
- [ ] Use appropriate icon (e.g., eye icon or info icon)
- [ ] Implement modal component for record details
- [ ] Add modal open/close logic to LiveView
- [ ] Ensure modal is properly styled and responsive
- [ ] Add loading state if record details need to be fetched
- [ ] Look at existing modal implementations in the app

### Modal Content (To Be Defined)
- [ ] Placeholder for detailed record information
- [ ] Structure to be determined in future phases
- [ ] Consider tabs or sections for different types of information

## Implementation Notes
- Most features (search, sortable columns) are already implemented elsewhere in the app
- Check admin LiveViews for reusable components and patterns
- Maintain consistency with existing UI patterns
- Ensure all changes work with the existing pagination and selection persistence

## Technical Considerations
- Update Ash queries to include new filter parameters
- Ensure proper indexing for searchable and sortable fields
- Maintain audit logging for all user interactions
- Test with large datasets to ensure performance

## Testing Strategy
1. **Unit Tests**: Test individual functions for filtering, sorting, and search
2. **LiveView Tests**: Test user interactions and UI updates
3. **Integration Tests**: Test full workflows with multiple filters and actions
4. **Performance Tests**: Ensure acceptable response times with full dataset

## Running Tests
- Run specific test file: `mix test test/sertantai_web/live/record_selection_live_test.exs`
- Run with specific tag: `mix test --only phase1`
- Run all tests: `mix test`
- Watch mode for TDD: `mix test.watch` (if available)