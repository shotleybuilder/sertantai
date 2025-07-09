# AshAuthentication.Phoenix.Router LiveView Compatibility Bug Report

## Summary
The `require_authenticated_user` plug from `AshAuthentication.Phoenix.Router` causes Phoenix LiveView processes to crash with a "Killed" error during initialization, preventing authenticated LiveViews from mounting.

## Environment
- **Phoenix**: 1.7.21
- **LiveView**: 1.0.17
- **Ash**: 3.5.25
- **AshAuthentication**: 4.9.5
- **AshAuthentication.Phoenix**: 2.10.2
- **Elixir**: 1.16.2
- **Erlang**: 26.x

## Problem Description

### Expected Behavior
When a user authenticates successfully and accesses a LiveView protected by the `require_authenticated_user` plug, the LiveView should mount normally with the authenticated user available in the socket assigns.

### Actual Behavior
The LiveView process crashes with "Killed" error during initialization, before the `mount/3` callback is executed. The crash occurs after the authentication pipeline successfully loads the user from the database.

### Error Pattern
```
[debug] QUERY OK source="users" - User loaded successfully
[debug] Processing with MyApp.DashboardLive.nil/2
Killed - Process terminated before mount/3 execution
```

## Reproduction Steps

1. **Setup standard AshAuthentication.Phoenix router configuration:**
```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :require_authenticated_user do
    plug :require_authenticated_user
  end

  scope "/", MyAppWeb do
    pipe_through [:browser, :require_authenticated_user]
    
    live "/dashboard", DashboardLive  # This crashes
  end
end
```

2. **Create a simple LiveView:**
```elixir
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    {:ok, assign(socket, page_title: "Dashboard")}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Dashboard</h1>
      <p>Welcome, <%= @current_user.email %>!</p>
    </div>
    """
  end
end
```

3. **Authenticate a user** through the standard authentication flow
4. **Access the protected LiveView route** - the process crashes

## Investigation Results

### What Works
- ✅ Authentication through controllers works perfectly
- ✅ Session storage and retrieval works correctly
- ✅ LiveViews work without the authentication pipeline
- ✅ The `require_authenticated_user` plug works with regular controllers

### What Doesn't Work
- ❌ LiveViews with `require_authenticated_user` pipeline crash
- ❌ The crash occurs during LiveView process initialization
- ❌ No error details are provided, just "Killed"

### Root Cause
The issue appears to be in the interaction between the `require_authenticated_user` plug (provided by `AshAuthentication.Phoenix.Router`) and the LiveView process initialization. The plug successfully loads the user from the database, but something in the process causes the LiveView to crash before `mount/3` is executed.

## Workaround

The current workaround is to:

1. **Bypass the authentication pipeline for LiveViews:**
```elixir
pipeline :require_authenticated_user_liveview do
  plug :skip_authentication_for_liveview
end

def skip_authentication_for_liveview(conn, _opts) do
  conn
end
```

2. **Handle authentication manually in LiveView mount:**
```elixir
def mount(_params, session, socket) do
  case session["user"] do
    nil ->
      {:ok, redirect(socket, to: "/login")}
    user_token when is_binary(user_token) ->
      case extract_user_id_from_token(user_token) do
        {:ok, user_id} ->
          case Ash.get(MyApp.Accounts.User, user_id, domain: MyApp.Accounts) do
            {:ok, user} ->
              {:ok, assign(socket, current_user: user)}
            {:error, _} ->
              {:ok, redirect(socket, to: "/login")}
          end
        {:error, _} ->
          {:ok, redirect(socket, to: "/login")}
      end
  end
end

defp extract_user_id_from_token(token) do
  case String.split(token, "id=") do
    [_prefix, user_id] -> {:ok, user_id}
    _ -> {:error, "Invalid token format"}
  end
end
```

## Impact
This bug prevents the standard usage of AshAuthentication with Phoenix LiveView, requiring developers to implement custom authentication logic in each LiveView instead of using the provided authentication pipeline.

## Potential Causes
1. **Memory/Resource Issues**: The authentication process might be consuming too much memory
2. **Process Lifecycle Conflicts**: The plug might be interfering with LiveView process initialization
3. **Session Handling**: There might be an issue with how session data is passed to LiveView
4. **Timeout Issues**: The authentication process might be timing out

## Additional Context
- The session format used by AshAuthentication is: `"318ailbe6h3s84d0nk000053:user?id=eac62b64-662f-4de8-bf22-4440467a234c"`
- The bug only affects LiveViews, not regular controllers
- The authentication itself works - the issue is specifically with the LiveView process initialization
- No error logs are produced, just "Killed" indicating process termination

## Files Involved
- `AshAuthentication.Phoenix.Router` - Provides the `require_authenticated_user` plug
- `AshAuthentication.Phoenix.Plug` - Contains the authentication logic
- Phoenix LiveView initialization process

## Request
Please investigate the compatibility between `AshAuthentication.Phoenix.Router.require_authenticated_user` and Phoenix LiveView to resolve this crash and enable standard authentication workflows with LiveView.