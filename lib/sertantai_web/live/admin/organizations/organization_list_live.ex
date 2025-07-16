defmodule SertantaiWeb.Admin.Organizations.OrganizationListLive do
  @moduledoc """
  Organization management interface for admin users.
  
  Provides comprehensive organization CRUD operations with search,
  filtering, and bulk management capabilities.
  """
  
  use SertantaiWeb, :live_view
  
  alias Sertantai.Organizations.Organization
  alias SertantaiWeb.Admin.Organizations.OrganizationFormComponent
  
  @impl true
  def mount(_params, _session, socket) do
    # Load organizations using Ash
    case Ash.read(Organization, actor: socket.assigns.current_user) do
      {:ok, organizations} ->
        {:ok,
         socket
         |> assign(:organizations, organizations)
         |> assign(:all_organizations, organizations)
         |> assign(:search_term, "")
         |> assign(:status_filter, "all")
         |> assign(:verification_filter, "all")
         |> assign(:sort_by, "organization_name")
         |> assign(:sort_order, "asc")
         |> assign(:selected_organizations, [])
         |> assign(:show_organization_modal, false)
         |> assign(:editing_organization, nil)}
      
      {:error, _error} ->
        {:ok,
         socket
         |> put_flash(:error, "Failed to load organizations")
         |> assign(:organizations, [])
         |> assign(:all_organizations, [])
         |> assign(:search_term, "")
         |> assign(:status_filter, "all")
         |> assign(:verification_filter, "all")
         |> assign(:sort_by, "organization_name")
         |> assign(:sort_order, "asc")
         |> assign(:selected_organizations, [])
         |> assign(:show_organization_modal, false)
         |> assign(:editing_organization, nil)}
    end
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    socket = 
      socket
      |> assign(:return_to, params["return_to"])
    
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end
  
  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:show_organization_modal, true)
    |> assign(:editing_organization, nil)
  end
  
  defp apply_action(socket, :edit, %{"id" => id}) do
    case Ash.get(Organization, id, actor: socket.assigns.current_user) do
      {:ok, organization} ->
        socket
        |> assign(:show_organization_modal, true)
        |> assign(:editing_organization, organization)
      
      {:error, _error} ->
        socket
        |> put_flash(:error, "Organization not found")
        |> assign(:show_organization_modal, false)
        |> assign(:editing_organization, nil)
    end
  end
  
  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:show_organization_modal, false)
    |> assign(:editing_organization, nil)
  end
  
  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    organizations = filter_and_sort_organizations(socket.assigns.all_organizations, search_term, socket.assigns.status_filter, socket.assigns.verification_filter, socket.assigns.sort_by, socket.assigns.sort_order)
    
    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:organizations, organizations)
     |> assign(:selected_organizations, [])}
  end
  
  def handle_event("filter_status", %{"status" => status}, socket) do
    organizations = filter_and_sort_organizations(socket.assigns.all_organizations, socket.assigns.search_term, status, socket.assigns.verification_filter, socket.assigns.sort_by, socket.assigns.sort_order)
    
    {:noreply,
     socket
     |> assign(:status_filter, status)
     |> assign(:organizations, organizations)
     |> assign(:selected_organizations, [])}
  end
  
  def handle_event("filter_verification", %{"verification" => verification}, socket) do
    organizations = filter_and_sort_organizations(socket.assigns.all_organizations, socket.assigns.search_term, socket.assigns.status_filter, verification, socket.assigns.sort_by, socket.assigns.sort_order)
    
    {:noreply,
     socket
     |> assign(:verification_filter, verification)
     |> assign(:organizations, organizations)
     |> assign(:selected_organizations, [])}
  end
  
  def handle_event("sort", %{"field" => field}, socket) do
    {sort_by, sort_order} = 
      if socket.assigns.sort_by == field do
        {field, if(socket.assigns.sort_order == "asc", do: "desc", else: "asc")}
      else
        {field, "asc"}
      end
    
    organizations = filter_and_sort_organizations(socket.assigns.all_organizations, socket.assigns.search_term, socket.assigns.status_filter, socket.assigns.verification_filter, sort_by, sort_order)
    
    {:noreply,
     socket
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> assign(:organizations, organizations)}
  end
  
  def handle_event("select_organization", %{"id" => id}, socket) do
    selected = socket.assigns.selected_organizations
    new_selected = 
      if id in selected do
        List.delete(selected, id)
      else
        [id | selected]
      end
    
    {:noreply, assign(socket, :selected_organizations, new_selected)}
  end
  
  def handle_event("select_all", _params, socket) do
    all_ids = Enum.map(socket.assigns.organizations, & &1.id)
    {:noreply, assign(socket, :selected_organizations, all_ids)}
  end
  
  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_organizations, [])}
  end
  
  def handle_event("bulk_verify", _params, socket) do
    socket.assigns.selected_organizations
    |> Enum.each(fn id ->
      case Ash.get(Organization, id, actor: socket.assigns.current_user) do
        {:ok, organization} ->
          Ash.update(organization, %{verified: true}, actor: socket.assigns.current_user)
        {:error, _error} ->
          :ok
      end
    end)
    
    # Reload organizations
    case Ash.read(Organization, actor: socket.assigns.current_user) do
      {:ok, organizations} ->
        filtered_organizations = filter_and_sort_organizations(organizations, socket.assigns.search_term, socket.assigns.status_filter, socket.assigns.verification_filter, socket.assigns.sort_by, socket.assigns.sort_order)
        
        {:noreply,
         socket
         |> assign(:organizations, filtered_organizations)
         |> assign(:all_organizations, organizations)
         |> assign(:selected_organizations, [])
         |> put_flash(:info, "Organizations verified successfully")}
      
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to reload organizations")}
    end
  end
  
  def handle_event("bulk_delete", _params, socket) do
    if socket.assigns.current_user.role == :admin do
      socket.assigns.selected_organizations
      |> Enum.each(fn id ->
        case Ash.get(Organization, id, actor: socket.assigns.current_user) do
          {:ok, organization} ->
            Ash.destroy(organization, actor: socket.assigns.current_user)
          {:error, _error} ->
            :ok
        end
      end)
      
      # Reload organizations
      case Ash.read(Organization, actor: socket.assigns.current_user) do
        {:ok, organizations} ->
          filtered_organizations = filter_and_sort_organizations(organizations, socket.assigns.search_term, socket.assigns.status_filter, socket.assigns.verification_filter, socket.assigns.sort_by, socket.assigns.sort_order)
          
          {:noreply,
           socket
           |> assign(:organizations, filtered_organizations)
           |> assign(:all_organizations, organizations)
           |> assign(:selected_organizations, [])
           |> put_flash(:info, "Organizations deleted successfully")}
        
        {:error, _error} ->
          {:noreply, put_flash(socket, :error, "Failed to reload organizations")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only admins can delete organizations")}
    end
  end
  
  def handle_event("delete_organization", %{"id" => id}, socket) do
    if socket.assigns.current_user.role == :admin do
      case Ash.get(Organization, id, actor: socket.assigns.current_user) do
        {:ok, organization} ->
          case Ash.destroy(organization, actor: socket.assigns.current_user) do
            :ok ->
              # Reload organizations
              case Ash.read(Organization, actor: socket.assigns.current_user) do
                {:ok, organizations} ->
                  filtered_organizations = filter_and_sort_organizations(organizations, socket.assigns.search_term, socket.assigns.status_filter, socket.assigns.verification_filter, socket.assigns.sort_by, socket.assigns.sort_order)
                  
                  {:noreply,
                   socket
                   |> assign(:organizations, filtered_organizations)
                   |> assign(:all_organizations, organizations)
                   |> put_flash(:info, "Organization deleted successfully")}
                
                {:error, _error} ->
                  {:noreply, put_flash(socket, :error, "Failed to reload organizations")}
              end
            
            {:error, _error} ->
              {:noreply, put_flash(socket, :error, "Failed to delete organization")}
          end
        
        {:error, _error} ->
          {:noreply, put_flash(socket, :error, "Organization not found")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only admins can delete organizations")}
    end
  end
  
  @impl true
  def handle_info({:organization_created, message}, socket) do
    # Reload organizations
    case Ash.read(Organization, actor: socket.assigns.current_user) do
      {:ok, organizations} ->
        filtered_organizations = filter_and_sort_organizations(organizations, socket.assigns.search_term, socket.assigns.status_filter, socket.assigns.verification_filter, socket.assigns.sort_by, socket.assigns.sort_order)
        
        {:noreply,
         socket
         |> assign(:organizations, filtered_organizations)
         |> assign(:all_organizations, organizations)
         |> assign(:show_organization_modal, false)
         |> put_flash(:info, message)}
      
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to reload organizations")}
    end
  end
  
  def handle_info({:organization_updated, message}, socket) do
    # Determine where to redirect after update
    redirect_path = socket.assigns[:return_to] || ~p"/admin/organizations"
    
    # Reload organizations
    case Ash.read(Organization, actor: socket.assigns.current_user) do
      {:ok, organizations} ->
        filtered_organizations = filter_and_sort_organizations(organizations, socket.assigns.search_term, socket.assigns.status_filter, socket.assigns.verification_filter, socket.assigns.sort_by, socket.assigns.sort_order)
        
        {:noreply,
         socket
         |> assign(:organizations, filtered_organizations)
         |> assign(:all_organizations, organizations)
         |> assign(:show_organization_modal, false)
         |> put_flash(:info, message)
         |> push_navigate(to: redirect_path)}
      
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to reload organizations")}
    end
  end
  
  def handle_info({:close_modal}, socket) do
    # Determine where to redirect after closing modal
    redirect_path = socket.assigns[:return_to] || ~p"/admin/organizations"
    
    {:noreply,
     socket
     |> assign(:show_organization_modal, false)
     |> push_navigate(to: redirect_path)}
  end
  
  # Helper function to filter and sort organizations
  defp filter_and_sort_organizations(organizations, search_term, _status_filter, verification_filter, sort_by, sort_order) do
    organizations
    |> filter_by_search(search_term)
    |> filter_by_verification(verification_filter)
    |> sort_organizations(sort_by, sort_order)
  end
  
  defp filter_by_search(organizations, ""), do: organizations
  defp filter_by_search(organizations, search_term) do
    search_lower = String.downcase(search_term)
    
    Enum.filter(organizations, fn org ->
      String.contains?(String.downcase(org.organization_name), search_lower) or
      String.contains?(String.downcase(org.email_domain), search_lower) or
      (org.core_profile["industry_sector"] && String.contains?(String.downcase(org.core_profile["industry_sector"]), search_lower))
    end)
  end
  
  defp filter_by_verification(organizations, "all"), do: organizations
  defp filter_by_verification(organizations, "verified") do
    Enum.filter(organizations, & &1.verified)
  end
  defp filter_by_verification(organizations, "unverified") do
    Enum.filter(organizations, &(!&1.verified))
  end
  
  defp sort_organizations(organizations, sort_by, sort_order) do
    sorted = 
      case sort_by do
        "organization_name" ->
          Enum.sort_by(organizations, & &1.organization_name)
        "email_domain" ->
          Enum.sort_by(organizations, & &1.email_domain)
        "verified" ->
          Enum.sort_by(organizations, & &1.verified)
        "inserted_at" ->
          Enum.sort_by(organizations, & &1.inserted_at, DateTime)
        "profile_completeness_score" ->
          Enum.sort_by(organizations, & &1.profile_completeness_score)
        _ ->
          organizations
      end
    
    if sort_order == "desc" do
      Enum.reverse(sorted)
    else
      sorted
    end
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Breadcrumb Navigation -->
      <nav class="mb-4" aria-label="Breadcrumb">
        <ol class="flex items-center space-x-2 text-sm text-gray-500">
          <li>
            <.link
              navigate={~p"/admin"}
              class="text-gray-400 hover:text-gray-600 transition-colors duration-200"
            >
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 5v4" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 5v4" />
              </svg>
              Admin Dashboard
            </.link>
          </li>
          <li>
            <svg class="h-4 w-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </li>
          <li class="text-gray-900 font-medium">
            Organization Management
          </li>
        </ol>
      </nav>
      
      <!-- Header -->
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Organization Management</h1>
          <p class="mt-2 text-sm text-gray-700">
            Manage organizations, their verification status, and profile information.
          </p>
        </div>
        <%= if @current_user.role == :admin do %>
          <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
            <.link
              patch={~p"/admin/organizations/new"}
              class="inline-flex items-center justify-center rounded-md border border-transparent bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 sm:w-auto"
            >
              New Organization
            </.link>
          </div>
        <% end %>
      </div>

      <!-- Search and Filters -->
      <div class="bg-white p-4 rounded-lg shadow space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <!-- Search -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
            <input
              type="text"
              value={@search_term}
              phx-change="search"
              name="search"
              placeholder="Search by name, domain, or industry..."
              class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            />
          </div>

          <!-- Verification Filter -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Verification Status</label>
            <select
              phx-change="filter_verification"
              name="verification"
              value={@verification_filter}
              class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            >
              <option value="all">All Organizations</option>
              <option value="verified">Verified Only</option>
              <option value="unverified">Unverified Only</option>
            </select>
          </div>

          <!-- Results Info -->
          <div class="flex items-center justify-between">
            <span class="text-sm text-gray-500">
              <%= length(@organizations) %> organization(s)
            </span>
            <%= if length(@selected_organizations) > 0 do %>
              <span class="text-sm font-medium text-blue-600">
                <%= length(@selected_organizations) %> selected
              </span>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Bulk Actions -->
      <%= if length(@selected_organizations) > 0 do %>
        <div class="bg-blue-50 p-4 rounded-lg border border-blue-200">
          <div class="flex items-center justify-between">
            <span class="text-sm font-medium text-blue-800">
              <%= length(@selected_organizations) %> organization(s) selected
            </span>
            <div class="flex space-x-2">
              <button
                phx-click="bulk_verify"
                class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded text-green-700 bg-green-100 hover:bg-green-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
              >
                Verify Selected
              </button>
              <%= if @current_user.role == :admin do %>
                <button
                  phx-click="bulk_delete"
                  data-confirm="Are you sure you want to delete the selected organizations?"
                  class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded text-red-700 bg-red-100 hover:bg-red-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                >
                  Delete Selected
                </button>
              <% end %>
              <button
                phx-click="clear_selection"
                class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Clear Selection
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Organizations Table -->
      <div class="bg-white shadow rounded-lg overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="w-8 px-6 py-3">
                <input
                  type="checkbox"
                  phx-click="select_all"
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
              </th>
              
              <th
                phx-click="sort"
                phx-value-field="organization_name"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Organization</span>
                  <%= if @sort_by == "organization_name" do %>
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <%= if @sort_order == "asc" do %>
                        <path d="M5 8l5-5 5 5H5z"/>
                      <% else %>
                        <path d="M15 12l-5 5-5-5h10z"/>
                      <% end %>
                    </svg>
                  <% end %>
                </div>
              </th>
              
              <th
                phx-click="sort"
                phx-value-field="email_domain"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Domain</span>
                  <%= if @sort_by == "email_domain" do %>
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <%= if @sort_order == "asc" do %>
                        <path d="M5 8l5-5 5 5H5z"/>
                      <% else %>
                        <path d="M15 12l-5 5-5-5h10z"/>
                      <% end %>
                    </svg>
                  <% end %>
                </div>
              </th>
              
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Industry
              </th>
              
              <th
                phx-click="sort"
                phx-value-field="verified"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Status</span>
                  <%= if @sort_by == "verified" do %>
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <%= if @sort_order == "asc" do %>
                        <path d="M5 8l5-5 5 5H5z"/>
                      <% else %>
                        <path d="M15 12l-5 5-5-5h10z"/>
                      <% end %>
                    </svg>
                  <% end %>
                </div>
              </th>
              
              <th
                phx-click="sort"
                phx-value-field="profile_completeness_score"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Completeness</span>
                  <%= if @sort_by == "profile_completeness_score" do %>
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <%= if @sort_order == "asc" do %>
                        <path d="M5 8l5-5 5 5H5z"/>
                      <% else %>
                        <path d="M15 12l-5 5-5-5h10z"/>
                      <% end %>
                    </svg>
                  <% end %>
                </div>
              </th>
              
              <th
                phx-click="sort"
                phx-value-field="inserted_at"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Created</span>
                  <%= if @sort_by == "inserted_at" do %>
                    <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <%= if @sort_order == "asc" do %>
                        <path d="M5 8l5-5 5 5H5z"/>
                      <% else %>
                        <path d="M15 12l-5 5-5-5h10z"/>
                      <% end %>
                    </svg>
                  <% end %>
                </div>
              </th>
              
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for organization <- @organizations do %>
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4">
                  <input
                    type="checkbox"
                    checked={organization.id in @selected_organizations}
                    phx-click="select_organization"
                    phx-value-id={organization.id}
                    class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  />
                </td>
                
                <td class="px-6 py-4">
                  <div class="text-sm font-medium text-gray-900">
                    <%= organization.organization_name %>
                  </div>
                  <div class="text-sm text-gray-500">
                    Type: <%= organization.core_profile["organization_type"] || "Not specified" %>
                  </div>
                </td>
                
                <td class="px-6 py-4 text-sm text-gray-900">
                  <%= organization.email_domain %>
                </td>
                
                <td class="px-6 py-4 text-sm text-gray-900">
                  <%= organization.core_profile["industry_sector"] || "Not specified" %>
                </td>
                
                <td class="px-6 py-4">
                  <%= if organization.verified do %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Verified
                    </span>
                  <% else %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                      Unverified
                    </span>
                  <% end %>
                </td>
                
                <td class="px-6 py-4">
                  <div class="flex items-center">
                    <div class="w-16 bg-gray-200 rounded-full h-2">
                      <div
                        class="bg-blue-600 h-2 rounded-full"
                        style={"width: #{round(Decimal.to_float(organization.profile_completeness_score || 0) * 100)}%"}
                      >
                      </div>
                    </div>
                    <span class="ml-2 text-sm text-gray-600">
                      <%= round(Decimal.to_float(organization.profile_completeness_score || 0) * 100) %>%
                    </span>
                  </div>
                </td>
                
                <td class="px-6 py-4 text-sm text-gray-500">
                  <%= Calendar.strftime(organization.inserted_at, "%Y-%m-%d") %>
                </td>
                
                <td class="px-6 py-4 text-right text-sm font-medium space-x-2">
                  <.link
                    patch={~p"/admin/organizations/#{organization.id}/edit"}
                    class="text-blue-600 hover:text-blue-900"
                  >
                    Edit
                  </.link>
                  <%= if @current_user.role == :admin do %>
                    <button
                      phx-click="delete_organization"
                      phx-value-id={organization.id}
                      data-confirm="Are you sure you want to delete this organization?"
                      class="text-red-600 hover:text-red-900"
                    >
                      Delete
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        
        <%= if length(@organizations) == 0 do %>
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No organizations found</h3>
            <p class="mt-1 text-sm text-gray-500">
              <%= if @search_term != "" or @verification_filter != "all" do %>
                Try adjusting your search or filters.
              <% else %>
                Get started by creating a new organization.
              <% end %>
            </p>
          </div>
        <% end %>
      </div>
    </div>

    <!-- Organization Form Modal -->
    <%= if @show_organization_modal do %>
      <.live_component
        module={OrganizationFormComponent}
        id="organization-form"
        organization={@editing_organization}
        current_user={@current_user}
      />
    <% end %>
    """
  end
end