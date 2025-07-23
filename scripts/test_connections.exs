# Test database connections
# Run with: source .env && mix run scripts/test_connections.exs

IO.puts("=== Environment Variables ===")
IO.puts("SUPABASE_PROJECT_ID: #{System.get_env("SUPABASE_PROJECT_ID")}")
IO.puts("SUPABASE_POOLER_HOST: #{System.get_env("SUPABASE_POOLER_HOST")}")
IO.puts("SUPABASE_HOST: #{System.get_env("SUPABASE_HOST")}")
IO.puts("SUPABASE_DB_PASSWORD: #{if System.get_env("SUPABASE_DB_PASSWORD"), do: "[SET]", else: "[NOT SET]"}")

# Test local connection first
IO.puts("\n=== Testing Local Database Connection ===")
local_config = [
  username: "postgres",
  password: "postgres", 
  hostname: "localhost",
  database: "sertantai_dev",
  port: 5432
]

case Postgrex.start_link(local_config) do
  {:ok, local_conn} ->
    IO.puts("✅ Local database connection successful")
    
    case Postgrex.query(local_conn, "SELECT COUNT(*) FROM uk_lrt", []) do
      {:ok, result} ->
        count = result.rows |> List.first() |> List.first()
        IO.puts("✅ Local database has #{count} records")
      {:error, error} ->
        IO.puts("❌ Error querying local database: #{inspect(error)}")
    end
    
    GenServer.stop(local_conn)
  {:error, error} ->
    IO.puts("❌ Local database connection failed: #{inspect(error)}")
end

# Test multiple Supabase connection methods
IO.puts("\n=== Testing Supabase Database Connection ===")

# Method 1: Direct connection using project.supabase.co format
IO.puts("\n--- Method 1: Direct Connection ---")
direct_config = [
  username: "postgres.#{System.get_env("SUPABASE_PROJECT_ID")}",
  password: System.get_env("SUPABASE_PASSWORD"),
  hostname: "#{System.get_env("SUPABASE_PROJECT_ID")}.supabase.co",
  database: "postgres",
  port: 5432,
  ssl: true,
  ssl_opts: [verify: :verify_none]
]

IO.puts("Attempting direct connection:")
IO.puts("  Username: #{direct_config[:username]}")
IO.puts("  Hostname: #{direct_config[:hostname]}")
IO.puts("  Port: #{direct_config[:port]}")

case Postgrex.start_link(direct_config) do
  {:ok, direct_conn} ->
    IO.puts("✅ Direct connection successful")
    case Postgrex.query(direct_conn, "SELECT COUNT(*) FROM uk_lrt", []) do
      {:ok, result} ->
        count = result.rows |> List.first() |> List.first()
        IO.puts("✅ Direct connection: #{count} records found")
      {:error, error} ->
        IO.puts("❌ Error querying via direct connection: #{inspect(error)}")
    end
    GenServer.stop(direct_conn)
  {:error, error} ->
    IO.puts("❌ Direct connection failed: #{inspect(error)}")
end

# Method 2: Pooler connection
IO.puts("\n--- Method 2: Pooler Connection ---")
pooler_config = [
  username: "postgres.#{System.get_env("SUPABASE_PROJECT_ID")}",
  password: System.get_env("SUPABASE_DB_PASSWORD"),
  hostname: System.get_env("SUPABASE_POOLER_HOST"),
  database: "postgres",
  port: 6543,
  ssl: true,
  ssl_opts: [verify: :verify_none]
]

IO.puts("Attempting pooler connection:")
IO.puts("  Username: #{pooler_config[:username]}")
IO.puts("  Hostname: #{pooler_config[:hostname]}")
IO.puts("  Port: #{pooler_config[:port]}")

case Postgrex.start_link(pooler_config) do
  {:ok, pooler_conn} ->
    IO.puts("✅ Pooler connection successful")
    case Postgrex.query(pooler_conn, "SELECT COUNT(*) FROM uk_lrt", []) do
      {:ok, result} ->
        count = result.rows |> List.first() |> List.first()
        IO.puts("✅ Pooler connection: #{count} records found")
      {:error, error} ->
        IO.puts("❌ Error querying via pooler connection: #{inspect(error)}")
    end
    GenServer.stop(pooler_conn)
  {:error, error} ->
    IO.puts("❌ Pooler connection failed: #{inspect(error)}")
end

# Method 3: DATABASE_URL parsing method
IO.puts("\n--- Method 3: DATABASE_URL Parsing ---")
database_url = System.get_env("DATABASE_URL")
if database_url do
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
  
  IO.puts("Attempting DATABASE_URL connection:")
  IO.puts("  Username: #{parsed_config[:username]}")
  IO.puts("  Hostname: #{parsed_config[:hostname]}")
  IO.puts("  Port: #{parsed_config[:port]}")
  IO.puts("  Database: #{parsed_config[:database]}")
  
  case Postgrex.start_link(parsed_config) do
    {:ok, parsed_conn} ->
      IO.puts("✅ DATABASE_URL connection successful")
      case Postgrex.query(parsed_conn, "SELECT COUNT(*) FROM uk_lrt", []) do
        {:ok, result} ->
          count = result.rows |> List.first() |> List.first()
          IO.puts("✅ DATABASE_URL connection: #{count} records found")
        {:error, error} ->
          IO.puts("❌ Error querying via DATABASE_URL connection: #{inspect(error)}")
      end
      GenServer.stop(parsed_conn)
    {:error, error} ->
      IO.puts("❌ DATABASE_URL connection failed: #{inspect(error)}")
  end
else
  IO.puts("❌ DATABASE_URL not set")
end

IO.puts("\n=== Connection Test Complete ===")