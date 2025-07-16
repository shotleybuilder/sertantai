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

### 5. LiveView Testing Authentication

**Problem**: 
LiveView tests failing with authentication redirects when using standard test helpers.

**Root Cause**: 
Standard Phoenix test helpers like `conn |> assign(:current_user, user)` don't work with LiveView because LiveView gets authentication from session, not connection assigns.

**Solution**:
1. **Proper Test Helper**: Use AshAuthentication session storage in test helpers:
   ```elixir
   # In test/support/conn_case.ex
   def log_in_user(conn, user) do
     conn
     |> Phoenix.ConnTest.init_test_session(%{})
     |> AshAuthentication.Plug.Helpers.store_in_session(user)
   end
   ```

2. **LiveView Mount Pattern**: Ensure LiveView uses same authentication loading as working LiveViews:
   ```elixir
   def mount(_params, session, socket) do
     # Load current user from session using AshAuthentication
     socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
     current_user = socket.assigns[:current_user]

     if current_user do
       # User authenticated logic
     else
       # Redirect to login
       {:ok, redirect(socket, to: ~p"/login")}
     end
   end
   ```

3. **Test Redirect Assertions**: When testing LiveView redirects, use proper pattern matching:
   ```elixir
   # For users without organization (redirect to register)
   assert {:error, {:redirect, %{to: "/organizations/register", flash: flash}}} = 
     live(conn, ~p"/organizations")
   assert flash["info"] == "You haven't registered an organization yet."

   # For successful page loads
   {:ok, view, html} = live(conn, ~p"/organizations")
   assert html =~ "Organization Profile"
   ```

### 6. Ash Resource Action Specification

**Problem**: 
Runtime errors like "Required primary update action" when calling `Ash.update/3`.

**Root Cause**: 
Ash resources may not have a primary update action defined, requiring explicit action specification.

**Solution**:
Always specify the action explicitly:
```elixir
# Correct - specify action explicitly
case Ash.update(organization, %{
  organization_name: params["organization_name"],
  organization_attrs: attrs
}, action: :update, domain: MyApp.Organizations) do

# Incorrect - relying on primary action
case Ash.update(organization, %{...}, domain: MyApp.Organizations) do
```

### 7. Form Parameter Handling in LiveView

**Problem**: 
Form submissions failing with mismatched parameter names between template and handle_event.

**Root Cause**: 
Phoenix forms generate parameters based on the form's `for` attribute, not the resource name.

**Solution**:
1. **Template Form Declaration**: 
   ```elixir
   <.form for={@form} id="org-form" phx-submit="save">
   ```

2. **Handle Event Pattern Matching**:
   ```elixir
   # Correct - matches the form name
   def handle_event("save", %{"form" => params}, socket) do

   # Incorrect - assumes resource name
   def handle_event("save", %{"organization" => params}, socket) do
   ```

3. **Test Form Submission**:
   ```elixir
   # Correct - use "form" key
   view
   |> form("#org-form", form: %{organization_name: "New Name"})
   |> render_submit()

   # Incorrect - using resource name
   view
   |> form("#org-form", organization: %{organization_name: "New Name"})
   |> render_submit()
   ```

### 8. Error Handling in LiveView Updates

**Problem**: 
Protocol errors when trying to convert Ash error structs to forms.

**Root Cause**: 
Ash returns `Ash.Error.Invalid` structs on validation failures, which can't be converted to Phoenix forms.

**Solution**:
Handle error cases by creating fresh forms:
```elixir
case Ash.update(resource, params, action: :update, domain: MyDomain) do
  {:ok, updated_resource} ->
    # Success case
    form = AshPhoenix.Form.for_action(updated_resource, :update, domain: MyDomain)
    {:noreply, assign(socket, :form, to_form(form))}

  {:error, _error} ->
    # Error case - create fresh form, don't try to convert error
    form = AshPhoenix.Form.for_action(original_resource, :update, domain: MyDomain)
    {:noreply, 
     socket
     |> assign(:form, to_form(form))
     |> put_flash(:error, "Update failed")}
end
```

### 9. Missing `load_from_session` Function Generation

**Problem**: 
AshAuthentication documentation shows using `plug :load_from_session` in router pipelines, but this function is not generated by `use AshAuthentication.Phoenix.Router`.

**Expected Documentation Behavior**:
```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAuthentication.Phoenix.Router  # Should generate :load_from_session
  
  pipeline :browser do
    plug :load_from_session  # Documentation says this should work
  end
end
```

**Actual Behavior**: 
The `:load_from_session` function is not generated, causing `UndefinedFunctionError` when the router is called.

**Root Cause**: 
Inconsistency between AshAuthentication documentation examples and actual macro behavior. The `use AshAuthentication.Phoenix.Router` does not generate the expected session loading function.

**Workaround Solution**:
Create a custom session loading function that manually calls the underlying AshAuthentication helpers:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAuthentication.Phoenix.Router
  
  pipeline :browser do
    plug :load_current_user  # Custom function instead
  end
  
  # Custom session loading function
  def load_current_user(conn, _opts) do
    # retrieve_from_session loads users and stores them in assigns with current_ prefix
    conn = AshAuthentication.Plug.Helpers.retrieve_from_session(conn, :my_app)
    
    # The user should now be in conn.assigns.current_user
    case conn.assigns[:current_user] do
      nil ->
        conn
      _user ->
        # Set the actor for Ash authorization
        AshAuthentication.Plug.Helpers.set_actor(conn, :user)
    end
  end
end
```

**Key Points**:
- Replace `:my_app` with your actual OTP application name
- The `retrieve_from_session/2` function loads users into assigns with `current_` prefix
- `set_actor/2` expects the subject name (`:user`) not the user object
- This approach works for both regular HTTP routes and LiveViews when combined with proper `live_session` configuration

**Related Issue**: 
This affects admin route authentication where LiveViews need both the browser pipeline session loading AND proper `live_session` configuration:

```elixir
scope "/admin", MyAppWeb.Admin do
  pipe_through [:browser, :require_admin_authentication]
  
  live_session :admin,
    on_mount: AshAuthentication.Phoenix.LiveSession,
    session: {AshAuthentication.Phoenix.LiveSession, :generate_session, []} do
    
    live "/", AdminLive, :dashboard
    # ... other admin routes
  end
end
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

Before writing LiveView tests with authentication:

- [ ] Use `AshAuthentication.Plug.Helpers.store_in_session/2` in test helpers
- [ ] Ensure LiveView mount uses `AshAuthentication.Phoenix.LiveSession.assign_new_resources/2`
- [ ] Test both authenticated and unauthenticated access patterns
- [ ] Use proper redirect assertion patterns for LiveView tests
- [ ] Specify Ash actions explicitly in all update operations
- [ ] Match form parameter names correctly in handle_event functions
- [ ] Handle Ash error responses properly without trying to convert to forms

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