defmodule SertantaiWeb.Admin.Organizations.LocationsSearchLive do
  @moduledoc """
  Global location search interface for admins.
  
  Provides search-driven workflow to find organizations and their locations
  across the entire system. Primary use case is helping admins quickly locate
  and manage locations without knowing the specific organization structure.
  """
  
  use SertantaiWeb, :live_view
  
  alias Sertantai.Organizations.{Organization, OrganizationLocation}
  
  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Organization Locations Search")
      |> assign(:search_term, "")
      |> assign(:selected_organization, nil)
      |> assign(:organizations, [])
      |> assign(:locations, [])
      |> assign(:searching, false)
      |> assign(:page, 1)
      |> assign(:per_page, 20)
      |> assign(:total_locations, 0)
      |> assign(:recent_organizations, [])
    
    {:ok, load_recent_organizations(socket)}
  end
  
  @impl true
  def handle_event("search_organizations", %{"search" => ""}, socket) do
    {:noreply,
     socket
     |> assign(:search_term, "")
     |> assign(:organizations, [])
     |> assign(:selected_organization, nil)
     |> assign(:locations, [])
     |> assign(:searching, false)}
  end
  
  def handle_event("search_organizations", %{"search" => search_term}, socket) do
    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:searching, true)
     |> assign(:selected_organization, nil)
     |> assign(:locations, [])
     |> perform_organization_search()}
  end
  
  def handle_event("select_organization", %{"id" => organization_id}, socket) do
    case Ash.get(Organization, organization_id, actor: socket.assigns.current_user) do
      {:ok, organization} ->
        {:noreply,
         socket
         |> assign(:selected_organization, organization)
         |> assign(:page, 1)
         |> load_organization_locations()}
      
      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Organization not found")
         |> assign(:selected_organization, nil)
         |> assign(:locations, [])}
    end
  end
  
  def handle_event("clear_selection", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_organization, nil)
     |> assign(:locations, [])
     |> assign(:page, 1)}
  end
  
  def handle_event("page_change", %{"page" => page}, socket) do
    page = String.to_integer(page)
    {:noreply, socket |> assign(:page, page) |> load_organization_locations()}
  end
  
  def handle_event("per_page_change", %{"per_page" => per_page}, socket) do
    per_page = String.to_integer(per_page)
    {:noreply, socket |> assign(:per_page, per_page) |> assign(:page, 1) |> load_organization_locations()}
  end
  
  # Load recent organizations for quick access
  defp load_recent_organizations(socket) do
    query = Organization
      |> Ash.Query.sort(updated_at: :desc)
      |> Ash.Query.limit(5)
      |> Ash.Query.load([:locations])
    
    case Ash.read(query, actor: socket.assigns.current_user) do
      {:ok, organizations} ->
        recent_with_counts = Enum.map(organizations, fn org ->
          location_count = length(org.locations || [])
          Map.put(org, :location_count, location_count)
        end)
        
        assign(socket, :recent_organizations, recent_with_counts)
      
      {:error, _error} ->
        assign(socket, :recent_organizations, [])
    end
  end
  
  # Search for organizations based on name or domain
  defp perform_organization_search(socket) do
    search_term = socket.assigns.search_term
    
    query = Organization
      |> apply_organization_search_filter(search_term)
      |> Ash.Query.limit(10)
      |> Ash.Query.load([:locations])
    
    case Ash.read(query, actor: socket.assigns.current_user) do
      {:ok, organizations} ->
        organizations_with_counts = Enum.map(organizations, fn org ->
          location_count = length(org.locations || [])
          Map.put(org, :location_count, location_count)
        end)
        
        socket
        |> assign(:organizations, organizations_with_counts)
        |> assign(:searching, false)
      
      {:error, _error} ->
        socket
        |> assign(:organizations, [])
        |> assign(:searching, false)
        |> put_flash(:error, "Failed to search organizations")
    end
  end
  
  # Apply search filter to organization query
  defp apply_organization_search_filter(query, search_term) do
    require Ash.Query
    import Ash.Expr
    
    query
    |> Ash.Query.filter(
      expr(
        contains(organization_name, ^search_term) or
        contains(email_domain, ^search_term)
      )
    )
  end
  
  # Load locations for the selected organization
  defp load_organization_locations(socket) do
    organization = socket.assigns.selected_organization
    
    if organization do
      {query, count_query} = build_location_query(socket, organization.id)
      
      with {:ok, locations} <- Ash.read(apply_pagination(query, socket.assigns.page, socket.assigns.per_page), actor: socket.assigns.current_user),
           {:ok, total_count} <- Ash.count(count_query, actor: socket.assigns.current_user) do
        socket
        |> assign(:locations, locations)
        |> assign(:total_locations, total_count)
      else
        {:error, _} ->
          socket
          |> assign(:locations, [])
          |> assign(:total_locations, 0)
          |> put_flash(:error, "Failed to load locations")
      end
    else
      socket
      |> assign(:locations, [])
      |> assign(:total_locations, 0)
    end
  end
  
  # Build location query for the selected organization
  defp build_location_query(_socket, organization_id) do
    query = OrganizationLocation
      |> apply_organization_filter(organization_id)
      |> Ash.Query.sort(location_name: :asc)
    
    count_query = OrganizationLocation
      |> apply_organization_filter(organization_id)
    
    {query, count_query}
  end
  
  # Apply organization filter to location query
  defp apply_organization_filter(query, organization_id) do
    require Ash.Query
    import Ash.Expr
    
    query |> Ash.Query.filter(expr(organization_id == ^organization_id))
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
      end: min(assigns.page * assigns.per_page, assigns.total_locations),
      total: assigns.total_locations
    }
  end
  
  # Calculate total pages
  defp total_pages(assigns) do
    ceil(assigns.total_locations / assigns.per_page)
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
          <li class="text-gray-900 font-medium">
            Organization Locations
          </li>
        </ol>
      </nav>
      
      <!-- Header -->
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Organization Locations</h1>
          <p class="mt-2 text-sm text-gray-700">
            Search for organizations and manage their locations across the entire system.
          </p>
        </div>
      </div>
      
      <!-- Organization Search -->
      <div class="bg-white p-6 rounded-lg shadow">
        <div class="space-y-4">
          <div>
            <label for="org-search" class="block text-sm font-medium text-gray-700 mb-2">
              Search Organizations
            </label>
            <div class="relative">
              <input
                id="org-search"
                type="text"
                value={@search_term}
                phx-change="search_organizations"
                name="search"
                placeholder="Search by organization name or email domain..."
                class="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-md shadow-sm focus:border-blue-500 focus:ring-blue-500"
              />
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              </div>
            </div>
          </div>
          
          <%= if @searching do %>
            <div class="flex items-center justify-center py-4">
              <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
              <span class="ml-2 text-sm text-gray-600">Searching...</span>
            </div>
          <% end %>
          
          <!-- Search Results -->
          <%= if length(@organizations) > 0 do %>
            <div class="space-y-2">
              <h3 class="text-sm font-medium text-gray-700">Search Results</h3>
              <div class="grid gap-3">
                <%= for org <- @organizations do %>
                  <div class="border border-gray-200 rounded-lg p-4 hover:border-blue-300 transition-colors cursor-pointer"
                       phx-click="select_organization" phx-value-id={org.id}>
                    <div class="flex items-center justify-between">
                      <div>
                        <h4 class="text-sm font-medium text-gray-900"><%= org.organization_name %></h4>
                        <p class="text-sm text-gray-500"><%= org.email_domain %></p>
                      </div>
                      <div class="text-right">
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                          <%= org.location_count %> location<%= if org.location_count != 1, do: "s" %>
                        </span>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
          
          <!-- Recent Organizations (shown when no search) -->
          <%= if @search_term == "" and length(@recent_organizations) > 0 do %>
            <div class="space-y-2">
              <h3 class="text-sm font-medium text-gray-700">Recent Organizations</h3>
              <div class="grid gap-3">
                <%= for org <- @recent_organizations do %>
                  <div class="border border-gray-200 rounded-lg p-4 hover:border-blue-300 transition-colors cursor-pointer"
                       phx-click="select_organization" phx-value-id={org.id}>
                    <div class="flex items-center justify-between">
                      <div>
                        <h4 class="text-sm font-medium text-gray-900"><%= org.organization_name %></h4>
                        <p class="text-sm text-gray-500"><%= org.email_domain %></p>
                      </div>
                      <div class="text-right">
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                          <%= org.location_count %> location<%= if org.location_count != 1, do: "s" %>
                        </span>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
      
      <!-- Selected Organization Locations -->
      <%= if @selected_organization do %>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-200">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-lg font-medium text-gray-900">
                  Locations for <%= @selected_organization.organization_name %>
                </h3>
                <p class="text-sm text-gray-500">
                  <%= @total_locations %> location<%= if @total_locations != 1, do: "s" %> total
                </p>
              </div>
              <div class="flex space-x-2">
                <.link
                  patch={~p"/admin/organizations/#{@selected_organization.id}/locations"}
                  class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Manage All
                </.link>
                <button
                  phx-click="clear_selection"
                  class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Clear
                </button>
              </div>
            </div>
          </div>
          
          <%= if length(@locations) > 0 do %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Location
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Type
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Region
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Status
                    </th>
                    <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for location <- @locations do %>
                    <tr class="hover:bg-gray-50">
                      <td class="px-6 py-4 whitespace-nowrap">
                        <div class="text-sm font-medium text-gray-900">
                          <%= location.location_name %>
                          <%= if location.is_primary_location do %>
                            <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                              Primary
                            </span>
                          <% end %>
                        </div>
                        <%= if location.postcode do %>
                          <div class="text-sm text-gray-500"><%= location.postcode %></div>
                        <% end %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <%= humanize_atom(location.location_type) %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <%= humanize_atom(location.geographic_region) %>
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
                      <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                        <.link
                          patch={~p"/admin/organizations/#{@selected_organization.id}/locations/#{location.id}/edit"}
                          class="text-blue-600 hover:text-blue-900 mr-3"
                        >
                          Edit
                        </.link>
                        <.link
                          patch={~p"/admin/organizations/#{@selected_organization.id}"}
                          class="text-gray-600 hover:text-gray-900"
                        >
                          View Org
                        </.link>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
            
            <!-- Pagination for locations -->
            <%= if @total_locations > @per_page do %>
              <div class="bg-white px-4 py-3 flex items-center justify-between border-t border-gray-200 sm:px-6">
                <div class="flex-1 flex justify-between sm:hidden">
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
                        <option value="20">20</option>
                        <option value="50">50</option>
                      </select>
                    </div>
                    
                    <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px">
                      <button
                        phx-click="page_change"
                        phx-value-page={@page - 1}
                        disabled={@page <= 1}
                        class={"relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 #{if @page <= 1, do: "cursor-not-allowed opacity-50"}"}
                      >
                        Previous
                      </button>
                      
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
          <% else %>
            <div class="text-center py-12">
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-gray-900">No locations found</h3>
              <p class="mt-1 text-sm text-gray-500">
                This organization doesn't have any locations yet.
              </p>
              <%= if @current_user.role == :admin do %>
                <div class="mt-6">
                  <.link
                    patch={~p"/admin/organizations/#{@selected_organization.id}/locations/new"}
                    class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    Add First Location
                  </.link>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end