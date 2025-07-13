# Script to update existing users with different roles for testing
# Run with: mix run scripts/update_user_roles.exs

alias Sertantai.Accounts.User

IO.puts("🔧 Updating existing users with different roles for testing...")

# Get all users without authorization (bypass policies)
case Ash.read(User, authorize?: false, domain: Sertantai.Accounts) do
  {:ok, users} ->
    IO.puts("Found #{length(users)} existing users")
    
    # Define role assignments
    role_assignments = [
      {"admin@sertantai.com", :admin, "Admin User"},
      {"test@sertantai.com", :professional, "Professional User"}, 
      {"demo@sertantai.com", :support, "Support User"}
    ]
    
    # Update each user with their assigned role
    Enum.each(role_assignments, fn {email, role, description} ->
      case Enum.find(users, &(&1.email == email)) do
        nil ->
          IO.puts("❌ User #{email} not found")
          
        user ->
          case Ash.update(user, %{role: role}, authorize?: false, domain: Sertantai.Accounts) do
            {:ok, updated_user} ->
              IO.puts("✅ Updated #{email} → #{role} (#{description})")
              
            {:error, error} ->
              IO.puts("❌ Failed to update #{email}: #{inspect(error)}")
          end
      end
    end)
    
    # Show final user roles
    IO.puts("\n📋 Final user roles:")
    case Ash.read(User, authorize?: false, domain: Sertantai.Accounts) do
      {:ok, updated_users} ->
        Enum.each(updated_users, fn user ->
          IO.puts("  #{user.email} → #{user.role}")
        end)
        
      {:error, error} ->
        IO.puts("❌ Failed to read updated users: #{inspect(error)}")
    end
    
  {:error, error} ->
    IO.puts("❌ Failed to read users: #{inspect(error)}")
end

IO.puts("\n✅ Role assignment complete!")
IO.puts("\nYou can now test admin access with:")
IO.puts("  admin@sertantai.com (admin role)")
IO.puts("  demo@sertantai.com (support role)")
IO.puts("\nAnd test restricted access with:")
IO.puts("  test@sertantai.com (professional role - should be blocked)")