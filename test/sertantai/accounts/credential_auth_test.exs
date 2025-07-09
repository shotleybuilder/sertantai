defmodule Sertantai.Accounts.CredentialAuthTest do
  use Sertantai.DataCase, async: false
  
  alias Sertantai.Accounts.User
  require Ash.Query
  
  setup do
    # Create the test user with exact credentials from seeds
    user_attrs = %{
      email: "test@sertantai.com",
      password: "test123!",
      password_confirmation: "test123!",
      first_name: "Test",
      last_name: "User",
      timezone: "Europe/London"
    }
    
    {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
    %{user: user}
  end
  
  test "user was created successfully", %{user: user} do
    assert to_string(user.email) == "test@sertantai.com"
    assert user.first_name == "Test"
    assert user.last_name == "User"
    assert user.timezone == "Europe/London"
  end
  
  test "user can be found by email", %{user: _user} do
    query = User |> Ash.Query.filter(email: "test@sertantai.com")
    found_user = Ash.read_one!(query, domain: Sertantai.Accounts)
    assert to_string(found_user.email) == "test@sertantai.com"
  end
  
  test "password authentication works with correct credentials", %{user: _user} do
    # Try to authenticate with the user using the correct read action
    result = User
    |> Ash.Query.for_read(:sign_in_with_password, %{
      email: "test@sertantai.com",
      password: "test123!"
    })
    |> Ash.read_one(domain: Sertantai.Accounts)
    
    case result do
      {:ok, authenticated_user} ->
        assert to_string(authenticated_user.email) == "test@sertantai.com"
        IO.puts("✅ Authentication successful!")
        
      {:error, error} ->
        IO.puts("❌ Authentication failed: #{inspect(error)}")
        flunk("Authentication should have succeeded")
    end
  end
  
  test "password authentication fails with wrong password", %{user: _user} do
    result = User
    |> Ash.Query.for_read(:sign_in_with_password, %{
      email: "test@sertantai.com",
      password: "wrongpassword"
    })
    |> Ash.read_one(domain: Sertantai.Accounts)
    
    case result do
      {:ok, _user} ->
        flunk("Authentication should have failed with wrong password")
        
      {:error, error} ->
        IO.puts("✅ Authentication correctly failed with wrong password: #{inspect(error)}")
        assert true
    end
  end
  
  test "password authentication fails with non-existent user" do
    result = User
    |> Ash.Query.for_read(:sign_in_with_password, %{
      email: "nonexistent@sertantai.com",
      password: "test123!"
    })
    |> Ash.read_one(domain: Sertantai.Accounts)
    
    case result do
      {:ok, _user} ->
        flunk("Authentication should have failed with non-existent user")
        
      {:error, error} ->
        IO.puts("✅ Authentication correctly failed with non-existent user: #{inspect(error)}")
        assert true
    end
  end
  
  test "check if user exists in database after seeding" do
    # This will help us debug if the user actually exists
    case Ash.read(User, domain: Sertantai.Accounts) do
      {:ok, users} ->
        IO.puts("Found #{length(users)} users in database:")
        Enum.each(users, fn user ->
          IO.puts("  - #{user.email} (#{user.first_name} #{user.last_name})")
        end)
        
        test_user = Enum.find(users, &(to_string(&1.email) == "test@sertantai.com"))
        if test_user do
          IO.puts("✅ test@sertantai.com user found in database")
        else
          IO.puts("❌ test@sertantai.com user NOT found in database")
        end
        
      {:error, error} ->
        IO.puts("❌ Error reading users: #{inspect(error)}")
    end
  end
end