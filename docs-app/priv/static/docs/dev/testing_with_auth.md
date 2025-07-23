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