# Priority 1 Core Metadata Import Script
# Updates existing uk_lrt records with core metadata from Supabase production
# Run with: source .env && mix run scripts/import_priority1_metadata.exs

alias Sertantai.UkLrt

# Remaining Priority 1 columns to import (excluding md_description which is 85% complete)
columns_to_import = [
  "title_en",
  "created_at",
  "md_date",
  "md_date_year",
  "md_date_month",
  "latest_change_date",
  "latest_change_date_year",
  "latest_change_date_month"
]

# Create separate connection configs for Supabase (source) and Local (target)
# Use working pooler connection configuration
supabase_config = [
  username: "postgres.#{System.get_env("SUPABASE_PROJECT_ID")}",
  password: System.get_env("SUPABASE_DB_PASSWORD"),
  hostname: System.get_env("SUPABASE_POOLER_HOST"),
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

IO.puts("Starting Priority 1 Core Metadata Import...")
IO.puts("Columns to import: #{Enum.join(columns_to_import, ", ")}")

# Connect to databases
{:ok, supabase_conn} = Postgrex.start_link(supabase_config)
{:ok, local_conn} = Postgrex.start_link(local_config)

# Get count of records missing title_en
query = "SELECT COUNT(*) as total FROM uk_lrt WHERE title_en IS NULL"
{:ok, result} = Postgrex.query(local_conn, query, [])
total_count = result.rows |> List.first() |> List.first()

IO.puts("Records missing title_en to update: #{total_count}")

# Process in batches - reduced size for connection stability
batch_size = 100
num_batches = ceil(total_count / batch_size)
IO.puts("Will process #{num_batches} batches of #{batch_size} records each")

# Track statistics
total_updated = 0
total_errors = 0

# Build column list for SELECT and UPDATE
column_list = Enum.join(columns_to_import, ", ")
update_set_clause = columns_to_import 
  |> Enum.with_index(2) 
  |> Enum.map(fn {col, idx} -> "#{col} = $#{idx}" end)
  |> Enum.join(", ")

for batch_num <- 1..num_batches do
  offset = (batch_num - 1) * batch_size
  
  IO.puts("\nProcessing batch #{batch_num}/#{num_batches} (offset: #{offset})")
  
  # Get batch of IDs from local database where title_en is missing
  local_query = "SELECT id FROM uk_lrt WHERE title_en IS NULL ORDER BY id LIMIT $1 OFFSET $2"
  
  case Postgrex.query(local_conn, local_query, [batch_size, offset]) do
    {:ok, local_result} ->
      batch_updated = 0
      batch_errors = 0
      
      # Process each record
      for [id] <- local_result.rows do
        # Fetch metadata from Supabase for this ID
        supabase_query = """
        SELECT #{column_list}
        FROM uk_lrt 
        WHERE id = $1
        """
        
        case Postgrex.query(supabase_conn, supabase_query, [id]) do
          {:ok, supabase_result} when supabase_result.num_rows > 0 ->
            # Get the metadata values
            metadata_values = List.first(supabase_result.rows)
            
            # Update local record
            update_query = """
            UPDATE uk_lrt 
            SET #{update_set_clause}
            WHERE id = $1
            """
            
            case Postgrex.query(local_conn, update_query, [id | metadata_values]) do
              {:ok, _} ->
                batch_updated = batch_updated + 1
              {:error, error} ->
                IO.puts("  Error updating record #{inspect(id)}: #{inspect(error)}")
                batch_errors = batch_errors + 1
            end
            
          {:ok, _} ->
            # No matching record in Supabase
            IO.puts("  Warning: No matching record in Supabase for ID #{inspect(id)}")
            
          {:error, error} ->
            IO.puts("  Error fetching from Supabase for ID #{inspect(id)}: #{inspect(error)}")
            batch_errors = batch_errors + 1
        end
      end
      
      total_updated = total_updated + batch_updated
      total_errors = total_errors + batch_errors
      
      IO.puts("  Batch #{batch_num} completed: #{batch_updated} updated, #{batch_errors} errors")
      
    {:error, error} ->
      IO.puts("Error fetching local batch #{batch_num}: #{inspect(error)}")
  end
  
  # Longer delay between batches to avoid overwhelming Supabase
  Process.sleep(1000)
end

# Close connections
Postgrex.close(supabase_conn)
Postgrex.close(local_conn)

IO.puts("\n=== Import Summary ===")
IO.puts("Records with missing title_en updated: #{total_updated}")
IO.puts("Total errors: #{total_errors}")
IO.puts("Success rate: #{if total_count > 0, do: Float.round(total_updated / total_count * 100, 2), else: 0}%")

# Verify the update by checking populated columns
IO.puts("\n=== Verification ===")
{:ok, verify_conn} = Postgrex.start_link(local_config)

for column <- columns_to_import do
  query = "SELECT COUNT(*) FROM uk_lrt WHERE #{column} IS NOT NULL"
  {:ok, result} = Postgrex.query(verify_conn, query, [])
  count = result.rows |> List.first() |> List.first()
  percentage = Float.round(count / total_count * 100, 2)
  IO.puts("#{column}: #{count} records populated (#{percentage}%)")
end

Postgrex.close(verify_conn)

IO.puts("\nPriority 1 Core Metadata import completed!")