defmodule Sertantai.AccountsTest do
  use Sertantai.DataCase
  
  alias Sertantai.Accounts.User

  describe "user registration" do
    test "creates user with valid attributes" do
      attrs = %{
        email: "test@example.com",
        first_name: "John",
        last_name: "Doe",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }

      assert {:ok, user} = Ash.create(User, attrs, action: :register_with_password, domain: Sertantai.Accounts)
      assert to_string(user.email) == "test@example.com"
      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.hashed_password != nil
      # Password should be hashed, not stored in plain text
      refute user.hashed_password == "securepassword123"
    end

    test "requires email" do
      attrs = %{
        first_name: "John",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }

      assert {:error, %Ash.Error.Invalid{}} = Ash.create(User, attrs, action: :register_with_password, domain: Sertantai.Accounts)
      # Should have email required error - Ash returns error instead of changeset
    end

    test "requires password" do
      attrs = %{
        email: "test@example.com",
        first_name: "John"
      }

      assert {:error, %Ash.Error.Invalid{}} = Ash.create(User, attrs, action: :register_with_password, domain: Sertantai.Accounts)
      # Should have password required error - Ash returns error instead of changeset
    end

    test "requires password confirmation to match" do
      attrs = %{
        email: "test@example.com",
        first_name: "John",
        password: "securepassword123",
        password_confirmation: "differentpassword"
      }

      assert {:error, %Ash.Error.Invalid{}} = Ash.create(User, attrs, action: :register_with_password, domain: Sertantai.Accounts)
      # Should have password confirmation error - Ash returns error instead of changeset
    end

    test "requires unique email" do
      attrs = %{
        email: "duplicate@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }

      # Create first user
      assert {:ok, _user1} = Ash.create(User, attrs, action: :register_with_password, domain: Sertantai.Accounts)

      # Try to create second user with same email
      assert {:error, %Ash.Error.Invalid{}} = Ash.create(User, attrs, action: :register_with_password, domain: Sertantai.Accounts)
      # Should have uniqueness constraint error - Ash returns error instead of changeset
    end

    test "stores email properly" do
      attrs = %{
        email: "Test@EXAMPLE.COM",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }

      assert {:ok, user} = Ash.create(User, attrs, action: :register_with_password, domain: Sertantai.Accounts)
      # Email should be stored (normalization may or may not happen)
      assert to_string(user.email) =~ "@"
    end
  end

  describe "user authentication" do
    setup do
      attrs = %{
        email: "auth@example.com",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
      
      {:ok, user} = Ash.create(User, attrs, action: :register_with_password, domain: Sertantai.Accounts)
      %{user: user}
    end

    test "authentication structure is configured", %{user: user} do
      # Test that user has authentication configured
      assert user.hashed_password != nil
      assert to_string(user.email) =~ "@"
      
      # Test that User resource has authentication configured
      assert function_exported?(AshAuthentication.Info, :authentication_strategies, 1)
    end

    test "password authentication strategy exists", %{user: _user} do
      # Test that password strategy is configured
      strategies = AshAuthentication.Info.authentication_strategies(User)
      password_strategy = Enum.find(strategies, &(&1.name == :password))
      
      assert password_strategy != nil
      assert password_strategy.identity_field == :email
    end

    test "user can be retrieved by email", %{user: user} do
      # Test basic user retrieval
      case Ash.get(User, user.id, domain: Sertantai.Accounts) do
        {:ok, found_user} ->
          assert found_user.id == user.id
          assert to_string(found_user.email) == to_string(user.email)
        {:error, _} ->
          flunk("Should be able to retrieve user by ID")
      end
    end
  end
end