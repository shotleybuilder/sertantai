defmodule SertantaiWeb.Admin.Organizations.OrganizationLocationsLive do
  @moduledoc """
  Admin interface for managing locations within a specific organization.
  
  Provides comprehensive location CRUD operations with context-aware
  navigation and proper admin authorization.
  """
  
  use SertantaiWeb, :live_view
  
  alias Sertantai.Organizations.{Organization, OrganizationLocation}
  alias SertantaiWeb.Admin.Organizations.LocationFormComponent
  
  @impl true
  def mount(%{"id" => organization_id}, _session, socket) do
    socket = 
      socket
      |> assign(:organization_id, organization_id)
      |> assign(:search_term, "")
      |> assign(:sort_by, "location_name")
      |> assign(:sort_order, "asc")
      |> assign(:selected_locations, [])
      |> assign(:show_location_modal, false)
      |> assign(:editing_location, nil)
      |> assign(:page, 1)
      |> assign(:per_page, 25)
      |> assign(:total_count, 0)
    
    case load_organization_and_locations(socket) do
      {:ok, socket} ->
        {:ok, socket}
      {:error, socket} ->
        {:ok, socket}
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
    |> assign(:show_location_modal, true)
    |> assign(:editing_location, nil)
  end
  
  defp apply_action(socket, :edit, %{"location_id" => location_id}) do
    case Ash.get(OrganizationLocation, location_id, actor: socket.assigns.current_user) do
      {:ok, location} ->
        socket
        |> assign(:show_location_modal, true)
        |> assign(:editing_location, location)
      
      {:error, _error} ->
        socket
        |> put_flash(:error, "Location not found")
        |> assign(:show_location_modal, false)
        |> assign(:editing_location, nil)
    end
  end
  
  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:show_location_modal, false)
    |> assign(:editing_location, nil)
  end
  
  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:page, 1)
     |> assign(:selected_locations, [])
     |> load_locations()}
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
     |> load_locations()}
  end
  
  def handle_event("select_location", %{"id" => id}, socket) do
    selected = socket.assigns.selected_locations
    new_selected = 
      if id in selected do
        List.delete(selected, id)
      else
        [id | selected]
      end
    
    {:noreply, assign(socket, :selected_locations, new_selected)}
  end
  
  def handle_event("select_all", _params, socket) do
    all_ids = Enum.map(socket.assigns.locations, & &1.id)
    {:noreply, assign(socket, :selected_locations, all_ids)}
  end
  
  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_locations, [])}
  end
  
  def handle_event("page_change", %{"page" => page}, socket) do
    page = String.to_integer(page)
    {:noreply, socket |> assign(:page, page) |> load_locations()}
  end
  
  def handle_event("per_page_change", %{"per_page" => per_page}, socket) do
    per_page = String.to_integer(per_page)
    {:noreply, socket |> assign(:per_page, per_page) |> assign(:page, 1) |> load_locations()}
  end
  
  def handle_event("delete_location", %{"id" => id}, socket) do
    if socket.assigns.current_user.role == :admin do
      case Ash.get(OrganizationLocation, id, actor: socket.assigns.current_user) do
        {:ok, location} ->
          case Ash.destroy(location, actor: socket.assigns.current_user) do
            :ok ->
              {:noreply,
               socket
               |> put_flash(:info, "Location deleted successfully")
               |> load_locations()}
            
            {:error, _error} ->
              {:noreply, put_flash(socket, :error, "Failed to delete location")}
          end
        
        {:error, _error} ->
          {:noreply, put_flash(socket, :error, "Location not found")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only admins can delete locations")}
    end
  end
  
  @impl true
  def handle_info({:location_created, message}, socket) do
    {:noreply,
     socket
     |> assign(:show_location_modal, false)
     |> put_flash(:info, message)
     |> load_locations()}
  end
  
  def handle_info({:location_updated, message}, socket) do
    redirect_path = socket.assigns[:return_to] || ~p"/admin/organizations/#{socket.assigns.organization_id}/locations"
    
    {:noreply,
     socket
     |> assign(:show_location_modal, false)
     |> put_flash(:info, message)
     |> load_locations()
     |> push_navigate(to: redirect_path)}
  end
  
  def handle_info({:close_modal}, socket) do
    redirect_path = socket.assigns[:return_to] || ~p"/admin/organizations/#{socket.assigns.organization_id}/locations"
    
    {:noreply,
     socket
     |> assign(:show_location_modal, false)
     |> push_navigate(to: redirect_path)}
  end
  
  # Load organization and its locations
  defp load_organization_and_locations(socket) do
    organization_id = socket.assigns.organization_id
    
    case Ash.get(Organization, organization_id, actor: socket.assigns.current_user) do
      {:ok, organization} ->
        socket = 
          socket
          |> assign(:organization, organization)
          |> assign(:page_title, "Manage Locations - #{organization.organization_name}")
          |> load_locations()
        
        {:ok, socket}
      
      {:error, _error} ->
        socket = 
          socket
          |> put_flash(:error, "Organization not found")
          |> redirect(to: ~p"/admin/organizations")
        
        {:error, socket}
    end
  end
  
  # Load locations with server-side filtering, sorting, and pagination
  defp load_locations(socket) do
    {query, count_query} = build_location_query(socket)
    
    with {:ok, locations} <- Ash.read(apply_pagination(query, socket.assigns.page, socket.assigns.per_page), actor: socket.assigns.current_user),
         {:ok, total_count} <- Ash.count(count_query, actor: socket.assigns.current_user) do
      socket
      |> assign(:locations, locations)
      |> assign(:total_count, total_count)
    else
      {:error, _} ->
        socket
        |> assign(:locations, [])
        |> assign(:total_count, 0)
        |> put_flash(:error, "Failed to load locations")
    end
  end
  
  # Build location query with filters and sorting
  defp build_location_query(socket) do
    query = OrganizationLocation
      |> apply_organization_filter(socket.assigns.organization_id)
      |> apply_search_filter(socket.assigns.search_term)
      |> apply_sorting(socket.assigns.sort_by, socket.assigns.sort_order)
    
    count_query = OrganizationLocation
      |> apply_organization_filter(socket.assigns.organization_id)
      |> apply_search_filter(socket.assigns.search_term)
    
    {query, count_query}
  end
  
  # Apply organization filter to query
  defp apply_organization_filter(query, organization_id) do
    require Ash.Query
    import Ash.Expr
    
    query |> Ash.Query.filter(expr(organization_id == ^organization_id))
  end
  
  # Apply search filter to query
  defp apply_search_filter(query, ""), do: query
  defp apply_search_filter(query, search_term) do
    require Ash.Query
    import Ash.Expr
    
    query
    |> Ash.Query.filter(
      expr(
        contains(location_name, ^search_term) or
        contains(postcode, ^search_term) or
        contains(geographic_region, ^search_term)
      )
    )
  end
  
  # Apply sorting to query
  defp apply_sorting(query, sort_by, sort_order) do
    require Ash.Query
    
    sort_order_atom = if sort_order == "desc", do: :desc, else: :asc
    
    case sort_by do
      "location_name" ->
        query |> Ash.Query.sort(location_name: sort_order_atom)
      "location_type" ->
        query |> Ash.Query.sort(location_type: sort_order_atom)
      "geographic_region" ->
        query |> Ash.Query.sort(geographic_region: sort_order_atom)
      "operational_status" ->
        query |> Ash.Query.sort(operational_status: sort_order_atom)
      "employee_count" ->
        query |> Ash.Query.sort(employee_count: sort_order_atom)
      "inserted_at" ->
        query |> Ash.Query.sort(inserted_at: sort_order_atom)
      _ ->
        query |> Ash.Query.sort(location_name: :asc)
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
  
  # Helper to humanize atom values
  defp humanize_atom(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> humanize_string()
  end
  
  defp humanize_atom(string) when is_binary(string) do
    humanize_string(string)
  end
  
  defp humanize_atom(nil), do: "Not specified"
  
  defp humanize_string(string) do
    string
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
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
              Admin Dashboard
            </.link>
          </li>
          <li>
            <svg class="h-4 w-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </li>
          <li>
            <.link
              patch={~p"/admin/organizations"}
              class="text-gray-400 hover:text-gray-600 transition-colors duration-200"
            >
              Organizations
            </.link>
          </li>
          <li>
            <svg class="h-4 w-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </li>
          <li>
            <.link
              patch={~p"/admin/organizations/#{@organization_id}"}
              class="text-gray-400 hover:text-gray-600 transition-colors duration-200"
            >
              <%= @organization.organization_name %>
            </.link>
          </li>
          <li>
            <svg class="h-4 w-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </li>
          <li class="text-gray-900 font-medium">
            Location Management
          </li>
        </ol>
      </nav>
      
      <!-- Header -->
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Location Management</h1>
          <p class="mt-2 text-sm text-gray-700">
            Manage locations for <strong><%= @organization.organization_name %></strong>
          </p>
        </div>
        <%= if @current_user.role == :admin do %>
          <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
            <.link
              patch={~p"/admin/organizations/#{@organization_id}/locations/new"}
              class="inline-flex items-center justify-center rounded-md border border-transparent bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 sm:w-auto"
            >
              New Location
            </.link>
          </div>
        <% end %>
      </div>

      <!-- Search and Filters -->
      <div class="bg-white p-4 rounded-lg shadow space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- Search -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
            <input
              type="text"
              value={@search_term}
              phx-change="search"
              name="search"
              placeholder="Search by name, postcode, or region..."
              class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            />
          </div>

          <!-- Results Info -->
          <div class="flex items-center justify-between">
            <span class="text-sm text-gray-500">
              <%= @total_count %> location(s) total
            </span>
            <%= if length(@selected_locations) > 0 do %>
              <span class="text-sm font-medium text-blue-600">
                <%= length(@selected_locations) %> selected
              </span>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Bulk Actions -->
      <%= if length(@selected_locations) > 0 do %>
        <div class="bg-blue-50 p-4 rounded-lg border border-blue-200">
          <div class="flex items-center justify-between">
            <span class="text-sm font-medium text-blue-800">
              <%= length(@selected_locations) %> location(s) selected
            </span>
            <div class="flex space-x-2">
              <%= if length(@selected_locations) == 1 do %>
                <%
                  selected_location = Enum.find(@locations, fn loc -> loc.id in @selected_locations end)
                %>
                <%= if selected_location do %>
                  <.link
                    patch={~p"/admin/organizations/#{@organization_id}/locations/#{selected_location.id}/edit"}
                    class="inline-flex items-center px-3 py-1.5 border border-blue-300 text-xs font-medium rounded text-blue-700 bg-blue-50 hover:bg-blue-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    <svg class="mr-1 h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                    Edit Location
                  </.link>
                <% end %>
              <% end %>
              <%= if @current_user.role == :admin do %>
                <button
                  phx-click="bulk_delete"
                  data-confirm="Are you sure you want to delete the selected locations?"
                  class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded text-red-700 bg-red-100 hover:bg-red-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                >
                  <svg class="mr-1 h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                  Delete Selected
                </button>
              <% end %>
              <button
                phx-click="clear_selection"
                class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <svg class="mr-1 h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
                Clear Selection
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Mobile scroll notice -->
      <div class="bg-blue-50 p-3 rounded-lg border border-blue-200 md:hidden mb-4">
        <p class="text-sm text-blue-800">
          💡 Swipe horizontally to see all columns
        </p>
      </div>

      <!-- Locations Table -->
      <div class="bg-white shadow rounded-lg overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200" style="min-width: 1000px;">
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
                phx-value-field="location_name"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Location</span>
                  <%= if @sort_by == "location_name" do %>
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
                phx-value-field="location_type"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Type</span>
                  <%= if @sort_by == "location_type" do %>
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
                phx-value-field="geographic_region"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Region</span>
                  <%= if @sort_by == "geographic_region" do %>
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
                Postcode
              </th>
              
              <th
                phx-click="sort"
                phx-value-field="operational_status"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Status</span>
                  <%= if @sort_by == "operational_status" do %>
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
                phx-value-field="employee_count"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Employees</span>
                  <%= if @sort_by == "employee_count" do %>
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
            <%= for location <- @locations do %>
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4">
                  <input
                    type="checkbox"
                    checked={location.id in @selected_locations}
                    phx-click="select_location"
                    phx-value-id={location.id}
                    class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  />
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <div>
                      <div class="text-sm font-medium">
                        <.link
                          patch={~p"/admin/organizations/#{@organization_id}/locations/#{location.id}/edit"}
                          class="text-blue-600 hover:text-blue-900 hover:underline"
                        >
                          <%= location.location_name %>
                        </.link>
                        <%= if location.is_primary_location do %>
                          <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            Primary
                          </span>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <%= humanize_atom(location.location_type) %>
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <%= humanize_atom(location.geographic_region) %>
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <%= location.postcode || "Not specified" %>
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium " <> 
                    case location.operational_status do
                      :active -> "bg-green-100 text-green-800"
                      :inactive -> "bg-red-100 text-red-800"
                      :seasonal -> "bg-yellow-100 text-yellow-800"
                      _ -> "bg-gray-100 text-gray-800"
                    end}>
                    <%= humanize_atom(location.operational_status) %>
                  </span>
                </td>
                
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  <%= location.employee_count || "Not specified" %>
                </td>
                
              </tr>
            <% end %>
          </tbody>
        </table>
        
        <%= if length(@locations) == 0 do %>
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No locations found</h3>
            <p class="mt-1 text-sm text-gray-500">
              <%= if @search_term != "" do %>
                Try adjusting your search terms.
              <% else %>
                This organization doesn't have any locations yet.
              <% end %>
            </p>
            <%= if @current_user.role == :admin do %>
              <div class="mt-6">
                <.link
                  patch={~p"/admin/organizations/#{@organization_id}/locations/new"}
                  class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Add First Location
                </.link>
              </div>
            <% end %>
          </div>
        <% end %>
        </div>
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
                <span class="font-medium"><%= info.total %></span> locations
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

    <!-- Location Form Modal -->
    <%= if @show_location_modal do %>
      <.live_component
        module={LocationFormComponent}
        id="location-form"
        location={@editing_location}
        organization={@organization}
        current_user={@current_user}
      />
    <% end %>
    """
  end
end