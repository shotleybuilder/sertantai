---
title: "Supabase PostgreSQL Connection Guide"
description: "Complete guide for connecting to Supabase PostgreSQL databases with troubleshooting"
category: "Development"
tags: ["supabase", "postgresql", "database", "connection", "troubleshooting"]
author: "Development Team"
date: "2025-01-22"
updated: "2025-01-22"
---

# Supabase PostgreSQL Connection Guide

A comprehensive guide for connecting to Supabase PostgreSQL databases, including troubleshooting common issues and connection methods.

## Overview

Supabase provides PostgreSQL databases with multiple connection options. This guide covers the most reliable connection methods and common troubleshooting steps.

## Connection Methods

### Method 1: Pooler Connection (Recommended)

The pooler connection is the most reliable method for production applications and scripts.

**Configuration:**
```elixir
pooler_config = [
  username: "postgres.PROJECT_ID",
  password: "YOUR_DB_PASSWORD", 
  hostname: "aws-0-eu-west-2.pooler.supabase.com",
  database: "postgres",
  port: 6543,
  ssl: true,
  ssl_opts: [verify: :verify_none],
  # Optimization settings for stability
  pool_size: 1,
  queue_target: 10000,
  queue_interval: 5000,
  timeout: 30000,
  connect_timeout: 30000
]
```

**Advantages:**
- ✅ Most stable for high-frequency operations
- ✅ Better connection pooling
- ✅ Handles connection limits efficiently
- ✅ Works well for batch operations

### Method 2: Direct Connection

Direct connection to the Supabase database server.

**Configuration:**
```elixir
direct_config = [
  username: "postgres.PROJECT_ID",
  password: "YOUR_PASSWORD",
  hostname: "PROJECT_ID.supabase.co", 
  database: "postgres",
  port: 5432,
  ssl: true,
  ssl_opts: [verify: :verify_none]
]
```

**Limitations:**
- ⚠️ May have query timeout issues under load
- ⚠️ Less reliable for batch operations
- ⚠️ Connection limits may be hit faster

### Method 3: DATABASE_URL Parsing

Parse connection details from a DATABASE_URL environment variable.

**Configuration:**
```elixir
database_url = System.get_env("DATABASE_URL")
uri = URI.parse(database_url)

parsed_config = [
  username: uri.userinfo |> String.split(":") |> List.first(),
  password: uri.userinfo |> String.split(":") |> List.last(),
  hostname: uri.host,
  database: String.trim_leading(uri.path, "/"),
  port: uri.port,
  ssl: true,
  ssl_opts: [verify: :verify_none]
]
```

## Environment Variables Setup

Create these environment variables in your system (never commit these to code):

```bash
# Core Supabase Settings
export SUPABASE_PROJECT_ID="your-project-id"
export SUPABASE_PASSWORD="your-regular-password"  
export SUPABASE_DB_PASSWORD="your-db-specific-password"

# Connection Hosts
export SUPABASE_POOLER_HOST="aws-0-eu-west-2.pooler.supabase.com"
export SUPABASE_HOST="your-project-id.supabase.co"

# Optional: Full DATABASE_URL
export DATABASE_URL="postgresql://postgres:password@db.project-id.supabase.co:5432/postgres"
```

## Testing Connections

Use this test script to verify all connection methods:

```elixir
# Test script: scripts/test_connections.exs

IO.puts("=== Testing Supabase Connections ===")

# Test Pooler Connection
pooler_config = [
  username: "postgres.#{System.get_env("SUPABASE_PROJECT_ID")}",
  password: System.get_env("SUPABASE_DB_PASSWORD"),
  hostname: System.get_env("SUPABASE_POOLER_HOST"),
  database: "postgres",
  port: 6543,
  ssl: true,
  ssl_opts: [verify: :verify_none]
]

case Postgrex.start_link(pooler_config) do
  {:ok, conn} ->
    IO.puts("✅ Pooler connection successful")
    {:ok, result} = Postgrex.query(conn, "SELECT version()", [])
    IO.puts("✅ Query successful")
    GenServer.stop(conn)
  {:error, error} ->
    IO.puts("❌ Pooler connection failed: #{inspect(error)}")
end
```

## Common Issues & Troubleshooting

### Issue 1: "Tenant or user not found"

**Symptoms:**
```
** (Postgrex.Error) FATAL XX000 (internal_error) Tenant or user not found
```

**Solutions:**
1. **Check Project Status**: Ensure your Supabase project is not paused
2. **Verify Credentials**: Double-check PROJECT_ID and passwords
3. **Use Correct Password**: Use DB-specific password, not regular password
4. **Try Pooler Connection**: Switch to pooler host instead of direct connection

