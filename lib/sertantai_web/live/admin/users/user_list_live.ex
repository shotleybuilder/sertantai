defmodule SertantaiWeb.Admin.Users.UserListLive do
  @moduledoc """
  User management interface for admin and support users.
  
  Features:
  - Paginated user list with search and filtering
  - Role-based access control (admin/support)
  - User creation, editing, and role management
  - Bulk operations for user management
  """
  
  use SertantaiWeb, :live_view
  
  alias Sertantai.Accounts.User
  
  @impl true
  def mount(_params, _session, socket) do
    # Verify user has admin access
    case socket.assigns[:current_user] do
      %User{role: role} when role in [:admin, :support] ->
        {:ok, 
         socket
         |> assign(:page_title, "User Management")
         |> assign(:search_term, "")
         |> assign(:role_filter, "all")
         |> assign(:sort_by, "email")
         |> assign(:sort_order, "asc")
         |> assign(:selected_users, [])
         |> assign(:show_user_modal, false)
         |> assign(:editing_user, nil)
         |> load_users()}
      
      _ ->
        socket = 
          socket
          |> put_flash(:error, "Access denied. Admin privileges required.")
          |> redirect(to: ~p"/admin")
        
        {:ok, socket}
    end
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end
  
  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:editing_user, nil)
    |> assign(:show_user_modal, false)
  end
  
  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:editing_user, nil)
    |> assign(:show_user_modal, true)
  end
  
  defp apply_action(socket, :edit, %{"id" => id}) do
    case Ash.get(User, id, actor: socket.assigns.current_user) do
      {:ok, user} ->
        socket
        |> assign(:editing_user, user)
        |> assign(:show_user_modal, true)
      
      {:error, _} ->
        socket
        |> put_flash(:error, "User not found")
        |> redirect(to: ~p"/admin/users")
    end
  end
  
  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    {:noreply, 
     socket
     |> assign(:search_term, search_term)
     |> load_users()}
  end
  
  def handle_event("filter_by_role", %{"role" => role}, socket) do
    {:noreply, 
     socket
     |> assign(:role_filter, role)
     |> load_users()}
  end
  
  def handle_event("sort", %{"field" => field}, socket) do
    {sort_by, sort_order} = 
      if socket.assigns.sort_by == field do
        {field, if(socket.assigns.sort_order == "asc", do: "desc", else: "asc")}
      else
        {field, "asc"}
      end
    
    {:noreply, 
     socket
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> load_users()}
  end
  
  def handle_event("select_user", %{"id" => id}, socket) do
    selected_users = 
      if id in socket.assigns.selected_users do
        List.delete(socket.assigns.selected_users, id)
      else
        [id | socket.assigns.selected_users]
      end
    
    {:noreply, assign(socket, :selected_users, selected_users)}
  end
  
  def handle_event("select_all", _params, socket) do
    all_user_ids = Enum.map(socket.assigns.users, & &1.id)
    {:noreply, assign(socket, :selected_users, all_user_ids)}
  end
  
  def handle_event("deselect_all", _params, socket) do
    {:noreply, assign(socket, :selected_users, [])}
  end
  
  def handle_event("close_modal", _params, socket) do
    {:noreply, 
     socket
     |> assign(:show_user_modal, false)
     |> assign(:editing_user, nil)}
  end
  
  def handle_event("delete_user", %{"id" => id}, socket) do
    # Only admins can delete users
    case socket.assigns.current_user.role do
      :admin ->
        case Ash.get(User, id, actor: socket.assigns.current_user) do
          {:ok, user} ->
            case Ash.destroy(user, actor: socket.assigns.current_user) do
              :ok ->
                {:noreply, 
                 socket
                 |> put_flash(:info, "User deleted successfully")
                 |> load_users()}
              
              {:error, _error} ->
                {:noreply, put_flash(socket, :error, "Failed to delete user")}
            end
          
          {:error, _} ->
            {:noreply, put_flash(socket, :error, "User not found")}
        end
      
      _ ->
        {:noreply, put_flash(socket, :error, "Only administrators can delete users")}
    end
  end
  
  def handle_event("bulk_delete", _params, socket) do
    case socket.assigns.current_user.role do
      :admin ->
        deleted_count = 
          socket.assigns.selected_users
          |> Enum.reduce(0, fn user_id, count ->
            case Ash.get(User, user_id, actor: socket.assigns.current_user) do
              {:ok, user} ->
                case Ash.destroy(user, actor: socket.assigns.current_user) do
                  :ok -> count + 1
                  _ -> count
                end
              
              _ -> count
            end
          end)
        
        {:noreply, 
         socket
         |> put_flash(:info, "#{deleted_count} users deleted successfully")
         |> assign(:selected_users, [])
         |> load_users()}
      
      _ ->
        {:noreply, put_flash(socket, :error, "Only administrators can delete users")}
    end
  end
  
  def handle_event("bulk_role_change", %{"role" => role}, socket) do
    case socket.assigns.current_user.role do
      :admin ->
        role_atom = String.to_existing_atom(role)
        
        updated_count = 
          socket.assigns.selected_users
          |> Enum.reduce(0, fn user_id, count ->
            case Ash.get(User, user_id, actor: socket.assigns.current_user) do
              {:ok, user} ->
                case Ash.update(user, %{role: role_atom}, action: :update_role, actor: socket.assigns.current_user) do
                  {:ok, _} -> count + 1
                  _ -> count
                end
              
              _ -> count
            end
          end)
        
        {:noreply, 
         socket
         |> put_flash(:info, "#{updated_count} users updated successfully")
         |> assign(:selected_users, [])
         |> load_users()}
      
      _ ->
        {:noreply, put_flash(socket, :error, "Only administrators can change user roles")}
    end
  end
  
  @impl true
  def handle_info({:user_created, message}, socket) do
    {:noreply, 
     socket
     |> put_flash(:info, message)
     |> assign(:show_user_modal, false)
     |> load_users()}
  end
  
  def handle_info({:user_updated, message}, socket) do
    {:noreply, 
     socket
     |> put_flash(:info, message)
     |> assign(:show_user_modal, false)
     |> load_users()}
  end
  
  def handle_info({:close_modal}, socket) do
    {:noreply, 
     socket
     |> assign(:show_user_modal, false)
     |> assign(:editing_user, nil)}
  end
  
  defp load_users(socket) do
    # Load users with pagination
    case Ash.read(User, actor: socket.assigns.current_user) do
      {:ok, users} ->
        # Apply filters in memory for now (can be optimized later)
        filtered_users = apply_filters(users, socket.assigns)
        assign(socket, :users, filtered_users)
      
      {:error, _error} ->
        socket
        |> put_flash(:error, "Failed to load users")
        |> assign(:users, [])
    end
  end
  
  defp apply_filters(users, assigns) do
    users
    |> filter_by_search(assigns.search_term)
    |> filter_by_role(assigns.role_filter)
    |> sort_users(assigns.sort_by, assigns.sort_order)
  end
  
  defp filter_by_search(users, ""), do: users
  defp filter_by_search(users, search_term) do
    search_term = String.downcase(search_term)
    
    Enum.filter(users, fn user ->
      email_match = String.downcase(user.email || "") |> String.contains?(search_term)
      first_name_match = String.downcase(user.first_name || "") |> String.contains?(search_term)
      last_name_match = String.downcase(user.last_name || "") |> String.contains?(search_term)
      
      email_match || first_name_match || last_name_match
    end)
  end
  
  defp filter_by_role(users, "all"), do: users
  defp filter_by_role(users, role) do
    role_atom = String.to_existing_atom(role)
    Enum.filter(users, fn user -> user.role == role_atom end)
  end
  
  defp sort_users(users, sort_by, sort_order) do
    sort_field = String.to_existing_atom(sort_by)
    
    sorted = Enum.sort_by(users, fn user ->
      case sort_field do
        :email -> user.email || ""
        :first_name -> user.first_name || ""
        :last_name -> user.last_name || ""
        :role -> to_string(user.role)
        :inserted_at -> user.inserted_at
        _ -> ""
      end
    end)
    
    case sort_order do
      "desc" -> Enum.reverse(sorted)
      _ -> sorted
    end
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto">
      <!-- Header -->
      <div class="bg-white shadow rounded-lg mb-6">
        <div class="px-6 py-4 border-b border-gray-200">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">User Management</h1>
              <p class="text-sm text-gray-600 mt-1">
                Manage user accounts, roles, and permissions
              </p>
            </div>
            
            <%= if @current_user.role == :admin do %>
              <.link
                patch={~p"/admin/users/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <svg class="-ml-1 mr-2 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                </svg>
                New User
              </.link>
            <% end %>
          </div>
        </div>
        
        <!-- Search and Filter Controls -->
        <div class="px-6 py-4 bg-gray-50">
          <div class="flex flex-wrap items-center space-x-4">
            <!-- Search -->
            <div class="flex-1 min-w-0">
              <form phx-submit="search">
                <div class="relative">
                  <input
                    type="text"
                    name="search"
                    value={@search_term}
                    placeholder="Search users by email, name..."
                    class="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                  />
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                    </svg>
                  </div>
                </div>
              </form>
            </div>
            
            <!-- Role Filter -->
            <div>
              <select
                phx-change="filter_by_role"
                name="role"
                value={@role_filter}
                class="block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm rounded-md"
              >
                <option value="all">All Roles</option>
                <option value="admin">Admin</option>
                <option value="support">Support</option>
                <option value="professional">Professional</option>
                <option value="member">Member</option>
                <option value="guest">Guest</option>
              </select>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Bulk Actions -->
      <%= if length(@selected_users) > 0 do %>
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <span class="text-sm font-medium text-blue-900">
                <%= length(@selected_users) %> user(s) selected
              </span>
              <button
                phx-click="deselect_all"
                class="ml-4 text-sm text-blue-700 hover:text-blue-900"
              >
                Clear selection
              </button>
            </div>
            
            <%= if @current_user.role == :admin do %>
              <div class="flex space-x-2">
                <!-- Bulk Role Change -->
                <select
                  phx-change="bulk_role_change"
                  name="role"
                  class="text-sm border-gray-300 rounded-md"
                >
                  <option value="">Change Role...</option>
                  <option value="admin">Admin</option>
                  <option value="support">Support</option>
                  <option value="professional">Professional</option>
                  <option value="member">Member</option>
                  <option value="guest">Guest</option>
                </select>
                
                <!-- Bulk Delete -->
                <button
                  phx-click="bulk_delete"
                  onclick="return confirm('Are you sure you want to delete the selected users?')"
                  class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-red-700 bg-red-100 hover:bg-red-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                >
                  Delete Selected
                </button>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
      
      <!-- Users Table -->
      <div class="bg-white shadow overflow-hidden rounded-lg">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <input
                  type="checkbox"
                  phx-click="select_all"
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
              </th>
              
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <button
                  phx-click="sort"
                  phx-value-field="email"
                  class="group inline-flex items-center hover:text-gray-900"
                >
                  Email
                  <%= if @sort_by == "email" do %>
                    <svg class="ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <%= if @sort_order == "asc" do %>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                      <% else %>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                      <% end %>
                    </svg>
                  <% end %>
                </button>
              </th>
              
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <button
                  phx-click="sort"
                  phx-value-field="first_name"
                  class="group inline-flex items-center hover:text-gray-900"
                >
                  Name
                  <%= if @sort_by == "first_name" do %>
                    <svg class="ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <%= if @sort_order == "asc" do %>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                      <% else %>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                      <% end %>
                    </svg>
                  <% end %>
                </button>
              </th>
              
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <button
                  phx-click="sort"
                  phx-value-field="role"
                  class="group inline-flex items-center hover:text-gray-900"
                >
                  Role
                  <%= if @sort_by == "role" do %>
                    <svg class="ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <%= if @sort_order == "asc" do %>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                      <% else %>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                      <% end %>
                    </svg>
                  <% end %>
                </button>
              </th>
              
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                <button
                  phx-click="sort"
                  phx-value-field="inserted_at"
                  class="group inline-flex items-center hover:text-gray-900"
                >
                  Created
                  <%= if @sort_by == "inserted_at" do %>
                    <svg class="ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <%= if @sort_order == "asc" do %>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                      <% else %>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                      <% end %>
                    </svg>
                  <% end %>
                </button>
              </th>
              
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for user <- @users do %>
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <input
                    type="checkbox"
                    phx-click="select_user"
                    phx-value-id={user.id}
                    checked={user.id in @selected_users}
                    class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  />
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm font-medium text-gray-900">
                    <%= user.email %>
                  </div>
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm text-gray-900">
                    <%= if user.first_name || user.last_name do %>
                      <%= [user.first_name, user.last_name] |> Enum.filter(& &1) |> Enum.join(" ") %>
                    <% else %>
                      <span class="text-gray-400">No name</span>
                    <% end %>
                  </div>
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={[
                    "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                    case user.role do
                      :admin -> "bg-red-100 text-red-800"
                      :support -> "bg-blue-100 text-blue-800"
                      :professional -> "bg-green-100 text-green-800"
                      :member -> "bg-yellow-100 text-yellow-800"
                      :guest -> "bg-gray-100 text-gray-800"
                    end
                  ]}>
                    <%= String.capitalize(to_string(user.role)) %>
                  </span>
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  <%= Calendar.strftime(user.inserted_at, "%Y-%m-%d") %>
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <div class="flex justify-end space-x-2">
                    <.link
                      patch={~p"/admin/users/#{user.id}/edit"}
                      class="text-blue-600 hover:text-blue-900"
                    >
                      Edit
                    </.link>
                    
                    <%= if @current_user.role == :admin && user.id != @current_user.id do %>
                      <button
                        phx-click="delete_user"
                        phx-value-id={user.id}
                        onclick="return confirm('Are you sure you want to delete this user?')"
                        class="text-red-600 hover:text-red-900"
                      >
                        Delete
                      </button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
            
            <%= if @users == [] do %>
              <tr>
                <td colspan="6" class="px-6 py-4 text-center text-gray-500">
                  No users found matching your criteria.
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
      
      <!-- User Modal -->
      <%= if @show_user_modal do %>
        <.live_component
          module={SertantaiWeb.Admin.Users.UserFormComponent}
          id="user-form"
          user={@editing_user}
          current_user={@current_user}
          on_close={JS.patch(~p"/admin/users")}
        />
      <% end %>
    </div>
    """
  end
end