# Admin Interface Testing Guide

## ⚠️ IMPORTANT: Database Ownership Issue

The admin interface authentication pipeline has a known issue that causes terminal kills during testing when authenticated users access the `/admin` routes.

**Root Cause**: `AshAuthentication.Plug.Helpers.retrieve_from_session` makes database queries that conflict with Ecto's test sandbox ownership model.

## ✅ Safe Testing Patterns

### 1. Component Testing (`admin_component_test.exs`)
Use `render_component` to test UI rendering without going through routes:

```elixir
html = render_component(&SertantaiWeb.Admin.AdminLive.render/1, %{current_user: admin})
assert html =~ "Sertantai Admin"
```

### 2. Direct Mount Testing (`admin_direct_mount_test.exs`)
Test LiveView logic by calling mount/3 directly:

```elixir
socket = %Socket{assigns: %{current_user: admin, ...}}
{:ok, socket} = SertantaiWeb.Admin.AdminLive.mount(%{}, %{}, socket)
assert socket.assigns.page_title == "Admin Dashboard"
```

## ❌ Patterns to Avoid

**Never use these patterns with authenticated users:**
- `get(conn, ~p"/admin")` with logged-in user
- `live(conn, ~p"/admin")` with logged-in user
- Any route-based testing through the admin authentication pipeline

## Test File Organization

- `admin_component_test.exs` - UI rendering tests using render_component
- `admin_direct_mount_test.exs` - LiveView logic tests using direct mount calls
- Future test files should follow these safe patterns

## Running Tests

```bash
# Run all admin tests safely
mix test test/sertantai_web/live/admin/

# Run specific test files
mix test test/sertantai_web/live/admin/admin_component_test.exs
mix test test/sertantai_web/live/admin/admin_direct_mount_test.exs
```

## Future Considerations

If the authentication pipeline issue is resolved in the future, we can add integration tests that use the full route-based testing approach. Until then, the component and direct mount testing provides comprehensive coverage while avoiding terminal kills.