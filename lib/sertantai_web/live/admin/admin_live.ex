defmodule SertantaiWeb.Admin.AdminLive do
  @moduledoc """
  Main admin interface LiveView with role-based access control.
  
  Only users with :admin or :support roles can access this interface.
  Provides the foundation for all admin functionality.
  """
  
  use SertantaiWeb, :live_view
  
  alias Sertantai.Accounts.User
  alias Sertantai.Organizations.Organization
  alias Sertantai.Sync.SyncConfiguration
  
  @impl true
  def mount(_params, _session, socket) do
    # Verify user has admin access (admin or support role)
    case socket.assigns[:current_user] do
      %User{role: role} when role in [:admin, :support] ->
        {:ok, 
         socket
         |> assign(:page_title, "Admin Dashboard")
         |> load_dashboard_stats()}
      
      %User{role: _role} ->
        # User is authenticated but doesn't have admin access
        socket = 
          socket
          |> put_flash(:error, "Access denied. Admin privileges required.")
          |> redirect(to: ~p"/dashboard")
        
        {:ok, socket}
      
      nil ->
        # User is not authenticated - should be caught by authentication plug
        socket = 
          socket
          |> put_flash(:error, "Please log in to access admin features.")
          |> redirect(to: ~p"/login")
        
        {:ok, socket}
    end
  end
  
  defp load_dashboard_stats(socket) do
    # Load real counts from database
    user_count = 
      case Ash.count(User, domain: Sertantai.Accounts) do
        {:ok, count} -> count
        _ -> 0
      end
      
    org_count = 
      case Ash.count(Organization, domain: Sertantai.Organizations) do
        {:ok, count} -> count
        _ -> 0
      end
      
    sync_count = 
      case Ash.count(SyncConfiguration, domain: Sertantai.Sync) do
        {:ok, count} -> count
        _ -> 0
      end
    
    socket
    |> assign(:user_count, user_count)
    |> assign(:org_count, org_count)
    |> assign(:sync_count, sync_count)
  end
  
  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Admin Header -->
      <header class="bg-white shadow-sm border-b border-gray-200">
        <div class="px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center py-4">
            <div class="flex items-center">
              <h1 class="text-xl sm:text-2xl font-bold text-gray-900">
                Sertantai Admin
              </h1>
              <span class="ml-2 sm:ml-4 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                <%= String.capitalize(to_string(@current_user.role)) %>
              </span>
            </div>
            
            <div class="flex items-center space-x-2 sm:space-x-4">
              <span class="hidden sm:inline text-sm text-gray-700">
                <%= @current_user.email %>
              </span>
              
              <.link
                href={~p"/dashboard"}
                class="inline-flex items-center px-2 sm:px-3 py-1 sm:py-2 border border-gray-300 shadow-sm text-xs sm:text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <svg class="sm:hidden h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                </svg>
                <span class="hidden sm:inline">Back to App</span>
              </.link>
            </div>
          </div>
        </div>
      </header>
      
      <div class="flex">
        <!-- Admin Sidebar Navigation -->
        <nav class="hidden lg:block w-64 bg-white shadow-sm border-r border-gray-200 min-h-screen">
          <div class="p-4">
            <ul class="space-y-2">
              <!-- Dashboard -->
              <li>
                <.link
                  patch={~p"/admin"}
                  class="flex items-center px-4 py-2 text-sm font-medium text-gray-700 rounded-md hover:bg-gray-50 hover:text-gray-900"
                >
                  <svg class="mr-3 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z" />
                  </svg>
                  Dashboard
                </.link>
              </li>
              
              <!-- User Management -->
              <li>
                <.link
                  patch={~p"/admin/users"}
                  class="flex items-center px-4 py-2 text-sm font-medium text-gray-700 rounded-md hover:bg-gray-50 hover:text-gray-900"
                >
                  <svg class="mr-3 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5 0a4 4 0 11-8 0 4 4 0 018 0z" />
                  </svg>
                  Users
                </.link>
              </li>
              
              <!-- Organization Management -->
              <li>
                <.link
                  patch={~p"/admin/organizations"}
                  class="flex items-center px-4 py-2 text-sm font-medium text-gray-700 rounded-md hover:bg-gray-50 hover:text-gray-900"
                >
                  <svg class="mr-3 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                  </svg>
                  Organizations
                </.link>
              </li>
              
              <!-- Sync Management -->
              <li>
                <.link
                  patch={~p"/admin/sync"}
                  class="flex items-center px-4 py-2 text-sm font-medium text-gray-700 rounded-md hover:bg-gray-50 hover:text-gray-900"
                >
                  <svg class="mr-3 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
                  </svg>
                  Sync Configurations
                </.link>
              </li>
              
              <!-- Billing (Admin only) -->
              <%= if @current_user.role == :admin do %>
                <li>
                  <.link
                    patch={~p"/admin/billing"}
                    class="flex items-center px-4 py-2 text-sm font-medium text-gray-700 rounded-md hover:bg-gray-50 hover:text-gray-900"
                  >
                    <svg class="mr-3 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                    </svg>
                    Billing
                  </.link>
                </li>
              <% end %>
              
              <!-- System Monitoring (Admin only) -->
              <%= if @current_user.role == :admin do %>
                <li>
                  <.link
                    patch={~p"/admin/system"}
                    class="flex items-center px-4 py-2 text-sm font-medium text-gray-700 rounded-md hover:bg-gray-50 hover:text-gray-900"
                  >
                    <svg class="mr-3 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 00-2-2z" />
                    </svg>
                    System
                  </.link>
                </li>
              <% end %>
            </ul>
          </div>
        </nav>
        
        <!-- Main Content Area -->
        <main class="flex-1 p-4 lg:p-6 overflow-x-hidden">
          <div class="max-w-full">
            <!-- Dashboard Content -->
            <div class="bg-white shadow rounded-lg p-4 lg:p-6">
              <h2 class="text-lg font-medium text-gray-900 mb-6">
                Admin Dashboard
              </h2>
              
              <!-- Quick Stats -->
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
                <div class="bg-blue-50 rounded-lg p-4 sm:p-6">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center flex-1 min-w-0">
                      <div class="flex-shrink-0">
                        <svg class="h-8 w-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5 0a4 4 0 11-8 0 4 4 0 018 0z" />
                        </svg>
                      </div>
                      <div class="ml-4 flex-1 min-w-0">
                        <p class="text-sm font-medium text-blue-600 truncate">Total Users</p>
                        <p class="text-2xl font-bold text-gray-900">
                          <%= @user_count %>
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
                
                <div class="bg-green-50 rounded-lg p-4 sm:p-6">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center flex-1 min-w-0">
                      <div class="flex-shrink-0">
                        <svg class="h-8 w-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                        </svg>
                      </div>
                      <div class="ml-4 flex-1 min-w-0">
                        <p class="text-sm font-medium text-green-600 truncate">Organizations</p>
                        <p class="text-2xl font-bold text-gray-900">
                          <%= @org_count %>
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
                
                <div class="bg-yellow-50 rounded-lg p-4 sm:p-6">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center flex-1 min-w-0">
                      <div class="flex-shrink-0">
                        <svg class="h-8 w-8 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
                        </svg>
                      </div>
                      <div class="ml-4 flex-1 min-w-0">
                        <p class="text-sm font-medium text-yellow-600 truncate">Sync Configs</p>
                        <p class="text-2xl font-bold text-gray-900">
                          <%= @sync_count %>
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              
              <!-- Welcome Message -->
              <div class="bg-gray-50 rounded-lg p-6">
                <h3 class="text-lg font-medium text-gray-900 mb-2">
                  Welcome to Sertantai Admin
                </h3>
                <p class="text-gray-700 mb-4">
                  Use the navigation menu on the left to manage users, organizations, and system settings.
                  <%= if @current_user.role == :support do %>
                    As a support team member, you have read access to help users and limited write permissions.
                  <% else %>
                    As an administrator, you have full access to all system features and user management.
                  <% end %>
                </p>
                
                <div class="flex space-x-4">
                  <.link
                    patch={~p"/admin/users"}
                    class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    Manage Users
                  </.link>
                  
                  <.link
                    patch={~p"/admin/organizations"}
                    class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    View Organizations
                  </.link>
                </div>
              </div>
            </div>
            
            <!-- Mobile Navigation Menu -->
            <div class="lg:hidden mt-8">
              <nav class="bg-white rounded-lg shadow p-4">
                <h3 class="text-sm font-medium text-gray-500 uppercase tracking-wider mb-3">Admin Menu</h3>
                <div class="grid grid-cols-2 gap-3">
                  <.link
                    patch={~p"/admin/users"}
                    class="flex items-center p-3 text-sm font-medium text-gray-700 rounded-md bg-gray-50 hover:bg-gray-100"
                  >
                    <svg class="mr-2 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5 0a4 4 0 11-8 0 4 4 0 018 0z" />
                    </svg>
                    Users
                  </.link>
                  
                  <.link
                    patch={~p"/admin/organizations"}
                    class="flex items-center p-3 text-sm font-medium text-gray-700 rounded-md bg-gray-50 hover:bg-gray-100"
                  >
                    <svg class="mr-2 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                    </svg>
                    Orgs
                  </.link>
                  
                  <.link
                    patch={~p"/admin/sync"}
                    class="flex items-center p-3 text-sm font-medium text-gray-700 rounded-md bg-gray-50 hover:bg-gray-100"
                  >
                    <svg class="mr-2 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
                    </svg>
                    Sync
                  </.link>
                  
                  <%= if @current_user.role == :admin do %>
                    <.link
                      patch={~p"/admin/billing"}
                      class="flex items-center p-3 text-sm font-medium text-gray-700 rounded-md bg-gray-50 hover:bg-gray-100"
                    >
                      <svg class="mr-2 h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                      </svg>
                      Billing
                    </.link>
                  <% end %>
                </div>
              </nav>
            </div>
          </div>
        </main>
      </div>
    </div>
    """
  end
end