# Script for populating the database with development data
# Run with: mix run priv/repo/seeds.exs

alias Sertantai.Accounts.User
alias Sertantai.Sync.SyncConfiguration
alias Sertantai.Sync.SelectedRecord

# Function to create users
create_users = fn ->
  IO.puts("Creating development users...")
  
  users = [
    %{
      email: "admin@sertantai.com",
      password: "admin123!",
      password_confirmation: "admin123!",
      first_name: "Admin",
      last_name: "User",
      timezone: "UTC"
    },
    %{
      email: "test@sertantai.com", 
      password: "test123!",
      password_confirmation: "test123!",
      first_name: "Test",
      last_name: "User",
      timezone: "Europe/London"
    },
    %{
      email: "demo@sertantai.com",
      password: "demo123!",
      password_confirmation: "demo123!",
      first_name: "Demo",
      last_name: "User",
      timezone: "America/New_York"
    }
  ]
  
  created_users = Enum.map(users, fn user_attrs ->
    case Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts) do
      {:ok, user} -> 
        IO.puts("✓ Created user: #{user.email}")
        user
      {:error, error} -> 
        IO.puts("✗ Failed to create user #{user_attrs.email}: #{inspect(error)}")
        nil
    end
  end)
  
  Enum.filter(created_users, & &1 != nil)
end

# Function to create sample sync configurations
create_sync_configs = fn users ->
  IO.puts("Creating sample sync configurations...")
  
  if length(users) > 0 do
    user = List.first(users)
    
    sync_configs = [
      %{
        name: "Environmental Regulations Export",
        description: "Export of environmental and climate change regulations",
        user_id: user.id,
        sync_type: "full_export",
        schedule: "daily",
        format: "csv",
        filters: %{
          "families" => ["💚 ENVIRONMENTAL PROTECTION", "💚 CLIMATE CHANGE"],
          "status" => ["✔ In force"]
        }
      },
      %{
        name: "Health & Safety Current Records",
        description: "Current health and safety regulations",
        user_id: user.id,
        sync_type: "filtered_export",
        schedule: "weekly",
        format: "json",
        filters: %{
          "families" => ["💙 HEALTH: Public", "💙 OH&S: Occupational / Personal Safety"],
          "status" => ["✔ In force", "⭕ Part Revocation / Repeal"]
        }
      },
      %{
        name: "Agricultural Policy Updates",
        description: "Monthly export of agricultural policy changes",
        user_id: user.id,
        sync_type: "incremental",
        schedule: "monthly",
        format: "csv",
        filters: %{
          "families" => ["💚 AGRICULTURE"],
          "year_from" => 2020
        }
      }
    ]
    
    Enum.each(sync_configs, fn config_attrs ->
      case Ash.create(SyncConfiguration, config_attrs, domain: Sertantai.Sync) do
        {:ok, config} -> 
          IO.puts("✓ Created sync config: #{config.name}")
        {:error, error} -> 
          IO.puts("✗ Failed to create sync config #{config_attrs.name}: #{inspect(error)}")
      end
    end)
  end
end

# Function to create sample selected records
create_selected_records = fn users ->
  IO.puts("Creating sample selected records...")
  
  if length(users) > 0 do
    user = List.first(users)
    
    # Get some UK LRT records to create selections
    case Ash.read(Sertantai.UkLrt |> Ash.Query.limit(50), domain: Sertantai.Domain) do
      {:ok, records} ->
        # Create selected records for the first 20 records
        selected_records = records
        |> Enum.take(20)
        |> Enum.map(fn record ->
          %{
            user_id: user.id,
            record_id: record.id,
            selected_at: DateTime.utc_now()
          }
        end)
        
        Enum.each(selected_records, fn selection_attrs ->
          case Ash.create(SelectedRecord, selection_attrs, domain: Sertantai.Sync) do
            {:ok, _selection} -> :ok
            {:error, error} -> 
              IO.puts("✗ Failed to create selected record: #{inspect(error)}")
          end
        end)
        
        IO.puts("✓ Created #{length(selected_records)} selected records")
        
      {:error, error} ->
        IO.puts("✗ Failed to load UK LRT records: #{inspect(error)}")
    end
  end
end

# Function to show seeding statistics
show_stats = fn ->
  IO.puts("\n=== Development Database Statistics ===")
  
  # User count
  case Ash.read(User, domain: Sertantai.Accounts) do
    {:ok, users} -> 
      IO.puts("Users: #{length(users)}")
      Enum.each(users, fn user ->
        IO.puts("  - #{user.email} (#{user.first_name} #{user.last_name})")
      end)
    {:error, _} -> IO.puts("Users: Error loading")
  end
  
  # UK LRT records count
  case Ash.read(Sertantai.UkLrt |> Ash.Query.limit(1), domain: Sertantai.Domain) do
    {:ok, records} -> 
      case Ash.count(Sertantai.UkLrt, domain: Sertantai.Domain) do
        {:ok, count} -> IO.puts("UK LRT Records: #{count}")
        {:error, _} -> IO.puts("UK LRT Records: #{length(records)} (sample)")
      end
    {:error, _} -> IO.puts("UK LRT Records: Error loading")
  end
  
  # Sync configurations count
  case Ash.read(SyncConfiguration, domain: Sertantai.Sync) do
    {:ok, configs} -> 
      IO.puts("Sync Configurations: #{length(configs)}")
      Enum.each(configs, fn config ->
        IO.puts("  - #{config.name}")
      end)
    {:error, _} -> IO.puts("Sync Configurations: Error loading")
  end
  
  # Selected records count
  case Ash.read(SelectedRecord, domain: Sertantai.Sync) do
    {:ok, selections} -> IO.puts("Selected Records: #{length(selections)}")
    {:error, _} -> IO.puts("Selected Records: Error loading")
  end
end

# Main seeding logic
IO.puts("🌱 Starting database seeding...")

# Check if we're in development
if Mix.env() == :dev do
  users = create_users.()
  create_sync_configs.(users)
  create_selected_records.(users)
  show_stats.()
  
  IO.puts("\n✅ Database seeding completed!")
  IO.puts("\nYou can now log in with:")
  IO.puts("  Email: admin@sertantai.com")
  IO.puts("  Password: admin123!")
  IO.puts("\nOr:")
  IO.puts("  Email: test@sertantai.com")
  IO.puts("  Password: test123!")
else
  IO.puts("❌ Seeding is only available in development environment")
end
