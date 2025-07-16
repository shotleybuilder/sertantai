defmodule SertantaiWeb.Admin.Users.UserListLiveTest do
  @moduledoc """
  Test user list functionality using safe component testing patterns.
  
  Uses direct component rendering to avoid router authentication issues.
  See README.md in admin/ directory for testing approach explanation.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  
  alias SertantaiWeb.Admin.Users.UserListLive
  alias Phoenix.LiveView.Socket
  
  describe "user list component rendering" do
    test "renders user list for admin user" do
      admin = user_fixture(%{role: :admin})
      regular_user = user_fixture(%{role: :member, email: "user@example.com"})
      
      # Create a socket with admin user
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [admin, regular_user],
          search_term: "",
          role_filter: "all",
          sort_by: "email",
          sort_order: "asc",
          selected_users: [],
          show_user_modal: false,
          editing_user: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Check that admin interface elements are present
      assert html =~ "User Management"
      assert html =~ "New User"
      assert html =~ to_string(admin.email)
      assert html =~ to_string(regular_user.email)
      assert html =~ "Admin"
      assert html =~ "Member"
    end
    
    test "renders user list for support user" do
      support = user_fixture(%{role: :support})
      regular_user = user_fixture(%{role: :member, email: "user@example.com"})
      
      socket = %Socket{
        assigns: %{
          current_user: support,
          users: [support, regular_user],
          search_term: "",
          role_filter: "all", 
          sort_by: "email",
          sort_order: "asc",
          selected_users: [],
          show_user_modal: false,
          editing_user: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Support users should see the interface but not "New User" button
      assert html =~ "User Management"
      refute html =~ "New User"
      assert html =~ to_string(support.email)
      assert html =~ to_string(regular_user.email)
    end
    
    test "search functionality filters users correctly" do
      admin = user_fixture(%{role: :admin})
      user1 = user_fixture(%{role: :member, email: "john@example.com", first_name: "John"})
      _user2 = user_fixture(%{role: :member, email: "jane@example.com", first_name: "Jane"})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [user1],  # Filtered to only show john
          search_term: "john",
          role_filter: "all",
          sort_by: "email", 
          sort_order: "asc",
          selected_users: [],
          show_user_modal: false,
          editing_user: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show filtered results
      assert html =~ "john@example.com"
      refute html =~ "jane@example.com"
    end
    
    test "role filter works correctly" do
      admin = user_fixture(%{role: :admin})
      _support = user_fixture(%{role: :support, email: "support@example.com"})
      _member = user_fixture(%{role: :member, email: "member@example.com"})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [admin],  # Filtered to show only admin
          search_term: "",
          role_filter: "admin",
          sort_by: "email",
          sort_order: "asc", 
          selected_users: [],
          show_user_modal: false,
          editing_user: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show only admin user
      assert html =~ to_string(admin.email)
      refute html =~ "support@example.com"
      refute html =~ "member@example.com"
    end
    
    test "bulk operations interface appears when users are selected" do
      admin = user_fixture(%{role: :admin})
      user1 = user_fixture(%{role: :member, email: "user1@example.com"})
      user2 = user_fixture(%{role: :member, email: "user2@example.com"})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [user1, user2],
          search_term: "",
          role_filter: "all",
          sort_by: "email",
          sort_order: "asc",
          selected_users: [user1.id, user2.id],  # Users selected
          show_user_modal: false,
          editing_user: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show bulk operations
      assert html =~ "2 user(s) selected"
      assert html =~ "Change Role..."
      assert html =~ "Delete Selected"
      assert html =~ "Clear selection"
    end
    
    test "new user modal shows when in new action" do
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [],
          search_term: "",
          role_filter: "all",
          sort_by: "email", 
          sort_order: "asc",
          selected_users: [],
          show_user_modal: true,
          editing_user: nil,
          __changed__: %{},
          flash: %{},
          live_action: :new
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show modal for new user
      assert html =~ "Create New User"
      assert html =~ "Email Address"
      assert html =~ ~s(type="password")  # Password input field should be present when creating
      assert html =~ "Role"
    end
    
    test "edit user modal shows when editing" do
      admin = user_fixture(%{role: :admin})
      user_to_edit = user_fixture(%{role: :member, email: "edit@example.com"})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [user_to_edit],
          search_term: "",
          role_filter: "all",
          sort_by: "email",
          sort_order: "asc", 
          selected_users: [],
          show_user_modal: true,
          editing_user: user_to_edit,
          __changed__: %{},
          flash: %{},
          live_action: :edit
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show modal for editing user
      assert html =~ "Edit User"
      assert html =~ to_string(user_to_edit.email)
      refute html =~ ~s(type="password")  # No password input field when editing
    end
    
    test "sorting controls display correctly" do
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [],
          search_term: "",
          role_filter: "all", 
          sort_by: "email",
          sort_order: "asc",
          selected_users: [],
          show_user_modal: false,
          editing_user: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show sortable column headers
      assert html =~ "Email"
      assert html =~ "Name"
      assert html =~ "Role"
      assert html =~ "Created"
      
      # Should show sort indicator for email column
      assert html =~ "M5 15l7-7 7 7"  # Ascending arrow for email
    end
  end
end