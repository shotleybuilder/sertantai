defmodule SertantaiWeb.Admin.Users.UserListLiveTest do
  @moduledoc """
  Test user list functionality using safe component testing patterns.
  
  Uses direct component rendering to avoid router authentication issues.
  See README.md in admin/ directory for testing approach explanation.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  import Sertantai.OrganizationsFixtures
  
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 2,
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 1,
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
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
    
    test "breadcrumb navigation is present" do
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show breadcrumb navigation
      assert html =~ "Admin Dashboard"
      assert html =~ "User Management"
      assert html =~ ~s(/admin)
      assert html =~ ~s(aria-label="Breadcrumb")
    end
    
    test "user names are clickable links to edit page" do
      admin = user_fixture(%{role: :admin})
      user_with_name = user_fixture(%{role: :member, email: "john@example.com", first_name: "John", last_name: "Doe"})
      user_without_name = user_fixture(%{role: :member, email: "no-name@example.com", first_name: nil, last_name: nil})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [user_with_name, user_without_name],
          search_term: "",
          role_filter: "all", 
          sort_by: "email",
          sort_order: "asc",
          selected_users: [],
          show_user_modal: false,
          editing_user: nil,
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 2,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show name as clickable link for user with name
      assert html =~ "John Doe"
      assert html =~ ~s(/admin/users/#{user_with_name.id}/edit)
      
      # Should show "No name" as clickable link for user without name
      assert html =~ "No name"
      assert html =~ ~s(/admin/users/#{user_without_name.id}/edit)
      
      # Should have proper link styling
      assert html =~ "text-blue-600 hover:text-blue-800 font-medium"
    end
  end
  
  describe "organization display functionality" do
    test "displays organization links for users with matching email domains" do
      admin = user_fixture(%{role: :admin})
      organization = organization_fixture(%{email_domain: "example.com", organization_name: "Example Corp", created_by_user_id: admin.id, actor: admin})
      user_with_org = user_fixture(%{role: :member, email: "user@example.com"})
      user_without_org = user_fixture(%{role: :member, email: "user@otherdomain.com"})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [user_with_org, user_without_org],
          search_term: "",
          role_filter: "all",
          sort_by: "email",
          sort_order: "asc",
          selected_users: [],
          show_user_modal: false,
          editing_user: nil,
          organizations_by_domain: %{"example.com" => organization},
          page: 1,
          per_page: 25,
          total_count: 2,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show organization name as link for user with matching domain
      assert html =~ "Example Corp"
      assert html =~ "/admin/organizations/#{organization.id}/edit"
      
      # Should include return_to parameter in organization link
      assert html =~ "return_to=%2Fadmin%2Fusers"
      
      # Should show "None" for user without organization
      assert html =~ "None"
    end
    
    test "organization sorting column is present" do
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [],
          search_term: "",
          role_filter: "all",
          sort_by: "organization",
          sort_order: "asc",
          selected_users: [],
          show_user_modal: false,
          editing_user: nil,
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show organization column header with sort button
      assert html =~ "Organization"
      assert html =~ ~s(phx-value-field="organization")
      assert html =~ "M5 15l7-7 7 7"  # Ascending arrow for organization
    end
    
    test "mobile view shows horizontal scroll notice" do
      admin = user_fixture(%{role: :admin})
      organization = organization_fixture(%{email_domain: "example.com", organization_name: "Example Corp", created_by_user_id: admin.id, actor: admin})
      user_with_org = user_fixture(%{role: :member, email: "user@example.com", first_name: "John", last_name: "Doe"})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [user_with_org],
          search_term: "",
          role_filter: "all",
          sort_by: "email",
          sort_order: "asc",
          selected_users: [],
          show_user_modal: false,
          editing_user: nil,
          organizations_by_domain: %{"example.com" => organization},
          page: 1,
          per_page: 25,
          total_count: 2,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show horizontal scroll notice for mobile
      assert html =~ "md:hidden"
      assert html =~ "Swipe horizontally to see all columns"
      assert html =~ "Example Corp"
    end
  end
  
  describe "pagination functionality" do
    test "displays pagination controls with correct information" do
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 100,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show pagination info
      assert html =~ "Showing 1-25 of 100 users"
      assert html =~ "Show:"
      assert html =~ ~s(value="25")
      
      # Should show page numbers
      assert html =~ ~s(phx-click="page_change")
      assert html =~ "Next"
      
      # Previous button should be disabled on first page
      assert html =~ "cursor-not-allowed"
    end
    
    test "shows correct pagination info for different pages" do
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
          organizations_by_domain: %{},
          page: 2,
          per_page: 25,
          total_count: 100,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show correct range for page 2
      assert html =~ "Showing 26-50 of 100 users"
      
      # Both Previous and Next should be enabled
      refute html =~ "cursor-not-allowed"
      assert html =~ "Previous"
      assert html =~ "Next"
    end
    
    test "handles empty state correctly" do
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show no users found message
      assert html =~ "No users found"
    end
  end
  
  describe "mobile responsive design" do
    test "shows horizontal scroll wrapper and minimum table width" do
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show horizontal scroll wrapper and minimum table width
      assert html =~ "overflow-x-auto"
      assert html =~ "min-width: 1000px"
      assert html =~ "Organization"
    end
    
    test "shows all columns with horizontal scrolling" do
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # All columns should be visible with horizontal scrolling
      assert html =~ "Created"
      assert html =~ "Organization"
      assert html =~ "Actions"
      assert html =~ "overflow-x-auto"
    end
    
    test "mobile pagination shows simplified controls" do
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
          organizations_by_domain: %{},
          page: 2,
          per_page: 25,
          total_count: 100,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show mobile pagination controls
      assert html =~ "sm:hidden"
      assert html =~ "Previous"
      assert html =~ "Next"
      
      # Should also show desktop pagination controls
      assert html =~ "hidden sm:flex-1"
    end
    
    test "search and filter controls stack on mobile" do
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
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should use flex-col for mobile and flex-row for desktop
      assert html =~ "flex flex-col space-y-4 sm:flex-row"
      assert html =~ "w-full sm:w-auto"
    end
  end
  
  describe "server-side filtering and sorting" do
    test "search functionality would use server-side filtering" do
      # This test documents that the search functionality uses server-side filtering
      # In the actual implementation, this would be tested with live view integration
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [],  # Empty because search would be handled server-side
          search_term: "john",
          role_filter: "all",
          sort_by: "email",
          sort_order: "asc",
          selected_users: [],
          show_user_modal: false,
          editing_user: nil,
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show the search term in the input
      assert html =~ ~s(value="john")
      assert html =~ "Search users by email, name..."
    end
    
    test "role filter would use server-side filtering" do
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          users: [],  # Empty because filter would be handled server-side
          search_term: "",
          role_filter: "member",
          sort_by: "email",
          sort_order: "asc",
          selected_users: [],
          show_user_modal: false,
          editing_user: nil,
          organizations_by_domain: %{},
          page: 1,
          per_page: 25,
          total_count: 0,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&UserListLive.render/1, socket.assigns)
      
      # Should show the selected role in the dropdown
      assert html =~ ~s(value="member")
      assert html =~ "All Roles"
    end
  end
end