# Classification & Type Columns Import Script
# Updates existing uk_lrt records with classification and type data from Supabase production
# Run with: source .env && mix run scripts/import_classification_type_columns.exs

alias Sertantai.UkLrt

# Classification & Type columns to import (based on schema documentation)
columns_to_import = [
  "type_code",
  "type_class", 
  "2ndary_class",
  "live_description",
  "acronym",
  "old_style_number"
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

IO.puts("Starting Classification & Type Columns Import...")
IO.puts("Columns to import: #{Enum.join(columns_to_import, ", ")}")

# Connect to databases
{:ok, supabase_conn} = Postgrex.start_link(supabase_config)
{:ok, local_conn} = Postgrex.start_link(local_config)

# Get count of records missing type_code (our main target column)
query = "SELECT COUNT(*) as total FROM uk_lrt WHERE type_code IS NULL"
{:ok, result} = Postgrex.query(local_conn, query, [])
total_count = result.rows |> List.first() |> List.first()

IO.puts("Records missing type_code to update: #{total_count}")
IO.puts("Note: This should be all #{total_count} records as type_code is currently unpopulated")

# Process in batches - reduced size for connection stability
batch_size = 100
num_batches = ceil(total_count / batch_size)
IO.puts("Will process #{num_batches} batches of #{batch_size} records each")

# Track statistics
total_updated = 0
total_errors = 0

# Build column list for SELECT and UPDATE
# Handle the problematic column name "2ndary_class" by quoting it
quoted_columns = Enum.map(columns_to_import, fn col ->
  if col == "2ndary_class", do: "\"#{col}\"", else: col
end)
column_list = Enum.join(quoted_columns, ", ")

update_set_clause = columns_to_import 
  |> Enum.with_index(2) 
  |> Enum.map(fn {col, idx} -> 
    if col == "2ndary_class" do
      "\"#{col}\" = $#{idx}"
    else
      "#{col} = $#{idx}"
    end
  end)
  |> Enum.join(", ")

for batch_num <- 1..num_batches do
  offset = (batch_num - 1) * batch_size
  
  IO.puts("\nProcessing batch #{batch_num}/#{num_batches} (offset: #{offset})")
  
  # Get batch of IDs from local database where type_code is missing (should be all records)
  local_query = "SELECT id FROM uk_lrt WHERE type_code IS NULL ORDER BY id LIMIT $1 OFFSET $2"
  
  case Postgrex.query(local_conn, local_query, [batch_size, offset]) do
    {:ok, local_result} ->
      batch_updated = 0
      batch_errors = 0
      
      # Process each record
      for [id] <- local_result.rows do
        # Fetch classification data from Supabase for this ID
        supabase_query = """
        SELECT #{column_list}
        FROM uk_lrt 
        WHERE id = $1
        """
        
        case Postgrex.query(supabase_conn, supabase_query, [id]) do
          {:ok, supabase_result} when supabase_result.num_rows > 0 ->
            # Get the classification values
            classification_values = List.first(supabase_result.rows)
            
            # Update local record
            update_query = """
            UPDATE uk_lrt 
            SET #{update_set_clause}
            WHERE id = $1
            """
            
            case Postgrex.query(local_conn, update_query, [id | classification_values]) do
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
IO.puts("Records with missing type_code updated: #{total_updated}")
IO.puts("Total errors: #{total_errors}")
IO.puts("Success rate: #{if total_count > 0, do: Float.round(total_updated / total_count * 100, 2), else: 0}%")

# Verify the update by checking populated columns
IO.puts("\n=== Verification ===")
{:ok, verify_conn} = Postgrex.start_link(local_config)

for column <- columns_to_import do
  # Handle the problematic column name for verification
  column_name = if column == "2ndary_class", do: "\"#{column}\"", else: column
  query = "SELECT COUNT(*) FROM uk_lrt WHERE #{column_name} IS NOT NULL"
  
  case Postgrex.query(verify_conn, query, []) do
    {:ok, result} ->
      count = result.rows |> List.first() |> List.first()
      percentage = if total_count > 0, do: Float.round(count / total_count * 100, 2), else: 0
      IO.puts("#{column}: #{count} records populated (#{percentage}%)")
    {:error, error} ->
      IO.puts("#{column}: Error checking - #{inspect(error)}")
  end
end

Postgrex.close(verify_conn)

IO.puts("\nClassification & Type Columns import completed!")
IO.puts("\nNext Steps:")
IO.puts("1. Update UkLrt Ash resource to include new attributes")
IO.puts("2. Run Phase 1 tests to verify table column functionality")
IO.puts("3. Continue with records view table reorganization")