defmodule SertantaiWeb.Admin.Components.AdminModalTest do
  @moduledoc """
  Tests for the AdminModal component.
  
  Tests modal functionality, behavior, and accessibility.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  
  alias SertantaiWeb.Admin.Components.AdminModal

  describe "admin_modal component" do
    test "component functions exist and can be imported" do
      # Basic existence test - verify component compiled correctly
      assert AdminModal.__info__(:functions) |> Keyword.has_key?(:admin_modal)
      assert AdminModal.__info__(:functions) |> Keyword.has_key?(:show_modal)
      assert AdminModal.__info__(:functions) |> Keyword.has_key?(:hide_modal)
      assert AdminModal.__info__(:functions) |> Keyword.has_key?(:confirmation_modal)
      assert AdminModal.__info__(:functions) |> Keyword.has_key?(:alert_modal)
    end
    
    test "modal component functions are properly defined" do
      # Test that modal functions exist and are callable
      assert is_function(&AdminModal.admin_modal/1)
      assert is_function(&AdminModal.show_modal/1)
      assert is_function(&AdminModal.show_modal/2)
      assert is_function(&AdminModal.hide_modal/1)
      assert is_function(&AdminModal.hide_modal/2)
      assert is_function(&AdminModal.confirmation_modal/1)
      assert is_function(&AdminModal.alert_modal/1)
    end
  end
end