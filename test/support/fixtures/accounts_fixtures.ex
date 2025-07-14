defmodule Sertantai.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating user accounts for testing.
  
  Optimized for memory efficiency and resource reuse.
  """

  alias Sertantai.Accounts.User

  # Process-based cache for reusing users within a test run
  def user_fixture(attrs \\ %{}) do
    role = Map.get(attrs, :role, :member)
    
    # Try to reuse existing user if only role is specified
    if map_size(attrs) <= 1 do
      case get_cached_user(role) do
        nil -> 
          user = create_new_user(attrs)
          cache_user(role, user)
          user
        user -> 
          user
      end
    else
      # Create unique user for custom attributes
      create_new_user(attrs)
    end
  end
  
  defp create_new_user(attrs) do
    default_attrs = %{
      email: "test#{System.unique_integer()}@example.com",
      password: "test123!test123!",
      password_confirmation: "test123!test123!",
      first_name: "Test",
      last_name: "User",
      timezone: "UTC"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    {:ok, user} = 
      Ash.create(User, merged_attrs, action: :register_with_password, domain: Sertantai.Accounts)

    user
  end
  
  defp get_cached_user(role) do
    Process.get({:test_user_cache, role})
  end
  
  defp cache_user(role, user) do
    Process.put({:test_user_cache, role}, user)
  end

  def admin_user_fixture(attrs \\ %{}) do
    default_attrs = %{
      email: "admin#{System.unique_integer()}@example.com",
      password: "admin123!admin123!",
      password_confirmation: "admin123!admin123!",
      first_name: "Admin",
      last_name: "User",
      timezone: "UTC"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    {:ok, user} = 
      Ash.create(User, merged_attrs, action: :register_with_password, domain: Sertantai.Accounts)

    user
  end

  def valid_user_attributes(attrs \\ %{}) do
    default_attrs = %{
      email: "test#{System.unique_integer()}@example.com",
      password: "test123!test123!",
      password_confirmation: "test123!test123!",
      first_name: "Test",
      last_name: "User",
      timezone: "UTC"
    }

    Map.merge(default_attrs, attrs)
  end
end