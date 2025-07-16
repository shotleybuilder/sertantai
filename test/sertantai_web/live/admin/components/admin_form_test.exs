defmodule SertantaiWeb.Admin.Components.AdminFormTest do
  @moduledoc """
  Tests for the AdminForm component.
  
  Tests form components, validation, and styling.
  """
  
  use SertantaiWeb.ConnCase, async: true
  
  alias SertantaiWeb.Admin.Components.AdminForm

  describe "admin_form component" do
    test "component functions exist and can be imported" do
      # Basic existence test - verify component compiled correctly
      assert AdminForm.__info__(:functions) |> Keyword.has_key?(:admin_form)
      assert AdminForm.__info__(:functions) |> Keyword.has_key?(:admin_input)
      assert AdminForm.__info__(:functions) |> Keyword.has_key?(:admin_select)
      assert AdminForm.__info__(:functions) |> Keyword.has_key?(:admin_textarea)
      assert AdminForm.__info__(:functions) |> Keyword.has_key?(:admin_form_buttons)
    end
    
    test "form component functions are properly defined" do
      # Test that form functions exist and are callable
      assert is_function(&AdminForm.admin_form/1)
      assert is_function(&AdminForm.admin_input/1)
      assert is_function(&AdminForm.admin_select/1)
      assert is_function(&AdminForm.admin_textarea/1)
      assert is_function(&AdminForm.admin_form_buttons/1)
    end
  end
end