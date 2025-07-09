# Test Memory Fix Context

## Issue
Running tests causes memory issues and crashes the terminal, losing all context. Tests need to run sequentially to avoid too many database connections.

## Changes Made

### 1. Modified test/test_helper.exs
Changed from:
```elixir
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Sertantai.Repo, :auto)
```

To:
```elixir
ExUnit.start(max_cases: 1)
Ecto.Adapters.SQL.Sandbox.mode(Sertantai.Repo, :manual)
```

**Explanation:**
- `max_cases: 1` forces tests to run sequentially (one at a time)
- `:manual` sandbox mode gives more control over database connections

### 2. Modified config/test.exs
Changed database pool size from:
```elixir
pool_size: 10,
```

To:
```elixir
pool_size: 2,
```

**Explanation:**
- Reduced pool size to minimize database connections
- With sequential tests, we don't need many connections

## Current Status
- ✅ Analyzed current test configuration for memory issues
- ✅ Configured tests to run sequentially with limited concurrency  
- ✅ Adjusted database pool size for tests
- 🔄 About to test the new configuration

## Test Files Found
- test/sertantai/accounts_test.exs
- test/sertantai/sync/sync_configuration_test.exs
- test/sertantai/sync/sync_service_test.exs
- test/sertantai_web/controllers/auth_controller_test.exs
- test/sertantai_web/controllers/error_html_test.exs
- test/sertantai_web/controllers/error_json_test.exs
- test/sertantai_web/controllers/page_controller_test.exs
- test/sertantai_web/live/dashboard_live_test.exs
- test/sertantai_web/live/auth_live_test.exs

## System Info
- CPU cores: 8
- Current branch: master
- Database: PostgreSQL with Ecto.Adapters.SQL.Sandbox

## Next Steps
1. Run `mix test --verbose` to test the new sequential configuration
2. Monitor memory usage during test execution
3. If issues persist, consider further reducing pool size or adding timeouts

## Additional Notes
The test configuration now uses manual sandbox mode which requires explicit database setup in each test, but provides better control over database connections and should prevent memory issues from concurrent database access.