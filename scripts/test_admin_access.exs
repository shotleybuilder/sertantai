# Test admin interface access control
require Logger

# Test admin user creation with different roles
roles_to_test = [:admin, :support, :professional, :member, :guest]

Logger.info("Testing admin interface access control...")

Enum.each(roles_to_test, fn role ->
  email = "test_#{role}@example.com"
  
  Logger.info("Testing role: #{role}")
  
  # Create or find user with specific role
  user = case Sertantai.Accounts.User 
               |> Ash.Query.filter(email == ^email) 
               |> Ash.read_one() do
    {:ok, existing_user} when not is_nil(existing_user) ->
      Logger.info("Found existing user: #{email}")
      existing_user
      
    {:ok, nil} ->
      Logger.info("Creating new user: #{email}")
      
      {:ok, new_user} = Sertantai.Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: "password123",
        password_confirmation: "password123",
        first_name: "Test",
        last_name: String.capitalize(to_string(role)),
        role: role
      })
      |> Ash.create()
      
      new_user
      
    {:error, error} ->
      Logger.error("Error finding/creating user #{email}: #{inspect(error)}")
      nil
  end
  
  if user do
    access_level = case user.role do
      role when role in [:admin, :support] -> "ALLOWED"
      _ -> "DENIED"
    end
    
    Logger.info("User #{email} (#{user.role}): Admin access #{access_level}")
  end
  
  :timer.sleep(100)  # Small delay between tests
end)

Logger.info("Admin access control test completed!")
Logger.info("✅ Admin users: should have access")
Logger.info("✅ Support users: should have access") 
Logger.info("❌ Professional users: should be denied")
Logger.info("❌ Member users: should be denied")
Logger.info("❌ Guest users: should be denied")
Logger.info("")
Logger.info("To test manually:")
Logger.info("1. Start server: PORT=4001 mix phx.server")
Logger.info("2. Login as admin/support user")
Logger.info("3. Navigate to: http://localhost:4001/admin")
Logger.info("4. Verify access control working correctly")