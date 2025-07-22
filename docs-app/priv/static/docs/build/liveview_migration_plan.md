---
title: "LiveView Migration Plan: DocController → DocLive"
category: "build"
tags: ["liveview", "migration", "phoenix", "development"]
priority: "high"
author: "Development Team"
description: "Step-by-step plan to migrate documentation pages from Phoenix controller to LiveView for interactive features"
status: "live"
---

# LiveView Migration Plan: DocController → DocLive

## Current Status ✅

- **App compiles successfully** 
- **Home page renders** (still using DocController)
- **Router updated** to use `live "/:category/:page", DocLive`
- **Basic DocLive created** with event handlers for sorting

## Problem Analysis 🔍

**Test Results**: 61/64 LiveView tests failing

**Root Cause Categories**:

1. ✅ **Missing Navigation Module** - `SertantaiDocs.Navigation.get_navigation_items/0` undefined (**FIXED**)
2. **Route Mismatch** - Tests use `/build` but LiveView route expects `/:category/:page`
3. **Session Issues** - `{:error, :nosession}` errors in tests  
4. **Missing Dependencies** - LiveView expects certain modules/functions that don't exist
5. **State Management** - Tests assume certain assigns that aren't initialized

## Migration Priority Phases 📋

### Phase 1: Critical Dependencies (HIGH PRIORITY)
**Goal**: Fix module dependencies so DocLive can mount

**Tasks**:
1. **Create `SertantaiDocs.Navigation` module**
   - Implement `get_navigation_items/0` function
   - Extract navigation logic from existing components/controllers
   - Status: 🔴 **BLOCKING** - prevents LiveView mounting

2. **Fix MarkdownProcessor integration**
   - Ensure `MarkdownProcessor.process_file/1` works in LiveView context
   - Handle file loading in LiveView mount
   - Status: 🔴 **BLOCKING** - needed for content rendering

**Success Criteria**: DocLive can mount without UndefinedFunctionError

### Phase 2: Session and Context (HIGH PRIORITY)  
**Goal**: Fix session handling and LiveView context issues

**Tasks**:
1. **Fix session handling in tests**
   - Investigate `{:error, :nosession}` errors
   - Ensure proper test setup for LiveView
   - May need to add session configuration to tests

2. **Review LiveView test patterns**
   - Check if tests are using correct `live/2` function calls
   - Ensure proper ConnCase setup for LiveView tests

**Success Criteria**: Tests can successfully mount LiveView without session errors

### Phase 3: State Management (MEDIUM PRIORITY)
**Goal**: Implement proper state management for filters/sorting

**Tasks**:
1. **Implement filtering logic**
   - Create proper `apply_filters_and_sort/2` function
   - Handle navigation item filtering by status, category, priority, etc.

2. **Add comprehensive assigns**
   - Ensure all assigns expected by `nav_sidebar` component are present
   - Handle navigation state properly

**Success Criteria**: Navigation filtering and sorting work correctly

### Phase 4: Event Handlers (MEDIUM PRIORITY)
**Goal**: Complete all LiveView event handling

**Tasks**:
1. **Implement all missing event handlers**
   - `search-query-change`
   - `toggle-tag-filter` 
   - Any other events called by components

2. **Test event interactions**
   - Ensure events properly update state
   - Verify UI updates correctly

**Success Criteria**: All interactive features work as expected

### Phase 5: Test Compatibility (LOW PRIORITY)
**Goal**: Update or fix failing tests

**Tasks**:
1. **Review test expectations**
   - Some tests may have incorrect expectations for LiveView behavior
   - Update tests to match new LiveView architecture

2. **Add missing test utilities**
   - May need helper functions for LiveView testing

**Success Criteria**: All tests pass

## Implementation Strategy 🛠️

### Approach: Incremental Migration

1. **Keep DocController as fallback**
   - Don't remove DocController until LiveView is fully working
   - Can add router condition to switch between controller/LiveView

2. **Parallel development**
   - Fix issues in DocLive while keeping existing functionality intact
   - Test with specific routes first

3. **Component compatibility**
   - Ensure `nav_sidebar` and related components work in both contexts
   - May need to make components more flexible

## Current Implementation Status 📊

### ✅ Completed
- Basic DocLive structure
- Event handler stubs (`change-sort`, `toggle-sort-order`, etc.)
- Router configuration
- Basic mount/render functions

### 🔄 In Progress  
- Navigation module creation (Phase 1)

### ❌ Todo
- Session handling fixes (Phase 2)
- Complete filtering logic (Phase 3)
- Missing event handlers (Phase 4)
- Test updates (Phase 5)

## Risk Assessment ⚠️

**High Risk**:
- **Breaking existing functionality** - need to maintain DocController fallback
- **Complex state management** - navigation filtering/sorting is complex

**Medium Risk**:
- **Test suite maintenance** - many tests will need updates
- **Performance impact** - LiveView has different performance characteristics

**Low Risk**:
- **User experience** - changes should be transparent to users
- **Deployment** - should be backwards compatible

## Next Immediate Steps 🎯

1. **Create SertantaiDocs.Navigation module** (BLOCKING)
2. **Test basic LiveView mounting** 
3. **Fix session issues in one test file**
4. **Gradually work through remaining failures**

## Success Metrics 📈

- **Functionality**: Sort dropdown works correctly
- **Tests**: All LiveView tests pass
- **Performance**: Page load times remain acceptable  
- **UX**: No regression in user experience
- **Maintainability**: Code is cleaner with proper state management

## Rollback Plan 🔙

If migration faces major issues:
1. Revert router to use DocController
2. Keep LiveView code for future iteration
3. Implement JavaScript-based dropdown as temporary fix
4. Plan more gradual migration approach

---

This plan provides a structured approach to completing the LiveView migration while minimizing risk and maintaining functionality.