### Issue 2: DNS Resolution Failures

**Symptoms:**
```
** (DBConnection.ConnectionError) tcp connect (hostname): non-existing domain - :nxdomain
```

**Solutions:**
1. **Project Paused**: Check if your Supabase project is paused
2. **Use Pooler Host**: Pooler hosts are more reliable than direct project hosts
3. **DNS Cache**: Clear DNS cache or try different DNS servers
4. **Wait After Unpausing**: Allow time for DNS propagation after unpausing

### Issue 3: Connection Timeouts

**Symptoms:**
```
connection not available and request was dropped from queue after 4000ms
```

**Solutions:**
1. **Use Pooler Connection**: More reliable for sustained operations
2. **Increase Timeouts**: Add timeout and queue configuration
3. **Reduce Batch Size**: Process smaller batches with delays
4. **Add Connection Pooling**: Configure proper pool settings

### Issue 4: SSL Certificate Warnings

**Symptoms:**
```
[warning] setting ssl: true on your database connection offers only limited protection
```

**Solution:**
This warning is expected when using `verify: :verify_none`. For production, consider proper SSL certificate verification.

## Best Practices

### For Production Applications

1. **Use Pooler Connections**: More reliable and scalable
2. **Configure Timeouts**: Set appropriate timeout values
3. **Environment Variables**: Never hardcode credentials
4. **Connection Pooling**: Configure proper pool sizes
5. **Error Handling**: Implement retry logic for transient failures

### For Development Scripts

1. **Test Connection First**: Always verify connectivity before operations
2. **Use Small Batches**: Process data in manageable chunks
3. **Add Delays**: Prevent overwhelming the database
4. **Monitor Project Status**: Check for project pausing

### For Import/Export Operations

```elixir
# Recommended configuration for data operations
config = [
  username: "postgres.#{System.get_env("SUPABASE_PROJECT_ID")}",
  password: System.get_env("SUPABASE_DB_PASSWORD"),
  hostname: System.get_env("SUPABASE_POOLER_HOST"),
  database: "postgres",
  port: 6543,
  ssl: true,
  ssl_opts: [verify: :verify_none],
  # Optimization for bulk operations
  pool_size: 1,
  queue_target: 10000,
  queue_interval: 5000,
  timeout: 30000,
  connect_timeout: 30000
]

# Process in small batches with delays
batch_size = 100
Process.sleep(1000) # Between batches
```

## Project Status Management

### Checking Project Status

1. Log into Supabase Dashboard
2. Navigate to your project
3. Check for "Paused" status indicator
4. Click "Resume" if paused

### After Resuming Paused Project

1. **Wait for DNS**: Allow 5-10 minutes for DNS propagation
2. **Test Connections**: Verify connectivity before running scripts
3. **Use Pooler**: Pooler connections typically restore faster
4. **Monitor Performance**: Initial queries may be slower after resuming

## Connection Testing Checklist

Before running important operations:

- [ ] Verify project is not paused
- [ ] Test pooler connection
- [ ] Confirm environment variables are loaded
- [ ] Run a simple query test
- [ ] Check for any SSL warnings
- [ ] Verify record counts match expectations

## Import Script Best Practices

Based on successful large-scale imports (e.g., importing 14,000+ type_code values), here are proven strategies:

### Environment Variables Configuration

**Load from ~/.bashrc instead of .env files:**
```bash
# Add to ~/.bashrc for better script reliability
export SUPABASE_PROJECT_ID="your-project-id"
export SUPABASE_DB_PASSWORD="your-db-password"  
export SUPABASE_POOLER_HOST="aws-0-eu-west-2.pooler.supabase.com"
```

**Script validation:**
```elixir
# Validate environment variables at script start
supabase_project_id = System.get_env("SUPABASE_PROJECT_ID")
supabase_password = System.get_env("SUPABASE_DB_PASSWORD")  
supabase_host = System.get_env("SUPABASE_POOLER_HOST")

if !supabase_project_id || !supabase_password || !supabase_host do
  IO.puts("Error: Missing required environment variables from ~/.bashrc")
  System.halt(1)
end
```

### Efficient Batch Processing

**Optimal batch size: 500 records**
```elixir
# Proven effective for large imports
batch_size = 500
num_batches = ceil(total_count / batch_size)

# Target only records that need updates
query = "SELECT id FROM uk_lrt WHERE type_code IS NULL ORDER BY id LIMIT $1 OFFSET $2"
```

