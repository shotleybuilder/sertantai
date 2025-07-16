# Admin Test Execution Plan

## Test Order (Most to Least Likely to Fail)

### 1. **User List Live Tests** (HIGHEST RISK)
```bash
mix test test/sertantai_web/live/admin/users/user_list_live_test.exs
```
- Most complex, likely loads many users
- Potential for large data queries
- LiveView with real-time updates

### 2. **Organization List Live Tests**
```bash
mix test test/sertantai_web/live/admin/organizations/organization_list_live_test.exs
```
- Similar complexity to user list
- May load related data (locations, users)
- Pagination and filtering logic

### 3. **Organization Detail Live Tests**
```bash
mix test test/sertantai_web/live/admin/organizations/organization_detail_live_test.exs
```
- Single record but with nested data
- May load associated records

### 4. **Sync List Live Tests**
```bash
mix test test/sertantai_web/live/admin/sync/sync_list_live_test.exs
```
- Sync configs with relationships
- Potentially complex queries

### 5. **User Form Component Tests**
```bash
mix test test/sertantai_web/live/admin/users/user_form_component_test.exs
```
- Form validation and submission
- Less likely to cause memory issues

### 6. **Admin Table Component Tests**
```bash
mix test test/sertantai_web/live/admin/components/admin_table_test.exs
```
- UI component testing
- Isolated from database

### 7. **Admin Modal Component Tests**
```bash
mix test test/sertantai_web/live/admin/components/admin_modal_test.exs
```
- Simple UI component
- No database interaction

### 8. **Admin Form Component Tests**
```bash
mix test test/sertantai_web/live/admin/components/admin_form_test.exs
```
- Form rendering only
- No database queries

### 9. **Admin Direct Mount Tests** (SAFEST)
```bash
mix test test/sertantai_web/live/admin/admin_direct_mount_test.exs
```
- Uses safe mount pattern
- Bypasses authentication pipeline

### 10. **Admin Component Tests** (SAFEST)
```bash
mix test test/sertantai_web/live/admin/admin_component_test.exs
```
- Pure rendering tests
- No LiveView lifecycle

## Running Tests Safely

1. Run each test individually to isolate failures
2. Monitor memory usage during test execution
3. If a test kills the terminal, note which one and skip to the next
4. Look for patterns in failures (e.g., all list views fail)

## Debugging Commands

```bash
# Run with increased logging
MIX_ENV=test mix test test/sertantai_web/live/admin/users/user_list_live_test.exs --trace

# Run specific test
mix test test/sertantai_web/live/admin/users/user_list_live_test.exs:LINE_NUMBER
```