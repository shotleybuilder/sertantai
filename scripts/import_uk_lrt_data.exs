# Data import script - pull from Supabase to local dev in batches
# Run with: source .env && mix run import_data.exs

alias Sertantai.UkLrt

# Create separate connection configs for Supabase (source) and Local (target)
supabase_config = [
  username: "postgres.#{System.get_env("SUPABASE_PROJECT_ID")}",
  password: System.get_env("SUPABASE_DB_PASSWORD"),
  hostname: System.get_env("SUPABASE_POOLER_HOST"),
  database: "postgres",
  port: 6543,
  ssl: true,
  ssl_opts: [verify: :verify_none]
]

local_config = [
  username: "postgres",
  password: "postgres", 
  hostname: "localhost",
  database: "sertantai_dev",
  port: 5432
]

# First, get the total count from Supabase
IO.puts("Connecting to Supabase to get total record count...")

# We'll use direct SQL to pull data in batches
batch_size = 500

# Get total count first from Supabase
{:ok, supabase_conn} = Postgrex.start_link(supabase_config)

query = """
SELECT COUNT(*) as total 
FROM uk_lrt
"""

{:ok, result} = Postgrex.query(supabase_conn, query, [])
total_count = result.rows |> List.first() |> List.first()

IO.puts("Total records to import: #{total_count}")

# Calculate number of batches
num_batches = ceil(total_count / batch_size)
IO.puts("Will process #{num_batches} batches of #{batch_size} records each")

# Connect to local database for inserts
{:ok, local_conn} = Postgrex.start_link(local_config)

# Import data in batches
for batch_num <- 1..num_batches do
  offset = (batch_num - 1) * batch_size
  
  IO.puts("Processing batch #{batch_num}/#{num_batches} (offset: #{offset})")
  
  # Get batch of records from Supabase - only the columns we need
  query = """
  SELECT id, family, family_ii, name, md_description, year, number, 
         live, type_desc, role, tags, created_at
  FROM uk_lrt 
  ORDER BY id 
  LIMIT $1 OFFSET $2
  """
  
  case Postgrex.query(supabase_conn, query, [batch_size, offset]) do
    {:ok, result} ->
      # Insert each record individually to handle data types properly
      inserted_count = 0
      for row <- result.rows do
        [id, family, family_ii, name, md_description, year, number, 
         live, type_desc, role, tags, created_at] = row
        
        insert_query = """
        INSERT INTO uk_lrt (id, family, family_ii, name, md_description, year, number, live, type_desc, role, tags, created_at) 
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        """
        
        case Postgrex.query(local_conn, insert_query, [id, family, family_ii, name, md_description, year, number, live, type_desc, role, tags, created_at]) do
          {:ok, _} ->
            inserted_count = inserted_count + 1
          {:error, error} ->
            IO.puts("Error inserting record #{id}: #{inspect(error)}")
        end
      end
      
      IO.puts("Batch #{batch_num} completed: #{inserted_count}/#{length(result.rows)} records inserted")
      
    {:error, error} ->
      IO.puts("Error fetching batch #{batch_num}: #{inspect(error)}")
  end
  
  # Small delay between batches to be nice to the database
  Process.sleep(100)
end

# Close connections
Postgrex.close(supabase_conn)
Postgrex.close(local_conn)

IO.puts("Data import completed!")

# Final count check
case Ash.read(UkLrt, domain: Sertantai.Domain) do
  {:ok, records} ->
    IO.puts("Final local database count: #{length(records)}")
  {:error, error} ->
    IO.puts("Error counting final records: #{inspect(error)}")
end