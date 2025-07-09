defmodule Sertantai.Accounts.RegistrationTest do
  use Sertantai.DataCase, async: false
  
  alias Sertantai.Accounts.User
  require Ash.Query
  
  test "user registration works with valid data" do
    # Test user registration with new credentials
    result = User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "newuser@sertantai.com",
      password: "newpassword123!",
      password_confirmation: "newpassword123!",
      first_name: "New",
      last_name: "User",
      timezone: "America/New_York"
    })
    |> Ash.create(domain: Sertantai.Accounts)
    
    case result do
      {:ok, user} ->
        IO.puts("✅ Registration successful!")
        IO.puts("User: #{user.email}")
        assert to_string(user.email) == "newuser@sertantai.com"
        assert user.first_name == "New"
        assert user.last_name == "User"
        assert user.timezone == "America/New_York"
        assert user.hashed_password != nil
        
      {:error, error} ->
        IO.puts("❌ Registration failed!")
        IO.puts("Error: #{inspect(error)}")
        flunk("Registration should have succeeded")
    end
  end
  
  test "user registration fails with mismatched passwords" do
    result = User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "baduser@sertantai.com",
      password: "password123!",
      password_confirmation: "differentpassword123!",
      first_name: "Bad",
      last_name: "User"
    })
    |> Ash.create(domain: Sertantai.Accounts)
    
    case result do
      {:ok, _user} ->
        flunk("Registration should have failed with mismatched passwords")
        
      {:error, error} ->
        IO.puts("✅ Registration correctly failed with mismatched passwords")
        IO.puts("Error: #{inspect(error)}")
        assert true
    end
  end
  
  test "user registration fails with duplicate email" do
    # First create a user
    {:ok, _user1} = User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "duplicate@sertantai.com",
      password: "password123!",
      password_confirmation: "password123!",
      first_name: "First",
      last_name: "User"
    })
    |> Ash.create(domain: Sertantai.Accounts)
    
    # Try to create another user with the same email
    result = User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "duplicate@sertantai.com",
      password: "password123!",
      password_confirmation: "password123!",
      first_name: "Second",
      last_name: "User"
    })
    |> Ash.create(domain: Sertantai.Accounts)
    
    case result do
      {:ok, _user} ->
        flunk("Registration should have failed with duplicate email")
        
      {:error, error} ->
        IO.puts("✅ Registration correctly failed with duplicate email")
        IO.puts("Error: #{inspect(error)}")
        assert true
    end
  end
  
  test "newly registered user can sign in" do
    # Register a new user
    {:ok, user} = User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: "signin@sertantai.com",
      password: "signin123!",
      password_confirmation: "signin123!",
      first_name: "Sign",
      last_name: "In"
    })
    |> Ash.create(domain: Sertantai.Accounts)
    
    IO.puts("✅ User registered: #{user.email}")
    
    # Now try to sign in with the new user
    result = User
    |> Ash.Query.for_read(:sign_in_with_password, %{
      email: "signin@sertantai.com",
      password: "signin123!"
    })
    |> Ash.read_one(domain: Sertantai.Accounts)
    
    case result do
      {:ok, authenticated_user} ->
        IO.puts("✅ Sign in successful!")
        assert to_string(authenticated_user.email) == "signin@sertantai.com"
        
      {:error, error} ->
        IO.puts("❌ Sign in failed!")
        IO.puts("Error: #{inspect(error)}")
        flunk("Sign in should have succeeded")
    end
  end
  
  test "registration form data structure" do
    # Test that we can create the right data structure for the form
    form_data = %{
      "email" => "form@sertantai.com",
      "password" => "form123!",
      "password_confirmation" => "form123!",
      "first_name" => "Form",
      "last_name" => "Test",
      "timezone" => "UTC"
    }
    
    # Convert string keys to atoms (as forms typically do)
    attrs = %{
      email: form_data["email"],
      password: form_data["password"],
      password_confirmation: form_data["password_confirmation"],
      first_name: form_data["first_name"],
      last_name: form_data["last_name"],
      timezone: form_data["timezone"]
    }
    
    result = User
    |> Ash.Changeset.for_create(:register_with_password, attrs)
    |> Ash.create(domain: Sertantai.Accounts)
    
    case result do
      {:ok, user} ->
        IO.puts("✅ Form data registration successful!")
        assert to_string(user.email) == "form@sertantai.com"
        
      {:error, error} ->
        IO.puts("❌ Form data registration failed!")
        IO.puts("Error: #{inspect(error)}")
        flunk("Form data registration should have succeeded")
    end
  end
end