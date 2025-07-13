# Debug authentication issues
# Run with: mix run scripts/test_auth_debug.exs

require Ash.Query

# Test with minimal user lookup first using correct Ash API
IO.puts("=== TESTING MINIMAL USER LOOKUP ===")
user = Sertantai.Accounts.User
  |> Ash.Query.filter(email: "test@sertantai.com")
  |> Ash.read_one!(authorize?: false, domain: Sertantai.Accounts)
IO.inspect(user.email, label: "User email")
IO.inspect(user.role, label: "User role") 
IO.inspect(user.hashed_password != nil, label: "Has password hash")

# Test password verification
IO.puts("\n=== TESTING PASSWORD VERIFICATION ===")
password_valid = Bcrypt.verify_pass("test123!", user.hashed_password)
IO.inspect(password_valid, label: "Password verification")

# Test database state
IO.puts("\n=== TESTING DATABASE STATE ===")
all_users = Ash.read!(Sertantai.Accounts.User, authorize?: false, domain: Sertantai.Accounts)
IO.inspect(length(all_users), label: "Total users")
Enum.each(all_users, fn u -> 
  IO.puts("  #{u.email} -> #{u.role}")
end)