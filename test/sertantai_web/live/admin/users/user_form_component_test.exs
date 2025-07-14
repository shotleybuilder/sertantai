defmodule SertantaiWeb.Admin.Users.UserFormComponentTest do
  @moduledoc """
  Test user form component using safe component testing patterns.
  
  Uses direct component rendering to avoid router authentication issues.
  See README.md in admin/ directory for testing approach explanation.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  
  alias SertantaiWeb.Admin.Users.UserFormComponent
  alias Phoenix.LiveView.Socket
  
  describe "user form component rendering" do
    test "renders create user form for admin" do
      admin = user_fixture(%{role: :admin})
      
      form = AshPhoenix.Form.for_create(Sertantai.Accounts.User, :register_with_password, forms: [auto?: false])
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          user: nil,
          form: form,
          action: :create,
          __changed__: %{}
        }
      }
      
      html = render_component(UserFormComponent, socket.assigns, %{id: "test-form"})
      
      # Should show create form with all fields
      assert html =~ "Create New User"
      assert html =~ "Email Address"
      assert html =~ "First Name"
      assert html =~ "Last Name"
      assert html =~ "Role"
      assert html =~ "Password"
      assert html =~ "Confirm Password"
      assert html =~ "Timezone"
      assert html =~ "Create User"
    end
    
    test "renders edit user form for admin" do
      admin = user_fixture(%{role: :admin})
      user_to_edit = user_fixture(%{role: :member, email: "edit@example.com", first_name: "Edit", last_name: "User"})
      
      form = AshPhoenix.Form.for_update(user_to_edit, :update, forms: [auto?: false])
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          user: user_to_edit,
          form: form,
          action: :edit,
          __changed__: %{}
        }
      }
      
      html = render_component(UserFormComponent, socket.assigns, %{id: "test-form"})
      
      # Should show edit form with pre-filled values
      assert html =~ "Edit User"
      assert html =~ "edit@example.com"
      assert html =~ "Edit"
      assert html =~ "User"
      assert html =~ "Role"
      refute html =~ "Password"  # No password fields in edit mode
      refute html =~ "Confirm Password"
      assert html =~ "Update User"
    end
    
    test "support user cannot see role field" do
      support = user_fixture(%{role: :support})
      user_to_edit = user_fixture(%{role: :member, email: "edit@example.com"})
      
      form = AshPhoenix.Form.for_update(user_to_edit, :update, forms: [auto?: false])
      
      socket = %Socket{
        assigns: %{
          current_user: support,
          user: user_to_edit,
          form: form,
          action: :edit,
          __changed__: %{}
        }
      }
      
      html = render_component(UserFormComponent, socket.assigns, %{id: "test-form"})
      
      # Support users should not see role field
      assert html =~ "Edit User"
      refute html =~ "Role"
      assert html =~ "First Name"
      assert html =~ "Last Name"
      assert html =~ "Timezone"
    end
    
    test "form shows validation errors" do
      admin = user_fixture(%{role: :admin})
      
      form = AshPhoenix.Form.for_create(Sertantai.Accounts.User, :register_with_password, forms: [auto?: false])
      # Simulate validation errors by validating empty params
      form = AshPhoenix.Form.validate(form, %{})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          user: nil,
          form: form,
          action: :create,
          __changed__: %{}
        }
      }
      
      html = render_component(UserFormComponent, socket.assigns, %{id: "test-form"})
      
      # Should show validation error
      assert html =~ "can't be blank"
    end
    
    test "timezone options are available" do
      admin = user_fixture(%{role: :admin})
      
      form = AshPhoenix.Form.for_create(Sertantai.Accounts.User, :register_with_password, forms: [auto?: false])
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          user: nil,
          form: form,
          action: :create,
          __changed__: %{}
        }
      }
      
      html = render_component(UserFormComponent, socket.assigns, %{id: "test-form"})
      
      # Should show timezone options
      assert html =~ "UTC"
      assert html =~ "Eastern Time"
      assert html =~ "Pacific Time"
      assert html =~ "London"
      assert html =~ "Tokyo"
    end
    
    test "role options are available for admin" do
      admin = user_fixture(%{role: :admin})
      
      form = AshPhoenix.Form.for_create(Sertantai.Accounts.User, :register_with_password, forms: [auto?: false])
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          user: nil,
          form: form,
          action: :create,
          __changed__: %{}
        }
      }
      
      html = render_component(UserFormComponent, socket.assigns, %{id: "test-form"})
      
      # Should show role options
      assert html =~ "Guest"
      assert html =~ "Member"
      assert html =~ "Professional"
      assert html =~ "Support"
      assert html =~ "Admin"
    end
    
    test "form has proper modal styling" do
      admin = user_fixture(%{role: :admin})
      
      form = AshPhoenix.Form.for_create(Sertantai.Accounts.User, :register_with_password, forms: [auto?: false])
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          user: nil,
          form: form,
          action: :create,
          __changed__: %{}
        }
      }
      
      html = render_component(UserFormComponent, socket.assigns, %{id: "test-form"})
      
      # Should have modal styling classes
      assert html =~ "fixed inset-0 z-50"
      assert html =~ "bg-gray-500 bg-opacity-75"
      assert html =~ "rounded-lg"
      assert html =~ "shadow-xl"
    end
    
    test "form has cancel and submit buttons" do
      admin = user_fixture(%{role: :admin})
      
      form = AshPhoenix.Form.for_create(Sertantai.Accounts.User, :register_with_password, forms: [auto?: false])
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          user: nil,
          form: form,
          action: :create,
          __changed__: %{}
        }
      }
      
      html = render_component(UserFormComponent, socket.assigns, %{id: "test-form"})
      
      # Should have action buttons
      assert html =~ "Cancel"
      assert html =~ "Create User"
      assert html =~ "type=\"submit\""
      assert html =~ "type=\"button\""
    end
  end
end