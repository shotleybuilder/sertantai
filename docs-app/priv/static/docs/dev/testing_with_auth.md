# Testing with Authentication

## Overview

Testing LiveViews that require authentication in the Sertantai application presents unique challenges due to the specific session format expected by different components and database transaction boundaries.

## Key Learnings

### Authentication Patterns in Tests

The application uses different authentication patterns depending on the component:

1. **Admin Routes**: Use standard `log_in_user/2` helper with regular HTTP requests (`get`, `post`)
2. **LiveViews with Custom Authentication**: Require specific session token formats

### RecordSelectionLive Authentication Requirements

The `RecordSelectionLive` expects a specific session format that differs from standard AshAuthentication:

```elixir
# Expected session format
session["user"] = "token_prefix:user?id=#{user_id}"
```

### Test Helper for RecordSelectionLive

Create a custom session helper for LiveViews that expect token-based authentication:

```elixir
# Helper function to create proper session for RecordSelectionLive
defp create_records_session(conn, user) do
  # Create the token format that RecordSelectionLive expects
  user_token = "test_session_token:user?id=#{user.id}"
  conn
  |> init_test_session(%{"user" => user_token})
end
```

### Database Transaction Issues

**Problem**: LiveViews run in separate processes and may not have access to the same database transaction as the test setup.

**Symptoms**: 
- Test creates user successfully
- LiveView mount fails with "user not found" error
- Error: `Failed to load user: %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{...}]}`

**Root Cause**: The user created in test setup is within a database transaction that gets rolled back before the LiveView process can access it.

### Working Authentication Test Examples

#### Admin Route Tests (Working)
```elixir
test "admin user can access /admin route", %{conn: conn} do
  admin = user_fixture(%{role: :admin})
  
  conn = 
    conn
    |> log_in_user(admin)
    |> get(~p"/admin")
  
  assert html_response(conn, 200)
end
```

#### LiveView Tests (Problematic)
```elixir
test "LiveView with authentication", %{conn: conn, user: user} do
  authenticated_conn = create_records_session(conn, user)
  
  case live(authenticated_conn, "/records") do
    {:ok, view, html} ->
      # Test passes if user exists in database
    {:error, _} ->
      # Often fails due to transaction boundary issues
  end
end
```

### Solutions Attempted

1. **Custom Session Format**: ✅ Successfully created proper token format
2. **Manual Sandbox Checkout**: ✅ Using `async: false` and `Ecto.Adapters.SQL.Sandbox.checkout`  
3. **Database Transaction Issue**: 🔄 Still requires resolution

### Test Setup Patterns

#### Successful Pattern (Admin Tests)
```elixir
# Uses regular HTTP requests, not LiveView
use SertantaiWeb.ConnCase, async: true
```

#### Challenging Pattern (LiveView with Auth)
```elixir
# Requires LiveView process with database access
use SertantaiWeb.ConnCase, async: false

setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sertantai.Repo)
  # ... user creation
end
```

### Authentication Flow Analysis

#### Standard AshAuthentication
- Uses `AshAuthentication.Plug.Helpers.store_in_session/2`
- Creates session in format: `session["ash_authentication"]["user"]`

#### RecordSelectionLive Custom Format
- Expects: `session["user"]` as token string
- Token format: `"prefix:user?id=#{user_id}"`
- Uses custom `extract_user_id_from_token/1` function

### Recommendations for Future Tests

1. **For Admin Routes**: Continue using `log_in_user/2` with HTTP requests
2. **For Standard LiveViews**: Use AshAuthentication session format
3. **For Custom LiveViews**: Create specific session helpers matching expected format
4. **Database Issues**: Consider using `Ecto.Adapters.SQL.Sandbox.allow/3` for cross-process access

### Test File Examples

#### Working Auth Tests
- `/test/sertantai_web/controllers/auth_controller_test.exs`
- `/test/sertantai_web/live/admin/admin_route_integration_test.exs`
- `/test/sertantai_web/live/auth_live_test.exs` (login page)

#### Reference Scripts
- `/scripts/test_auth_debug.exs` - Database user verification
- `/scripts/test_role_auth.exs` - Role-based access testing

### Current Status

**Working**: Authentication format creation and session setup
**Blocked**: Database transaction boundary issues preventing LiveView tests from accessing test users

## Next Steps

1. Resolve database transaction issues for LiveView tests
2. Implement working TDD tests for Status dropdown behavior  
3. Use passing tests to fix Status dropdown display issues
4. Apply learnings to other LiveView authentication tests

## Key Files Modified

- `/test/sertantai_web/live/record_selection_live_test.exs` - Custom session helper
- `/test/support/conn_case.ex` - Standard `log_in_user/2` helper
- `/lib/sertantai_web/live/record_selection_live.ex` - Authentication expectations

