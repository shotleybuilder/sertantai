# Test role-based authentication for all 5 user roles
require Ash.Query

# Test each user role authentication
users = [
  {:admin, "admin@sertantai.com"},
  {:support, "support@sertantai.com"}, 
  {:professional, "professional@sertantai.com"},
  {:member, "member@sertantai.com"},
  {:guest, "guest@sertantai.com"}
]

IO.puts "Testing role-based authentication synchronously..."

Enum.each(users, fn {role, email} ->
  IO.puts "\n=== Testing #{role} user: #{email} ==="
  
  case Sertantai.Accounts.User |> Ash.Query.filter(email == ^email) |> Ash.read_one() do
    {:ok, user} when not is_nil(user) ->
      IO.puts "✅ User found: #{user.email}, Role: #{user.role}"
      
      # Test role assignment
      if user.role == role do
        IO.puts "✅ Role correctly assigned: #{role}"
      else
        IO.puts "❌ Role mismatch: expected #{role}, got #{user.role}"
      end
      
    {:ok, nil} ->
      IO.puts "❌ User not found: #{email}"
    {:error, error} ->
      IO.puts "❌ Error finding user #{email}: #{inspect(error)}"
  end
end)

IO.puts "\n=== Authentication test complete ==="