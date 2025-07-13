# Authentication Troubleshooting Guide

This document captures key learnings from authentication issues encountered during development to prevent future developers from facing the same problems.

## Common Issues and Solutions

### 1. PostgreSQL citext Extension Error

**Problem**: 
```
invalid expression: email: The citext extension needs to be installed before email can be used. 
Please add "citext" to the list of installed_extensions in Sertantai.Repo.
```

**Root Cause**: 
Even though the citext extension exists in the database, Ash Framework needs it explicitly declared in the repo configuration.

**Solution**:
1. Verify extension exists: `psql -c "SELECT * FROM pg_extension WHERE extname = 'citext';"`
2. Ensure it's listed in `lib/sertantai/repo.ex`:
   ```elixir
   def installed_extensions do
     ["ash-functions", "uuid-ossp", "citext"]
   end
   ```
3. Restart the server after changes

### 2. Missing User Actions

**Problem**: 
```
KeyError) key :type not found in: nil
```
When trying to create forms for user profile updates.

**Root Cause**: 
User resource was missing the `:update` action in its action definitions.

**Solution**:
Add `:update` to the defaults in `lib/sertantai/accounts/user.ex`:
```elixir
actions do
  defaults [:read, :update]  # Add :update here
  # ... other actions
end
```

### 3. LiveView Authentication Session Loading

**Problem**: 
Users redirected to login even when authenticated, or `current_user` is nil in LiveView.

**Root Cause**: 
LiveView requires proper session configuration and resource assignment.

**Solution**:
1. **Router Configuration**: Ensure live_session is properly configured:
   ```elixir
   live_session :authenticated, 
     on_mount: AshAuthentication.Phoenix.LiveSession,
     session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []} do
     
     live "/profile", AuthLive, :profile
     live "/dashboard", DashboardLive
     # ... other protected routes
   end  # Don't forget to close the block!
   ```

2. **LiveView Mount**: Use AshAuthentication helper to load user:
   ```elixir
   defp assign_current_user_from_session(socket, session) do
     AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
   end
   ```

### 4. AshPhoenix.Form Syntax for Existing Records

**Problem**: 
Incorrect form creation syntax when working with existing user records.

**Solution**:
Use the resource instance as the first parameter:
```elixir
# Correct - pass the user instance
form = AshPhoenix.Form.for_action(current_user, :update, domain: Sertantai.Accounts)

# Incorrect - passing the module
form = AshPhoenix.Form.for_action(User, :update, initial: current_user)
```

## Database Setup Critical Rules

⚠️ **GOLDEN RULE**: After any code changes involving Ash resources, ALWAYS run:
1. `mix ash.codegen --check` (generate any needed migrations)
2. `mix ecto.migrate` (apply pending migrations)  
3. THEN start the server with `mix phx.server`

**Never let the app run ahead of the database schema!**

## Development Workflow

### Quick Authentication Test Commands

```bash
# 1. Check if server responds
curl -s http://localhost:4000/login | grep -o "Sign In"

# 2. Verify authentication redirect works
curl -s http://localhost:4000/profile | grep -o "redirected"

# 3. Check available test users
psql postgresql://postgres:postgres@localhost:5432/sertantai_dev -c "SELECT email FROM users;"
```

### Test Users Available

- `admin@sertantai.com`
- `test@sertantai.com` 
- `demo@sertantai.com`

Password for all test users: `test123!`

## Prevention Checklist

Before implementing authentication features:

- [ ] Verify all required PostgreSQL extensions are declared in `repo.ex`
- [ ] Ensure User resource has all needed actions (`:read`, `:update`, etc.)
- [ ] Check live_session configuration includes all protected routes
- [ ] Use correct AshPhoenix.Form syntax for existing vs new records
- [ ] Run migration pipeline before starting server
- [ ] Test authentication flow with existing test users

## Common Debugging Steps

1. **Check server logs** for specific error messages
2. **Verify database connection** and extension availability
3. **Review User resource actions** for missing operations
4. **Examine router configuration** for proper live_session setup
5. **Test with curl** to isolate authentication vs LiveView issues

## Related Files

- `lib/sertantai/repo.ex` - PostgreSQL extensions
- `lib/sertantai/accounts/user.ex` - User resource and actions
- `lib/sertantai_web/router.ex` - Authentication routing and live_session
- `lib/sertantai_web/live/auth_live.ex` - Authentication LiveView logic

---

*This guide should be updated whenever new authentication issues are discovered and resolved.*