defmodule Sertantai.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating user accounts for testing.
  """

  alias Sertantai.Accounts.User

  def user_fixture(attrs \\ %{}) do
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