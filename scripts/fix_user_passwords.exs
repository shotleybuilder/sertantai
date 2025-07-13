# Script to fix user passwords by generating proper hashes
# Run with: mix run scripts/fix_user_passwords.exs

alias Sertantai.Accounts.User

IO.puts("🔧 Fixing user passwords with proper hashes...")

# Define user credentials with their expected passwords
user_credentials = [
  {"test@sertantai.com", "test123!"},
  {"member@sertantai.com", "member123!"},
  {"guest@sertantai.com", "guest123!"}
]

# Update each user with properly hashed password
Enum.each(user_credentials, fn {email, password} ->
  # Generate proper hash using Bcrypt
  hashed_password = Bcrypt.hash_pwd_salt(password)
  
  # Update user directly in database
  case Ecto.Adapters.SQL.query(
    Sertantai.Repo,
    "UPDATE users SET hashed_password = $1 WHERE email = $2",
    [hashed_password, email]
  ) do
    {:ok, %{num_rows: 1}} ->
      IO.puts("✅ Updated password for #{email}")
    {:ok, %{num_rows: 0}} ->
      IO.puts("❌ User #{email} not found")
    {:error, error} ->
      IO.puts("❌ Failed to update #{email}: #{inspect(error)}")
  end
end)

IO.puts("\n✅ Password fix complete!")
IO.puts("\nYou can now login with:")
IO.puts("  test@sertantai.com / test123!")
IO.puts("  member@sertantai.com / member123!")
IO.puts("  guest@sertantai.com / guest123!")