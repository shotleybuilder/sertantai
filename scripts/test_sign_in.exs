# Test sign_in_with_password action directly
# Run with: mix run scripts/test_sign_in.exs

require Ash.Query

# Test authentication with correct credentials
IO.puts("=== TESTING SIGN IN WITH PASSWORD ===")
result = Sertantai.Accounts.User
|> Ash.Query.for_read(:sign_in_with_password, %{
  email: "test@sertantai.com",
  password: "test123!"
})
|> Ash.read_one(domain: Sertantai.Accounts)

case result do
  {:ok, authenticated_user} ->
    IO.puts("✅ Authentication successful!")
    IO.inspect(authenticated_user.email, label: "Authenticated user")
    IO.inspect(authenticated_user.role, label: "User role")
    
  {:error, error} ->
    IO.puts("❌ Authentication failed:")
    IO.inspect(error, label: "Error details")
end

# Test with wrong password
IO.puts("\n=== TESTING WITH WRONG PASSWORD ===")
result2 = Sertantai.Accounts.User
|> Ash.Query.for_read(:sign_in_with_password, %{
  email: "test@sertantai.com", 
  password: "wrongpassword"
})
|> Ash.read_one(domain: Sertantai.Accounts)

case result2 do
  {:ok, _user} ->
    IO.puts("❌ ERROR: Authentication should have failed with wrong password")
    
  {:error, error} ->
    IO.puts("✅ Authentication correctly failed with wrong password")
    IO.inspect(error, label: "Expected error")
end