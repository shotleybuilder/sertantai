# Authentication Debug Context

## Problem Summary
The Phoenix LiveView application was experiencing authentication issues where login would work but accessing the dashboard would crash with "Killed" error, losing all terminal context.

## Issues Found and Fixed

### 1. **Test Memory Issues** ✅ FIXED
- **Problem**: Running tests caused memory issues and terminal crashes
- **Solution**: 
  - Modified `test/test_helper.exs`: `ExUnit.start(max_cases: 1)` and `Ecto.Adapters.SQL.Sandbox.mode(Sertantai.Repo, :manual)`
  - Modified `config/test.exs`: Reduced `pool_size` from 10 to 2
  - Moved test files to proper locations and updated to use `Sertantai.DataCase`

### 2. **Missing Test User** ✅ FIXED
- **Problem**: `test@sertantai.com` user didn't exist in database
- **Solution**: Created user manually using `Ash.create`
- **Credentials**: `test@sertantai.com` / `test123!`

### 3. **Login Authentication Flow** ✅ FIXED
- **Problem**: Login form was using LiveView but couldn't store user in session
- **Solution**: Changed login form to POST directly to `/auth/user/password/sign_in`
- **Files Modified**:
  - `lib/sertantai_web/live/auth_live.html.heex`: Changed from LiveView form to HTML form
  - `lib/sertantai_web/live/auth_live.ex`: Simplified login handler
  - Fixed CSRF token: `Plug.CSRFProtection.get_csrf_token()`

### 4. **Dashboard Crash Issue** 🔍 CURRENT ISSUE
- **Problem**: Dashboard crashes with "Killed" after successful login
- **Root Cause**: The `require_authenticated_user` plug from AshAuthentication.Phoenix.Router conflicts with LiveView
- **Investigation Results**:
  - ✅ Dashboard works without authentication pipeline (`/dashboard-test`)
  - ❌ Dashboard crashes with authentication pipeline (`/dashboard`)
  - ✅ User authentication and session storage works correctly
  - ❌ `require_authenticated_user` plug causes LiveView process to crash

## Current State

### Working Components
- ✅ User login and authentication
- ✅ Session storage via `AuthController`
- ✅ LiveView functionality (when bypassing auth pipeline)
- ✅ Database queries and user loading

### Files Modified
```
lib/sertantai_web/live/auth_live.html.heex   - Fixed login form
lib/sertantai_web/live/auth_live.ex          - Simplified login handler  
lib/sertantai_web/router.ex                 - Added test routes and custom pipeline
lib/sertantai_web/live/dashboard_live.ex    - Simplified for debugging
test/test_helper.exs                         - Fixed memory issues
config/test.exs                              - Reduced pool size
```

### Key Routes
- `/login` - Login form (works)
- `/auth/user/password/sign_in` - Authentication endpoint (works)
- `/dashboard` - Protected dashboard (crashes due to auth pipeline)
- `/dashboard-test` - Unprotected dashboard (works)

### Authentication Flow
1. User enters credentials on `/login`
2. Form POSTs to `/auth/user/password/sign_in`
3. `AuthController.success/4` stores user in session
4. User redirected to `/dashboard`
5. **CRASH OCCURS**: `require_authenticated_user` plug conflicts with LiveView

## Next Steps

### Immediate Solution
1. Test dashboard with bypass authentication pipeline
2. Implement authentication within LiveView mount function
3. Replace problematic pipeline with custom solution

### Code to Test
```elixir
# In router.ex - bypass auth pipeline for LiveView
pipeline :require_authenticated_user_liveview do
  plug :skip_authentication_for_liveview
end

def skip_authentication_for_liveview(conn, _opts) do
  conn
end
```

### Proposed LiveView Authentication
```elixir
# In dashboard_live.ex mount function
def mount(_params, session, socket) do
  case AshAuthentication.Plug.Helpers.retrieve_from_session(session, Sertantai.Accounts.User) do
    {:ok, user} ->
      {:ok, assign(socket, current_user: user, ...)}
    {:error, _} ->
      {:ok, redirect(socket, to: "/login")}
  end
end
```

## Technical Details

### Database
- PostgreSQL with Ecto
- User table with proper authentication setup
- Test user: `test@sertantai.com` / `test123!`

### Authentication Stack
- Ash Framework 3.0+
- AshAuthentication with Phoenix integration
- Bcrypt for password hashing
- Session-based authentication

### Error Pattern
```
[debug] QUERY OK source="users" - User loaded successfully
[debug] Processing with SertantaiWeb.DashboardLive.nil/2
Killed - Process terminated before mount/3 execution
```

## Files to Reference

### Key Configuration Files
- `lib/sertantai_web/router.ex` - Route and pipeline configuration
- `lib/sertantai_web/controllers/auth_controller.ex` - Session management
- `lib/sertantai_web/live/dashboard_live.ex` - Dashboard LiveView
- `lib/sertantai_web.ex` - LiveView configuration

### Test Files
- `test/sertantai/accounts/credential_auth_test.exs` - Authentication tests
- `test/sertantai/accounts/registration_test.exs` - Registration tests
- `test_memory_fix_context.md` - Memory issue documentation

## Important Notes
- The issue is NOT with the LiveView code itself
- The issue is NOT with the template rendering
- The issue IS with the authentication pipeline conflicting with LiveView process initialization
- User authentication works correctly - the problem is in the authorization pipeline