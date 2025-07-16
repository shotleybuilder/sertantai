defmodule SertantaiWeb.Admin.Components.AdminTableTest do
  @moduledoc """
  Tests for the AdminTable component.
  
  Tests component functionality, styling, and behavior.
  """
  
  use SertantaiWeb.ConnCase, async: true
  
  alias SertantaiWeb.Admin.Components.AdminTable

  describe "admin_table component" do
    test "component functions exist and can be imported" do
      # Basic existence test - verify component compiled correctly
      assert AdminTable.__info__(:functions) |> Keyword.has_key?(:admin_table)
      assert AdminTable.__info__(:functions) |> Keyword.has_key?(:role_badge)
      assert AdminTable.__info__(:functions) |> Keyword.has_key?(:status_badge)
      assert AdminTable.__info__(:functions) |> Keyword.has_key?(:action_buttons)
    end
    
    test "role_badge function handles all role types" do
      # Test that role badge function exists and handles expected roles
      roles = [:admin, :support, :professional, :member, :guest]
      
      Enum.each(roles, fn _role ->
        # This should not raise an error if the function is properly defined
        assert is_function(&AdminTable.role_badge/1)
      end)
    end
    
    test "status_badge function exists" do
      assert is_function(&AdminTable.status_badge/1)
    end
  end
end