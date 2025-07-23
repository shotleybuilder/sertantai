# Test script to verify Supabase connection and data match
# Run with: mix run scripts/test_type_code_connection.exs

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

IO.puts("Testing connections...")

# Connect to databases
{:ok, supabase_conn} = Postgrex.start_link(supabase_config)
{:ok, local_conn} = Postgrex.start_link(local_config)

# Get a sample ID from local database that has no type_code
local_query = "SELECT id FROM uk_lrt WHERE type_code IS NULL LIMIT 5"
{:ok, local_result} = Postgrex.query(local_conn, local_query, [])

IO.puts("Sample IDs from local DB with NULL type_code:")
for [id] <- local_result.rows do
  IO.puts("  #{Base.encode16(id, case: :lower)}")
end

# Test if those IDs exist in Supabase  
IO.puts("\nChecking if these IDs exist in Supabase with type_code:")
for [id] <- Enum.take(local_result.rows, 3) do
  supabase_query = "SELECT id, type_code FROM uk_lrt WHERE id = $1"
  
  case Postgrex.query(supabase_conn, supabase_query, [id]) do
    {:ok, supabase_result} when supabase_result.num_rows > 0 ->
      [found_id, type_code] = List.first(supabase_result.rows)
      IO.puts("  ✓ ID #{Base.encode16(id, case: :lower)} found in Supabase with type_code: #{inspect(type_code)}")
    {:ok, _} ->
      IO.puts("  ✗ ID #{Base.encode16(id, case: :lower)} NOT found in Supabase")
    {:error, error} ->
      IO.puts("  ✗ Error querying Supabase for ID #{Base.encode16(id, case: :lower)}: #{inspect(error)}")
  end
end

# Get counts from both databases
{:ok, local_count_result} = Postgrex.query(local_conn, "SELECT COUNT(*) FROM uk_lrt", [])
local_total = local_count_result.rows |> List.first() |> List.first()

{:ok, supabase_count_result} = Postgrex.query(supabase_conn, "SELECT COUNT(*) FROM uk_lrt", [])
supabase_total = supabase_count_result.rows |> List.first() |> List.first()

IO.puts("\nRecord counts:")
IO.puts("  Local DB: #{local_total} records")
IO.puts("  Supabase: #{supabase_total} records")

# Close connections
GenServer.stop(supabase_conn)
GenServer.stop(local_conn)

IO.puts("\nConnection test completed!")