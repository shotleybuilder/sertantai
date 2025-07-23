# Debug script to test importing just 10 records
# Run with: mix run scripts/debug_type_code_import.exs

# Get environment variables from ~/.bashrc
supabase_project_id = System.get_env("SUPABASE_PROJECT_ID")
supabase_password = System.get_env("SUPABASE_DB_PASSWORD")  
supabase_host = System.get_env("SUPABASE_POOLER_HOST")

if !supabase_project_id || !supabase_password || !supabase_host do
  IO.puts("Error: Missing required environment variables from ~/.bashrc")
  System.halt(1)
end

# Connection configs
supabase_config = [
  username: "postgres.#{supabase_project_id}",
  password: supabase_password,
  hostname: supabase_host,
  database: "postgres",
  port: 6543,
  ssl: true,
  ssl_opts: [verify: :verify_none],
  pool_size: 1,
  timeout: 30000,
  connect_timeout: 30000
]

local_config = [
  username: "postgres",
  password: "postgres", 
  hostname: "localhost",
  database: "sertantai_dev",
  port: 5432
]

IO.puts("Debug: Testing type_code import for 10 records...")

# Connect to databases
{:ok, supabase_conn} = Postgrex.start_link(supabase_config)
{:ok, local_conn} = Postgrex.start_link(local_config)

# Get 10 records from local database that have no type_code
local_query = "SELECT id FROM uk_lrt WHERE type_code IS NULL LIMIT 10"
{:ok, local_result} = Postgrex.query(local_conn, local_query, [])

IO.puts("Processing #{length(local_result.rows)} records...")

updated_count = 0

for [id] <- local_result.rows do
  # Fetch type_code from Supabase for this ID
  supabase_query = "SELECT type_code FROM uk_lrt WHERE id = $1"
  
  case Postgrex.query(supabase_conn, supabase_query, [id]) do
    {:ok, supabase_result} when supabase_result.num_rows > 0 ->
      # Get the type_code value
      [type_code] = List.first(supabase_result.rows)
      
      IO.puts("  ID #{String.slice(Base.encode16(id, case: :lower), 0, 8)}... type_code from Supabase: #{inspect(type_code)}")
      
      # Only update if type_code is not null in Supabase
      if type_code do
        # Update local record
        update_query = "UPDATE uk_lrt SET type_code = $2 WHERE id = $1"
        
        case Postgrex.query(local_conn, update_query, [id, type_code]) do
          {:ok, update_result} ->
            IO.puts("    ✓ Updated locally (#{update_result.num_rows} row affected)")
            updated_count = updated_count + 1
          {:error, error} ->
            IO.puts("    ✗ Error updating: #{inspect(error)}")
        end
      else
        IO.puts("    - Skipped (type_code is NULL in Supabase)")
      end
      
    {:ok, _} ->
      IO.puts("  ✗ ID #{String.slice(Base.encode16(id, case: :lower), 0, 8)}... not found in Supabase")
      
    {:error, error} ->
      IO.puts("  ✗ Error fetching from Supabase: #{inspect(error)}")
  end
end

IO.puts("\nDebug Summary:")
IO.puts("  Records processed: #{length(local_result.rows)}")
IO.puts("  Records updated: #{updated_count}")

# Verify the updates
{:ok, verify_result} = Postgrex.query(local_conn, "SELECT COUNT(*) FROM uk_lrt WHERE type_code IS NOT NULL", [])
total_with_type_code = verify_result.rows |> List.first() |> List.first()
IO.puts("  Total records with type_code now: #{total_with_type_code}")

# Close connections
GenServer.stop(supabase_conn)
GenServer.stop(local_conn)

IO.puts("\nDebug completed!")