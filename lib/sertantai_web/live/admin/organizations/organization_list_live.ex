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
    socket =
      socket
      |> assign(:current_path, "/admin/organizations")
      |> assign(:search_term, "")
      |> assign(:status_filter, "all")
      |> assign(:verification_filter, "all")
      |> assign(:sort_by, "organization_name")
      |> assign(:sort_order, "asc")
      |> assign(:selected_organizations, [])
      |> assign(:show_organization_modal, false)
      |> assign(:editing_organization, nil)
      |> assign(:page, 1)
      |> assign(:per_page, 25)
      |> assign(:total_count, 0)
    
    {:ok, load_organizations(socket)}
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
    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:page, 1)
     |> assign(:selected_organizations, [])
     |> load_organizations()}
  end
  
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:status_filter, status)
     |> assign(:page, 1)
     |> assign(:selected_organizations, [])
     |> load_organizations()}
  end
  
  def handle_event("filter_verification", %{"verification" => verification}, socket) do
    {:noreply,
     socket
     |> assign(:verification_filter, verification)
     |> assign(:page, 1)
     |> assign(:selected_organizations, [])
     |> load_organizations()}
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
     |> assign(:page, 1)
     |> load_organizations()}
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
  
  def handle_event("page_change", %{"page" => page}, socket) do
    page = String.to_integer(page)
    {:noreply, socket |> assign(:page, page) |> load_organizations()}
  end
  
  def handle_event("per_page_change", %{"per_page" => per_page}, socket) do
    per_page = String.to_integer(per_page)
    {:noreply, socket |> assign(:per_page, per_page) |> assign(:page, 1) |> load_organizations()}
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
    {:noreply,
     socket
     |> assign(:selected_organizations, [])
     |> put_flash(:info, "Organizations verified successfully")
     |> load_organizations()}
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
      {:noreply,
       socket
       |> assign(:selected_organizations, [])
       |> put_flash(:info, "Organizations deleted successfully")
       |> load_organizations()}
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
              {:noreply,
               socket
               |> put_flash(:info, "Organization deleted successfully")
               |> load_organizations()}
            
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
    {:noreply,
     socket
     |> assign(:show_organization_modal, false)
     |> put_flash(:info, message)
     |> load_organizations()}
  end
  
  def handle_info({:organization_updated, message}, socket) do
    # Determine where to redirect after update
    redirect_path = socket.assigns[:return_to] || ~p"/admin/organizations"
    
    # Reload organizations
    {:noreply,
     socket
     |> assign(:show_organization_modal, false)
     |> put_flash(:info, message)
     |> load_organizations()
     |> push_navigate(to: redirect_path)}
  end
  
  def handle_info({:close_modal}, socket) do
    # Determine where to redirect after closing modal
    redirect_path = socket.assigns[:return_to] || ~p"/admin/organizations"
    
    {:noreply,
     socket
     |> assign(:show_organization_modal, false)
     |> push_navigate(to: redirect_path)}
  end
  
  # Load organizations with server-side filtering, sorting, and pagination
  defp load_organizations(socket) do
    {query, count_query} = build_organization_query(socket)
    
    with {:ok, organizations} <- Ash.read(apply_pagination(query, socket.assigns.page, socket.assigns.per_page), actor: socket.assigns.current_user),
         {:ok, total_count} <- Ash.count(count_query, actor: socket.assigns.current_user) do
      socket
      |> assign(:organizations, organizations)
      |> assign(:total_count, total_count)
    else
      {:error, _} ->
        socket
        |> assign(:organizations, [])
        |> assign(:total_count, 0)
        |> put_flash(:error, "Failed to load organizations")
    end
  end
  
  # Build organization query with filters and sorting
  defp build_organization_query(socket) do
    query = Organization
      |> apply_search_filter(socket.assigns.search_term)
      |> apply_verification_filter(socket.assigns.verification_filter)
      |> apply_sorting(socket.assigns.sort_by, socket.assigns.sort_order)
    
    count_query = Organization
      |> apply_search_filter(socket.assigns.search_term)
      |> apply_verification_filter(socket.assigns.verification_filter)
    
    {query, count_query}
  end
  
  # Apply search filter to query
  defp apply_search_filter(query, ""), do: query
  defp apply_search_filter(query, search_term) do
    require Ash.Query
    import Ash.Expr
    
    query
    |> Ash.Query.filter(
      expr(
        contains(organization_name, ^search_term) or
        contains(email_domain, ^search_term) or
        contains(fragment("(?->>'industry_sector')", core_profile), ^search_term)
      )
    )
  end
  
  # Apply verification filter to query
  defp apply_verification_filter(query, "all"), do: query
  defp apply_verification_filter(query, "verified") do
    require Ash.Query
    import Ash.Expr
    
    query |> Ash.Query.filter(expr(verified == true))
  end
  defp apply_verification_filter(query, "unverified") do
    require Ash.Query
    import Ash.Expr
    
    query |> Ash.Query.filter(expr(verified == false))
  end
  
  # Apply sorting to query
  defp apply_sorting(query, sort_by, sort_order) do
    require Ash.Query
    
    sort_order_atom = if sort_order == "desc", do: :desc, else: :asc
    
    case sort_by do
      "organization_name" ->
        query |> Ash.Query.sort(organization_name: sort_order_atom)
      "email_domain" ->
        query |> Ash.Query.sort(email_domain: sort_order_atom)
      "verified" ->
        query |> Ash.Query.sort(verified: sort_order_atom)
      "inserted_at" ->
        query |> Ash.Query.sort(inserted_at: sort_order_atom)
      "profile_completeness_score" ->
        query |> Ash.Query.sort(profile_completeness_score: sort_order_atom)
      "organization_type" ->
        # Sort by organization type in core_profile - for now, sort by organization name
        # TODO: Implement proper JSON field sorting when Ash supports it better
        query |> Ash.Query.sort(organization_name: sort_order_atom)
      _ ->
        query |> Ash.Query.sort(organization_name: :asc)
    end
  end
  
  # Apply pagination to query
  defp apply_pagination(query, page, per_page) do
    require Ash.Query
    
    offset = (page - 1) * per_page
    query
    |> Ash.Query.limit(per_page)
    |> Ash.Query.offset(offset)
  end
  
  # Helper function for pagination display
  defp pagination_info(assigns) do
    %{
      start: (assigns.page - 1) * assigns.per_page + 1,
      end: min(assigns.page * assigns.per_page, assigns.total_count),
      total: assigns.total_count
    }
  end
  
  # Calculate total pages
  defp total_pages(assigns) do
    ceil(assigns.total_count / assigns.per_page)
  end
  
  # Generate page numbers for pagination
  defp pagination_pages(current_page, total_pages) do
    start_page = max(1, current_page - 2)
    end_page = min(total_pages, current_page + 2)
    
    start_page..end_page |> Enum.to_list()
  end
  
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto">
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
      <div class="bg-white shadow rounded-lg mb-6">
        <div class="px-6 py-4 border-b border-gray-200">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">Organization Management</h1>
              <p class="text-sm text-gray-600 mt-1">
                Manage organizations, their verification status, and profile information.
              </p>
            </div>
            <%= if @current_user.role == :admin do %>
              <div class="flex-shrink-0">
                <.link
                  patch={~p"/admin/organizations/new"}
                  class="inline-flex items-center justify-center rounded-md border border-transparent bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                >
                  New Organization
                </.link>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Search and Filter Controls -->
        <div class="px-6 py-4 bg-gray-50">
          <div class="flex flex-col space-y-4 sm:flex-row sm:items-center sm:space-y-0 sm:space-x-4">
            <!-- Search -->
            <div class="flex-1 min-w-0">
              <form phx-submit="search">
                <div class="relative">
                  <input
                    type="text"
                    name="search"
                    value={@search_term}
                    placeholder="Search by name, domain, or industry..."
                    class="block w-full rounded-md border-gray-300 pl-10 focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                    phx-change="search"
                  />
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                    </svg>
                  </div>
                </div>
              </form>
            </div>

            <!-- Verification Filter -->
            <div class="flex-shrink-0">
              <select
                phx-change="filter_verification"
                name="verification"
                value={@verification_filter}
                class="block w-full rounded-md border-gray-300 py-2 pl-3 pr-10 text-base focus:border-blue-500 focus:outline-none focus:ring-blue-500 sm:text-sm"
              >
                <option value="all">All Organizations</option>
                <option value="verified">Verified Only</option>
                <option value="unverified">Unverified Only</option>
              </select>
            </div>

            <!-- Results Info -->
            <div class="flex-shrink-0 text-sm text-gray-500">
              <%= @total_count %> organization(s) total
              <%= if length(@selected_organizations) > 0 do %>
                · <span class="font-medium text-blue-600"><%= length(@selected_organizations) %> selected</span>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Bulk Actions -->
        <%= if length(@selected_organizations) > 0 do %>
          <div class="px-6 py-3 bg-blue-50 border-t border-gray-200">
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
      </div>

      <!-- Organizations Table -->
      <div class="bg-white shadow overflow-hidden rounded-lg">
        <!-- Mobile scroll notice -->
        <div class="px-6 py-3 bg-blue-50 border-b border-gray-200 md:hidden">
          <p class="text-sm text-blue-800">
            💡 Swipe horizontally to see all columns
          </p>
        </div>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200" style="min-width: 1200px;">
          <thead class="bg-gray-50">
            <tr>
              <th class="w-8 px-6 py-3">
                <input
                  type="checkbox"
                  phx-click="select_all"
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
              </th>
              
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Locations
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
                phx-value-field="organization_type"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Type</span>
                  <%= if @sort_by == "organization_type" do %>
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
                
                <td class="px-6 py-4 text-left text-sm font-medium">
                  <.link
                    navigate={~p"/admin/organizations/#{organization.id}/locations"}
                    class="text-indigo-600 hover:text-indigo-900"
                  >
                    Manage
                  </.link>
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap">
                  <.link
                    patch={~p"/admin/organizations/#{organization.id}/edit?return_to=#{URI.encode("/admin/organizations")}"}
                    class="text-blue-600 hover:text-blue-800 font-medium"
                  >
                    <%= organization.organization_name %>
                  </.link>
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <%= organization.core_profile["organization_type"] || "Not specified" %>
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
        
        <!-- Pagination Controls -->
        <%= if @total_count > 0 do %>
          <div class="bg-white px-4 py-3 flex items-center justify-between border-t border-gray-200 sm:px-6">
            <div class="flex-1 flex justify-between sm:hidden">
            <!-- Mobile pagination -->
            <button
              phx-click="page_change"
              phx-value-page={@page - 1}
              disabled={@page <= 1}
              class={"relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 #{if @page <= 1, do: "cursor-not-allowed opacity-50"}"}
            >
              Previous
            </button>
            <button
              phx-click="page_change"
              phx-value-page={@page + 1}
              disabled={@page >= total_pages(assigns)}
              class={"ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 #{if @page >= total_pages(assigns), do: "cursor-not-allowed opacity-50"}"}
            >
              Next
            </button>
          </div>
          
          <div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
            <div>
              <%
                info = pagination_info(assigns)
              %>
              <p class="text-sm text-gray-700">
                Showing <span class="font-medium"><%= info.start %></span> to 
                <span class="font-medium"><%= info.end %></span> of 
                <span class="font-medium"><%= info.total %></span> organizations
              </p>
            </div>
            
            <div class="flex items-center space-x-4">
              <div class="flex items-center space-x-2">
                <label class="text-sm text-gray-700">Show:</label>
                <select phx-change="per_page_change" name="per_page" value={@per_page} class="rounded-md border-gray-300 text-sm">
                  <option value="10">10</option>
                  <option value="25">25</option>
                  <option value="50">50</option>
                  <option value="100">100</option>
                </select>
              </div>
              
              <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px">
                <!-- Previous button -->
                <button
                  phx-click="page_change"
                  phx-value-page={@page - 1}
                  disabled={@page <= 1}
                  class={"relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 #{if @page <= 1, do: "cursor-not-allowed opacity-50"}"}
                >
                  Previous
                </button>
                
                <!-- Page numbers -->
                <%= for page_num <- pagination_pages(@page, total_pages(assigns)) do %>
                  <button
                    phx-click="page_change"
                    phx-value-page={page_num}
                    class={
                      if page_num == @page do
                        "bg-blue-50 border-blue-500 text-blue-600 relative inline-flex items-center px-4 py-2 border text-sm font-medium"
                      else
                        "bg-white border-gray-300 text-gray-500 hover:bg-gray-50 relative inline-flex items-center px-4 py-2 border text-sm font-medium"
                      end
                    }
                  >
                    <%= page_num %>
                  </button>
                <% end %>
                
                <!-- Next button -->
                <button
                  phx-click="page_change"
                  phx-value-page={@page + 1}
                  disabled={@page >= total_pages(assigns)}
                  class={"relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 #{if @page >= total_pages(assigns), do: "cursor-not-allowed opacity-50"}"}
                >
                  Next
                </button>
              </nav>
            </div>
          </div>
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