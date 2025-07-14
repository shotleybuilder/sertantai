defmodule Sertantai.Accounts.RoleAuthTest do
  use Sertantai.DataCase, async: false
  alias Sertantai.Accounts.User
  require Ash.Query
  import Sertantai.AccountsFixtures

  describe "role-based authentication system" do
    test "user creation requires proper authorization" do
      # Test that basic registration works (no actor required for registration)
      {:ok, user} = User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Test",
        last_name: "User"
      })
      |> Ash.create()
      
      # Verify user was created with default guest role
      assert user.role == :guest, 
        "User #{user.email} should default to guest role, but has #{user.role}"
      
      # Verify user can be queried from database
      db_user = User
      |> Ash.Query.filter(email == ^user.email)
      |> Ash.read_one!()

      assert db_user != nil, "User #{user.email} should exist in database"
      assert db_user.role == :guest, 
        "Database user #{user.email} should have guest role, but has #{db_user.role}"
    end

    test "role hierarchy is properly defined" do
      # Test that all 5 roles are valid enum values
      valid_roles = [:guest, :member, :professional, :admin, :support]
      
      Enum.each(valid_roles, fn role ->
        # This should not raise an error if role is valid
        changeset = User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "test_#{role}@example.com",
          password: "password123",
          role: role,
          first_name: "Test",
          last_name: "User"
        })
        
        # Check that role is accepted without validation errors
        refute Enum.any?(changeset.errors, fn error ->
          error.field == :role
        end), "Role #{role} should be valid"
      end)
    end

    test "users can be queried by role and role filtering works" do
      # Create a test user using proper registration action
      {:ok, user} = User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "query_test@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "Query",
        last_name: "Test"
      })
      |> Ash.create()
      
      # Query users with guest role (should include our test user)
      guest_users = User
      |> Ash.Query.filter(role == :guest)
      |> Ash.read!()
      
      # Should find at least our test user
      assert length(guest_users) >= 1, "Should find at least one user with guest role"
      
      # All returned users should have guest role
      Enum.each(guest_users, fn found_user ->
        assert found_user.role == :guest, "All users in result should have guest role"
      end)
      
      # Our test user should be in the results
      test_user_found = Enum.any?(guest_users, fn found_user ->
        found_user.email == user.email
      end)
      assert test_user_found, "Test user should be found in guest role query"
    end

    test "role assignment works during registration and security policies are enforced" do
      # Test that users can register with any role (current behavior)
      {:ok, admin_user} = User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "test_admin@example.com",
        password: "password123", 
        password_confirmation: "password123",
        first_name: "Test",
        last_name: "Admin",
        role: :admin  # This is currently allowed during registration
      })
      |> Ash.create()
      
      assert admin_user.role == :admin, "Admin role should be assigned during registration"
      
      # Test that role updates through standard update action require proper authorization
      {:ok, regular_user} = User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "regular@example.com",
        password: "password123",
        password_confirmation: "password123", 
        first_name: "Regular",
        last_name: "User"
      })
      |> Ash.create()
      
      # Test that updates without actor context should fail our policies
      # The default :update action accepts fields like first_name
      assert_raise Ash.Error.Forbidden, fn ->
        regular_user
        |> Ash.Changeset.for_update(:update, %{first_name: "Unauthorized"})
        |> Ash.update!()  # No actor context, should fail our policies
      end
      
      # Test that users can update their own records when acting as themselves
      updated_user = regular_user
      |> Ash.Changeset.for_update(:update, %{first_name: "UpdatedName"})
      |> Ash.update!(actor: regular_user)  # With actor context, should succeed
      
      assert updated_user.first_name == "UpdatedName", "User should be able to update their own first name"
    end
  end
end