## Updated Solutions (Session 2)

### Database Transaction Resolution ✅

**Problem Solved**: The database transaction boundary issue that prevented LiveView processes from accessing test data has been resolved.

**Root Cause**: LiveView processes run in separate Elixir processes and couldn't access data created within the test's database transaction when using `Ecto.Adapters.SQL.Sandbox` in `:manual` mode.

**Solution**: Use shared sandbox mode to allow LiveView processes to access the same database transaction as the test:

```elixir
# In test setup
setup do
  # Handle case where sandbox is already checked out
  case Ecto.Adapters.SQL.Sandbox.checkout(Sertantai.Repo) do
    :ok -> :ok
    {:already, :owner} -> :ok
  end
  
  # Enable shared mode so LiveView processes can access test data
  Ecto.Adapters.SQL.Sandbox.mode(Sertantai.Repo, {:shared, self()})
  
  # ... rest of setup
end
```

### Ash Changeset Creation Pattern ✅

**Problem**: Incorrect order of Ash changeset operations caused validation errors.

**Wrong Pattern**:
```elixir
# This fails with "Changeset has already been validated"
UkLrt
|> Ash.Changeset.for_create(:create)
|> Ash.Changeset.change_attributes(attrs)
|> Ash.create!(domain: Sertantai.Domain)
```

**Correct Pattern**:
```elixir
# Proper order: new -> change_attributes -> for_create -> create
UkLrt
|> Ash.Changeset.new()
|> Ash.Changeset.change_attributes(attrs)
|> Ash.Changeset.for_create(:create)
|> Ash.create!(domain: Sertantai.Domain)
```

### Working Test Configuration

```elixir
defmodule SertantaiWeb.RecordSelectionLiveTest do
  use SertantaiWeb.ConnCase, async: false  # Required for database sharing
  import Phoenix.LiveViewTest
  require Ash.Query
  import Ash.Expr
  
  # ... other aliases
  
  setup do
    # Handle sandbox checkout (supports multiple tests)
    case Ecto.Adapters.SQL.Sandbox.checkout(Sertantai.Repo) do
      :ok -> :ok
      {:already, :owner} -> :ok
    end
    
    # Critical: Enable shared mode for LiveView processes
    Ecto.Adapters.SQL.Sandbox.mode(Sertantai.Repo, {:shared, self()})
    
    # Create admin user with proper Ash pattern
    admin_user = 
      User
      |> Ash.Changeset.new()
      |> Ash.Changeset.change_attributes(%{
        email: "admin@example.com",
        password: "password123!",
        password_confirmation: "password123!",
        first_name: "Admin",
        last_name: "User",
        role: :admin,
        timezone: "UTC"
      })
      |> Ash.Changeset.for_create(:register_with_password)
      |> Ash.create!(domain: Sertantai.Accounts)
    
    %{user: admin_user}
  end
  
  # Tests now work reliably with authentication
  @tag :phase3
  test "search functionality works", %{conn: conn, user: user} do
    authenticated_conn = log_in_user(conn, user)
    
    {:ok, view, html} = live(authenticated_conn, "/records")
    # Test passes - LiveView can access the test user
    assert html =~ "Record Selection"
  end
end
```

### Key Requirements for LiveView Auth Tests

1. **Use `async: false`**: Required for database transaction sharing
2. **Add Ash imports**: `require Ash.Query` and `import Ash.Expr` for filter expressions
3. **Handle sandbox checkout**: Support multiple tests with `{:already, :owner}` case
4. **Enable shared mode**: Critical for LiveView process database access
5. **Use correct Ash patterns**: Follow `new -> change_attributes -> for_create -> create` order
6. **Include `password_confirmation`**: Required for `:register_with_password` action

### Database Schema Issues Resolution ✅

**Problem**: Ash resource field names that aren't GraphQL-compliant (like `:"2ndary_class"`) cause compilation errors.

**Solution**: 
1. Rename database columns to be GraphQL-compliant
2. Use direct SQL commands for production databases that can't use migrations
3. Update Ash resource snapshots to reflect new schema

```elixir
# Direct SQL for production column rename
ALTER TABLE uk_lrt RENAME COLUMN "2ndary_class" TO secondary_class;
```

### Working Test Results

All Phase 3 search functionality tests now pass:
- ✅ Search box rendering
- ✅ Search by title, family, and number fields  
- ✅ Case-insensitive search
- ✅ Search interaction with other filters
- ✅ Multi-field search capabilities

### Current Status Update

**Previous Status**: Blocked by database transaction boundary issues
**New Status**: ✅ **RESOLVED** - All authentication and database issues resolved

The testing framework now reliably supports:
- LiveView tests with authentication
- Complex database operations with Ash
- Cross-process database access for LiveView processes
- TDD development workflow for LiveView features