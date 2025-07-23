#!/usr/bin/env elixir

Mix.install([
  :postgrex,
  :jason
])

defmodule DataMigration do
  @moduledoc """
  Script to migrate data from Supabase to local PostgreSQL.
  Extracts 1000 diverse UK LRT records for development.
  """
  
  def run do
    IO.puts("Starting data migration from Supabase to local PostgreSQL...")
    
    # Connect to Supabase
    {:ok, supabase_conn} = connect_to_supabase()
    
    # Connect to local PostgreSQL
    {:ok, local_conn} = connect_to_local()
    
    # Extract data from Supabase
    IO.puts("Extracting data from Supabase...")
    records = extract_uk_lrt_data(supabase_conn)
    
    # Insert into local database
    IO.puts("Inserting #{length(records)} records into local database...")
    insert_records(local_conn, records)
    
    # Cleanup
    GenServer.stop(supabase_conn)
    GenServer.stop(local_conn)
    
    IO.puts("Data migration completed successfully!")
  end
  
  defp connect_to_supabase do
    Postgrex.start_link(
      hostname: System.get_env("SUPABASE_POOLER_HOST"),
      port: 6543,
      username: "postgres.#{System.get_env("SUPABASE_PROJECT_ID")}",
      password: System.get_env("SUPABASE_DB_PASSWORD"),
      database: "postgres",
      parameters: [pgbouncer: "true"],
      ssl: true,
      ssl_opts: [verify: :verify_none]
    )
  end
  
  defp connect_to_local do
    Postgrex.start_link(
      hostname: "localhost",
      port: 5432,
      username: "postgres",
      password: "postgres",
      database: "sertantai_dev"
    )
  end
  
  defp extract_uk_lrt_data(conn) do
    query = """
    SELECT 
      id, family, family_ii, name, md_description, year, number, 
      live, type_desc, role, tags, created_at
    FROM uk_lrt 
    WHERE family IS NOT NULL 
    ORDER BY 
      family, 
      CASE 
        WHEN live = '✔ In force' THEN 1
        WHEN live = '⭕ Part Revocation / Repeal' THEN 2
        WHEN live = '❌ Revoked / Repealed / Abolished' THEN 3
        ELSE 4
      END,
      created_at DESC
    LIMIT 1000
    """
    
    case Postgrex.query(conn, query, []) do
      {:ok, %{rows: rows, columns: columns}} ->
        rows
        |> Enum.map(fn row ->
          columns
          |> Enum.zip(row)
          |> Enum.into(%{})
        end)
        |> Enum.map(&process_record/1)
        
      {:error, error} ->
        IO.puts("Error extracting data: #{inspect(error)}")
        []
    end
  end
  
  defp process_record(record) do
    %{
      id: record["id"],
      family: record["family"],
      family_ii: record["family_ii"],
      name: record["name"],
      md_description: record["md_description"],
      year: record["year"],
      number: record["number"],
      live: record["live"],
      type_desc: record["type_desc"],
      role: process_array_field(record["role"]),
      tags: process_array_field(record["tags"]),
      created_at: record["created_at"] || DateTime.utc_now()
    }
  end
  
  defp process_array_field(nil), do: []
  defp process_array_field(field) when is_list(field), do: field
  defp process_array_field(field) when is_binary(field) do
    case Jason.decode(field) do
      {:ok, list} when is_list(list) -> list
      _ -> [field]
    end
  end
  defp process_array_field(_), do: []
  
  defp insert_records(conn, records) do
    # First, ensure the table exists
    create_table_query = """
    CREATE TABLE IF NOT EXISTS uk_lrt (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      family VARCHAR(255),
      family_ii VARCHAR(255),
      name VARCHAR(255),
      md_description TEXT,
      year INTEGER,
      number VARCHAR(255),
      live VARCHAR(255),
      type_desc VARCHAR(255),
      role TEXT[], -- Array of strings
      tags TEXT[], -- Array of strings
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
    """
    
    case Postgrex.query(conn, create_table_query, []) do
      {:ok, _} -> IO.puts("Table created or already exists")
      {:error, error} -> IO.puts("Error creating table: #{inspect(error)}")
    end
    
    # Insert records in batches
    records
    |> Enum.chunk_every(100)
    |> Enum.with_index()
    |> Enum.each(fn {batch, batch_index} ->
      IO.puts("Processing batch #{batch_index + 1}...")
      insert_batch(conn, batch)
    end)
  end
  
  defp insert_batch(conn, batch) do
    insert_query = """
    INSERT INTO uk_lrt (
      id, family, family_ii, name, md_description, year, number, 
      live, type_desc, role, tags, created_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
    ON CONFLICT (id) DO UPDATE SET
      family = EXCLUDED.family,
      family_ii = EXCLUDED.family_ii,
      name = EXCLUDED.name,
      md_description = EXCLUDED.md_description,
      year = EXCLUDED.year,
      number = EXCLUDED.number,
      live = EXCLUDED.live,
      type_desc = EXCLUDED.type_desc,
      role = EXCLUDED.role,
      tags = EXCLUDED.tags,
      created_at = EXCLUDED.created_at
    """
    
    Enum.each(batch, fn record ->
      params = [
        record.id,
        record.family,
        record.family_ii,
        record.name,
        record.md_description,
        record.year,
        record.number,
        record.live,
        record.type_desc,
        record.role,
        record.tags,
        record.created_at
      ]
      
      case Postgrex.query(conn, insert_query, params) do
        {:ok, _} -> :ok
        {:error, error} -> 
          IO.puts("Error inserting record #{record.id}: #{inspect(error)}")
      end
    end)
  end
  
  def show_stats do
    {:ok, conn} = connect_to_local()
    
    stats_query = """
    SELECT 
      COUNT(*) as total_records,
      COUNT(DISTINCT family) as distinct_families,
      COUNT(DISTINCT family_ii) as distinct_family_ii,
      COUNT(DISTINCT live) as distinct_statuses,
      MIN(year) as earliest_year,
      MAX(year) as latest_year
    FROM uk_lrt
    """
    
    case Postgrex.query(conn, stats_query, []) do
      {:ok, %{rows: [row]}} ->
        [total, families, family_ii, statuses, min_year, max_year] = row
        
        IO.puts("\n=== Local Database Statistics ===")
        IO.puts("Total records: #{total}")
        IO.puts("Distinct families: #{families}")
        IO.puts("Distinct family_ii: #{family_ii}")
        IO.puts("Distinct statuses: #{statuses}")
        IO.puts("Year range: #{min_year} - #{max_year}")
        
      {:error, error} ->
        IO.puts("Error getting stats: #{inspect(error)}")
    end
    
    GenServer.stop(conn)
  end
end

# Run the migration
case System.argv() do
  ["stats"] -> DataMigration.show_stats()
  _ -> DataMigration.run()
end