**Proper accumulator pattern with Enum.reduce:**
```elixir
{total_updated, total_errors} = Enum.reduce(1..num_batches, {0, 0}, fn batch_num, {acc_updated, acc_errors} ->
  # Process batch
  {batch_updated, batch_errors} = process_batch(batch_num)
  
  IO.puts("Batch #{batch_num} completed: #{batch_updated} updated, #{batch_errors} errors")
  {acc_updated + batch_updated, acc_errors + batch_errors}
  |> tap(fn _ -> Process.sleep(500) end)  # Short delay between batches
end)
```

### Data Validation and Safety

**Check source data before updating:**
```elixir
case Postgrex.query(supabase_conn, "SELECT type_code FROM uk_lrt WHERE id = $1", [id]) do
  {:ok, result} when result.num_rows > 0 ->
    [type_code] = List.first(result.rows)
    
    # Only update if source value is not null
    if type_code do
      update_query = "UPDATE uk_lrt SET type_code = $2 WHERE id = $1"
      Postgrex.query(local_conn, update_query, [id, type_code])
    end
end
```

**Progress tracking and feedback:**
```elixir
# Visual progress indicator
if rem(updated_count, 50) == 0, do: IO.write(".")

# Meaningful batch completion messages
IO.puts("Batch #{batch_num}/#{total_batches} completed: #{updated} updated, #{errors} errors")
```

### Connection Management

**Proper connection cleanup:**
```elixir
# Use GenServer.stop() instead of Postgrex.close()
GenServer.stop(supabase_conn)
GenServer.stop(local_conn)
```

**Connection configuration for imports:**
```elixir
import_config = [
  username: "postgres.#{supabase_project_id}",
  password: supabase_password,
  hostname: supabase_host,
  database: "postgres",
  port: 6543,
  ssl: true,
  ssl_opts: [verify: :verify_none],
  # Optimized for sustained operations
  pool_size: 1,
  queue_target: 10000,
  queue_interval: 5000,
  timeout: 30000,
  connect_timeout: 30000
]
```

### Running Long Imports

**Background execution with logging:**
```bash
# Run import in background with output logging
source ~/.bashrc && nohup mix run scripts/import_script.exs > /tmp/import.log 2>&1 &

# Monitor progress
tail -f /tmp/import.log
grep "Batch.*completed" /tmp/import.log | tail -5
```

**Process monitoring:**
```bash
# Check if import is still running
ps aux | grep import_script

# Monitor database changes in real-time
# (use separate terminal/connection)
SELECT COUNT(*) FROM uk_lrt WHERE type_code IS NOT NULL;
```

### Performance Optimization

**Proven settings for 19K+ record imports:**
- **Batch size:** 500 records (sweet spot for performance vs. stability)
- **Delay between batches:** 500ms (prevents overwhelming connections)
- **Connection pooling:** Single connection per database (reduces overhead)
- **Progress reporting:** Every 50 updates within batch, summary per batch

**Verification and cleanup:**
```elixir
# Verify results at completion
IO.puts("\n=== Verification ===")
{:ok, result} = Postgrex.query(local_conn, "SELECT COUNT(*) FROM uk_lrt WHERE type_code IS NOT NULL", [])
final_count = result.rows |> List.first() |> List.first()
total_records = 19089  # or get dynamically
percentage = Float.round(final_count / total_records * 100, 2)
IO.puts("Final: #{final_count} records populated (#{percentage}%)")
```

### Error Handling and Recovery

**Graceful error handling:**
```elixir
case Postgrex.query(conn, query, params) do
  {:ok, result} -> 
    # Process success
  {:error, %Postgrex.Error{} = error} ->
    IO.puts("Database error: #{error.message}")
    # Log and continue or halt based on severity
  {:error, error} ->
    IO.puts("Connection error: #{inspect(error)}")
    # Implement retry logic if needed
end
```

### Testing Import Scripts

**Pre-import validation:**
```elixir
# Test connections before starting
{:ok, test_conn} = Postgrex.start_link(config)
{:ok, _} = Postgrex.query(test_conn, "SELECT 1", [])
IO.puts("✅ Connection test successful")

# Verify data samples exist
{:ok, sample} = Postgrex.query(test_conn, "SELECT COUNT(*) FROM target_table WHERE field IS NULL", [])
count = sample.rows |> List.first() |> List.first()
IO.puts("Records to process: #{count}")
```

## Conclusion

The pooler connection method is generally the most reliable for production use. Always test connections before important operations, and be aware that project pausing can cause temporary connectivity issues.

For large imports, use 500-record batches with proper error handling and progress tracking. Load environment variables from ~/.bashrc for better script reliability.

For troubleshooting, start with the pooler connection method and verify your project status in the Supabase dashboard.