defmodule SertantaiWeb.Admin.Billing.RoleManagementLive do
  use SertantaiWeb, :live_view
  
  alias Sertantai.Accounts
  alias Sertantai.Accounts.User
  alias Sertantai.Billing
  alias Sertantai.Billing.{Customer, Subscription}
  
  require Ash.Query
  import Ash.Expr
  
  @impl true
  def mount(_params, _session, socket) do
    {:ok, 
     socket
     |> assign(:page_title, "Role & Billing Management")
     |> assign(:search_query, "")
     |> load_data()}
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end
  
  defp apply_action(socket, :index, _params) do
    socket
  end
  
  defp apply_action(socket, :user_detail, %{"id" => id}) do
    user = User
      |> Ash.Query.filter(id == ^id)
      |> Ash.Query.load(customer: [subscriptions: :plan])
      |> Ash.read_one!(actor: socket.assigns.current_user)
    
    socket
    |> assign(:selected_user, user)
    |> assign(:page_title, "User Role Details: #{user.email}")
  end
  
  defp load_data(socket) do
    # Load users with billing relationship
    users = User
      |> Ash.Query.load(customer: [subscriptions: :plan])
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!(actor: socket.assigns.current_user)
    
    # Calculate statistics
    stats = %{
      total_users: length(users),
      members: Enum.count(users, &(&1.role == :member)),
      professionals: Enum.count(users, &(&1.role == :professional)),
      admins: Enum.count(users, &(&1.role == :admin)),
      support: Enum.count(users, &(&1.role == :support)),
      with_active_subscriptions: Enum.count(users, &has_active_subscription?/1),
      role_mismatches: Enum.count(users, &role_mismatch?/1)
    }
    
    socket
    |> assign(:users, users)
    |> assign(:filtered_users, users)
    |> assign(:stats, stats)
  end
  
  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    filtered_users = if query == "" do
      socket.assigns.users
    else
      Enum.filter(socket.assigns.users, fn user ->
        String.contains?(String.downcase(user.email), String.downcase(query)) ||
        (user.customer && String.contains?(String.downcase(user.customer.name || ""), String.downcase(query)))
      end)
    end
    
    {:noreply, 
     socket
     |> assign(:search_query, query)
     |> assign(:filtered_users, filtered_users)}
  end
  
  @impl true
  def handle_event("filter", %{"filter" => filter}, socket) do
    filtered_users = case filter do
      "all" -> socket.assigns.users
      "mismatches" -> Enum.filter(socket.assigns.users, &role_mismatch?/1)
      "active_subscriptions" -> Enum.filter(socket.assigns.users, &has_active_subscription?/1)
      "no_subscriptions" -> Enum.filter(socket.assigns.users, &(!has_active_subscription?(&1)))
      role -> Enum.filter(socket.assigns.users, &(&1.role == String.to_atom(role)))
    end
    
    {:noreply, assign(socket, :filtered_users, filtered_users)}
  end
  
  @impl true
  def handle_event("override_role", %{"user_id" => user_id, "new_role" => new_role}, socket) do
    user = Ash.get!(User, user_id, actor: socket.assigns.current_user)
    new_role = String.to_atom(new_role)
    
    case Ash.update(user, %{role: new_role}, actor: socket.assigns.current_user) do
      {:ok, _updated_user} ->
        # Log the manual override
        log_role_override(user, user.role, new_role, socket.assigns.current_user)
        
        {:noreply,
         socket
         |> put_flash(:info, "Role updated successfully")
         |> load_data()}
      
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to update role: #{inspect(error)}")}
    end
  end
  
  @impl true
  def handle_event("sync_role", %{"user_id" => user_id}, socket) do
    user = User
      |> Ash.Query.filter(id == ^user_id)
      |> Ash.Query.load(customer: [subscriptions: :plan])
      |> Ash.read_one!(actor: socket.assigns.current_user)
    
    expected_role = calculate_expected_role(user)
    
    if user.role != expected_role do
      case Ash.update(user, %{role: expected_role}, actor: socket.assigns.current_user) do
        {:ok, _updated_user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Role synced to #{expected_role}")
           |> load_data()}
        
        {:error, error} ->
          {:noreply, put_flash(socket, :error, "Failed to sync role: #{inspect(error)}")}
      end
    else
      {:noreply, put_flash(socket, :info, "Role is already in sync")}
    end
  end
  
  @impl true
  def handle_event("sync_all_roles", _params, socket) do
    mismatched_users = Enum.filter(socket.assigns.users, &role_mismatch?/1)
    
    results = Enum.map(mismatched_users, fn user ->
      expected_role = calculate_expected_role(user)
      
      case Ash.update(user, %{role: expected_role}, actor: socket.assigns.current_user) do
        {:ok, _} -> {:ok, user.id}
        {:error, _} -> {:error, user.id}
      end
    end)
    
    success_count = Enum.count(results, fn {status, _} -> status == :ok end)
    error_count = Enum.count(results, fn {status, _} -> status == :error end)
    
    message = if error_count == 0 do
      "Successfully synced #{success_count} user roles"
    else
      "Synced #{success_count} roles, #{error_count} errors"
    end
    
    {:noreply,
     socket
     |> put_flash(:info, message)
     |> load_data()}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <.header class="mb-6">
        <%= @page_title %>
        <:subtitle>
          Manage user roles and billing relationships
        </:subtitle>
      </.header>
      
      <!-- Statistics -->
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-6">
        <div class="bg-white rounded-lg shadow p-4">
          <div class="text-sm text-gray-500">Total Users</div>
          <div class="text-2xl font-bold text-gray-900"><%= @stats.total_users %></div>
        </div>
        <div class="bg-white rounded-lg shadow p-4">
          <div class="text-sm text-gray-500">Members</div>
          <div class="text-2xl font-bold text-gray-900"><%= @stats.members %></div>
        </div>
        <div class="bg-white rounded-lg shadow p-4">
          <div class="text-sm text-gray-500">Professionals</div>
          <div class="text-2xl font-bold text-blue-600"><%= @stats.professionals %></div>
        </div>
        <div class="bg-white rounded-lg shadow p-4">
          <div class="text-sm text-gray-500">Admins</div>
          <div class="text-2xl font-bold text-purple-600"><%= @stats.admins %></div>
        </div>
        <div class="bg-white rounded-lg shadow p-4">
          <div class="text-sm text-gray-500">Active Subs</div>
          <div class="text-2xl font-bold text-green-600"><%= @stats.with_active_subscriptions %></div>
        </div>
        <div class="bg-white rounded-lg shadow p-4">
          <div class="text-sm text-gray-500">Mismatches</div>
          <div class="text-2xl font-bold text-red-600"><%= @stats.role_mismatches %></div>
        </div>
      </div>
      
      <!-- Filters and Search -->
      <div class="bg-white rounded-lg shadow p-4 mb-6">
        <div class="flex flex-col md:flex-row gap-4">
          <form phx-change="search" class="flex-1">
            <.input
              name="search[query]"
              type="text"
              placeholder="Search by email or name..."
              value={@search_query}
              class="w-full"
            />
          </form>
          
          <div class="flex gap-2">
            <button phx-click="filter" phx-value-filter="all" 
              class="px-3 py-2 text-sm rounded-md bg-gray-100 hover:bg-gray-200">
              All
            </button>
            <button phx-click="filter" phx-value-filter="mismatches" 
              class="px-3 py-2 text-sm rounded-md bg-red-100 hover:bg-red-200 text-red-700">
              Mismatches (<%= @stats.role_mismatches %>)
            </button>
            <button phx-click="filter" phx-value-filter="active_subscriptions" 
              class="px-3 py-2 text-sm rounded-md bg-green-100 hover:bg-green-200 text-green-700">
              Active Subs
            </button>
            <button phx-click="filter" phx-value-filter="member" 
              class="px-3 py-2 text-sm rounded-md bg-gray-100 hover:bg-gray-200">
              Members
            </button>
            <button phx-click="filter" phx-value-filter="professional" 
              class="px-3 py-2 text-sm rounded-md bg-blue-100 hover:bg-blue-200 text-blue-700">
              Professionals
            </button>
          </div>
          
          <%= if @stats.role_mismatches > 0 do %>
            <button phx-click="sync_all_roles" 
              class="px-4 py-2 text-sm font-medium rounded-md bg-blue-600 text-white hover:bg-blue-700"
              data-confirm="This will sync all mismatched roles. Continue?">
              <.icon name="hero-arrow-path" class="w-4 h-4 inline mr-1" />
              Sync All Mismatches
            </button>
          <% end %>
        </div>
      </div>
      
      <!-- User List -->
      <div class="bg-white shadow rounded-lg overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  User
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Current Role
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Expected Role
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Active Subscription
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for user <- @filtered_users do %>
                <tr class={if role_mismatch?(user), do: "bg-red-50", else: "hover:bg-gray-50"}>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900">
                      <.link patch={~p"/admin/billing/role-management/#{user.id}"} 
                        class="text-blue-600 hover:text-blue-900">
                        <%= user.email %>
                      </.link>
                    </div>
                    <div class="text-sm text-gray-500">
                      <%= if user.customer, do: user.customer.name, else: "No billing info" %>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={[
                      "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                      role_badge_color(user.role)
                    ]}>
                      <%= user.role %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <% expected_role = calculate_expected_role(user) %>
                    <span class={[
                      "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                      role_badge_color(expected_role)
                    ]}>
                      <%= expected_role %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= if active_subscription = get_active_subscription(user) do %>
                      <div>
                        <div class="font-medium"><%= active_subscription.plan.name %></div>
                        <div class="text-xs text-gray-400">
                          <%= format_date(active_subscription.current_period_end) %>
                        </div>
                      </div>
                    <% else %>
                      <span class="text-gray-400">None</span>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <%= if role_mismatch?(user) do %>
                      <span class="inline-flex items-center px-2 py-1 text-xs font-medium rounded-full bg-red-100 text-red-800">
                        <.icon name="hero-exclamation-triangle" class="w-3 h-3 mr-1" />
                        Mismatch
                      </span>
                    <% else %>
                      <span class="inline-flex items-center px-2 py-1 text-xs font-medium rounded-full bg-green-100 text-green-800">
                        <.icon name="hero-check-circle" class="w-3 h-3 mr-1" />
                        In Sync
                      </span>
                    <% end %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <div class="flex gap-2">
                      <%= if role_mismatch?(user) do %>
                        <button 
                          phx-click="sync_role"
                          phx-value-user_id={user.id}
                          class="text-blue-600 hover:text-blue-900"
                        >
                          Sync
                        </button>
                      <% end %>
                      
                      <div class="relative inline-block text-left" x-data="{ open: false }">
                        <button 
                          @click="open = !open"
                          class="text-gray-600 hover:text-gray-900"
                        >
                          Override
                        </button>
                        <div 
                          x-show="open" 
                          @click.away="open = false"
                          x-transition
                          class="absolute right-0 z-10 mt-2 w-32 bg-white rounded-md shadow-lg ring-1 ring-black ring-opacity-5"
                        >
                          <div class="py-1">
                            <button 
                              phx-click="override_role"
                              phx-value-user_id={user.id}
                              phx-value-new_role="member"
                              @click="open = false"
                              class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                            >
                              Set to Member
                            </button>
                            <button 
                              phx-click="override_role"
                              phx-value-user_id={user.id}
                              phx-value-new_role="professional"
                              @click="open = false"
                              class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                            >
                              Set to Professional
                            </button>
                            <button 
                              phx-click="override_role"
                              phx-value-user_id={user.id}
                              phx-value-new_role="admin"
                              @click="open = false"
                              class="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                            >
                              Set to Admin
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
  
  # Helper functions
  
  defp has_active_subscription?(user) do
    user.customer && 
    user.customer.subscriptions &&
    Enum.any?(user.customer.subscriptions, &(&1.status == "active"))
  end
  
  defp get_active_subscription(user) do
    if user.customer && user.customer.subscriptions do
      Enum.find(user.customer.subscriptions, &(&1.status == "active"))
    end
  end
  
  defp calculate_expected_role(user) do
    cond do
      # Admin and support roles are manually managed
      user.role in [:admin, :support] -> user.role
      
      # Check for active subscription
      active_subscription = get_active_subscription(user) ->
        String.to_atom(active_subscription.plan.user_role || "professional")
      
      # Default to member if no active subscription
      true -> :member
    end
  end
  
  defp role_mismatch?(user) do
    expected = calculate_expected_role(user)
    # Don't flag admin/support as mismatches
    user.role not in [:admin, :support] && user.role != expected
  end
  
  defp role_badge_color(:admin), do: "bg-purple-100 text-purple-800"
  defp role_badge_color(:support), do: "bg-indigo-100 text-indigo-800"
  defp role_badge_color(:professional), do: "bg-blue-100 text-blue-800"
  defp role_badge_color(:member), do: "bg-gray-100 text-gray-800"
  defp role_badge_color(_), do: "bg-gray-100 text-gray-800"
  
  defp format_date(nil), do: "N/A"
  defp format_date(date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end
  
  defp log_role_override(user, from_role, to_role, admin) do
    # TODO: Implement audit logging
    require Logger
    Logger.info("Role override: User #{user.id} (#{user.email}) changed from #{from_role} to #{to_role} by admin #{admin.id}")
  end
end