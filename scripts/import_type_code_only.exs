# Type Code Only Import Script
# Updates existing uk_lrt records with type_code data from Supabase production
# Run with: mix run scripts/import_type_code_only.exs
# Environment variables are loaded from ~/.bashrc

alias Sertantai.UkLrt

# Only import type_code column for focused, fast import
columns_to_import = [
  "type_code"
]

# Get environment variables from ~/.bashrc
supabase_project_id = System.get_env("SUPABASE_PROJECT_ID")
supabase_password = System.get_env("SUPABASE_DB_PASSWORD")  
supabase_host = System.get_env("SUPABASE_POOLER_HOST")

if !supabase_project_id || !supabase_password || !supabase_host do
  IO.puts("Error: Missing required environment variables. Please ensure ~/.bashrc contains:")
  IO.puts("  SUPABASE_PROJECT_ID")
  IO.puts("  SUPABASE_DB_PASSWORD") 
  IO.puts("  SUPABASE_POOLER_HOST")
  System.halt(1)
end

# Create separate connection configs for Supabase (source) and Local (target)
# Use working pooler connection configuration
supabase_config = [
  username: "postgres.#{supabase_project_id}",
  password: supabase_password,
  hostname: supabase_host,
  database: "postgres",
  port: 6543,
  ssl: true,
  ssl_opts: [verify: :verify_none],
  pool_size: 1,
  queue_target: 10000,
  queue_interval: 5000,
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

IO.puts("Starting Type Code Only Import...")
IO.puts("Column to import: type_code")

# Connect to databases
{:ok, supabase_conn} = Postgrex.start_link(supabase_config)
{:ok, local_conn} = Postgrex.start_link(local_config)

# Get count of records missing type_code
query = "SELECT COUNT(*) as total FROM uk_lrt WHERE type_code IS NULL"
{:ok, result} = Postgrex.query(local_conn, query, [])
total_count = result.rows |> List.first() |> List.first()

IO.puts("Records missing type_code to update: #{total_count}")

# Increase batch size for faster processing
batch_size = 500
num_batches = ceil(total_count / batch_size)
IO.puts("Will process #{num_batches} batches of #{batch_size} records each")

# Track statistics using Enum.reduce for proper accumulation
{total_updated, total_errors} = Enum.reduce(1..num_batches, {0, 0}, fn batch_num, {acc_updated, acc_errors} ->
  offset = (batch_num - 1) * batch_size
  
  IO.puts("\nProcessing batch #{batch_num}/#{num_batches} (offset: #{offset})")
  
  # Get batch of IDs from local database where type_code is missing
  local_query = "SELECT id FROM uk_lrt WHERE type_code IS NULL ORDER BY id LIMIT $1 OFFSET $2"
  
  case Postgrex.query(local_conn, local_query, [batch_size, offset]) do
    {:ok, local_result} ->
      # Process each record and count updates/errors
      {batch_updated, batch_errors} = Enum.reduce(local_result.rows, {0, 0}, fn [id], {upd, err} ->
        # Fetch type_code from Supabase for this ID
        supabase_query = "SELECT type_code FROM uk_lrt WHERE id = $1"
        
        case Postgrex.query(supabase_conn, supabase_query, [id]) do
          {:ok, supabase_result} when supabase_result.num_rows > 0 ->
            # Get the type_code value
            [type_code] = List.first(supabase_result.rows)
            
            # Only update if type_code is not null in Supabase
            if type_code do
              # Update local record
              update_query = "UPDATE uk_lrt SET type_code = $2 WHERE id = $1"
              
              case Postgrex.query(local_conn, update_query, [id, type_code]) do
                {:ok, _} ->
                  if rem(upd + 1, 50) == 0, do: IO.write(".")
                  {upd + 1, err}
                {:error, error} ->
                  IO.puts("  Error updating record #{inspect(id)}: #{inspect(error)}")
                  {upd, err + 1}
              end
            else
              {upd, err}
            end
            
          {:ok, _} ->
            IO.puts("  Warning: No matching record in Supabase for ID #{inspect(id)}")
            {upd, err}
            
          {:error, error} ->
            IO.puts("  Error fetching from Supabase for ID #{inspect(id)}: #{inspect(error)}")
            {upd, err + 1}
        end
      end)
      
      IO.puts("\n  Batch #{batch_num} completed: #{batch_updated} updated, #{batch_errors} errors")
      {acc_updated + batch_updated, acc_errors + batch_errors}
      
    {:error, error} ->
      IO.puts("Error fetching local batch #{batch_num}: #{inspect(error)}")
      {acc_updated, acc_errors + 1}
  end
  |> tap(fn _ -> Process.sleep(500) end)  # Shorter delay between batches
end)

# Close connections
GenServer.stop(supabase_conn)
GenServer.stop(local_conn)

IO.puts("\n=== Import Summary ===")
IO.puts("Records with missing type_code updated: #{total_updated}")
IO.puts("Total errors: #{total_errors}")
IO.puts("Success rate: #{if total_count > 0, do: Float.round(total_updated / total_count * 100, 2), else: 0}%")

# Verify the update
IO.puts("\n=== Verification ===")
{:ok, verify_conn} = Postgrex.start_link(local_config)

query = "SELECT COUNT(*) FROM uk_lrt WHERE type_code IS NOT NULL"
{:ok, result} = Postgrex.query(verify_conn, query, [])
count = result.rows |> List.first() |> List.first()
total_records = 19089
percentage = Float.round(count / total_records * 100, 2)
IO.puts("type_code: #{count} records populated (#{percentage}%)")

Postgrex.close(verify_conn)

IO.puts("\nType Code import completed!")
IO.puts("The /records table should now show more type codes (uksi, ssi, etc.) instead of full type descriptions.")