defmodule SertantaiWeb.Admin.Organizations.OrganizationDetailLive do
  @moduledoc """
  Organization detail view for admin users.
  
  Shows comprehensive organization information including locations,
  users, and analytics with management capabilities.
  """
  
  use SertantaiWeb, :live_view
  
  alias Sertantai.Organizations.{Organization, OrganizationLocation}
  alias SertantaiWeb.Admin.Organizations.LocationFormComponent
  
  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case load_organization_with_details(id, socket.assigns.current_user) do
      {:ok, {organization, locations, users}} ->
        {:ok,
         socket
         |> assign(:organization, organization)
         |> assign(:locations, locations)
         |> assign(:organization_users, users)
         |> assign(:show_location_modal, false)
         |> assign(:editing_location, nil)
         |> assign(:selected_tab, "overview")}
      
      {:error, _error} ->
        {:ok,
         socket
         |> put_flash(:error, "Organization not found")
         |> push_navigate(to: ~p"/admin/organizations")}
    end
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end
  
  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:show_location_modal, false)
    |> assign(:editing_location, nil)
  end
  
  defp apply_action(socket, :new_location, _params) do
    socket
    |> assign(:show_location_modal, true)
    |> assign(:editing_location, nil)
  end
  
  defp apply_action(socket, :edit_location, %{"location_id" => location_id}) do
    case Enum.find(socket.assigns.locations, &(&1.id == location_id)) do
      nil ->
        socket
        |> put_flash(:error, "Location not found")
        |> assign(:show_location_modal, false)
        |> assign(:editing_location, nil)
      
      location ->
        socket
        |> assign(:show_location_modal, true)
        |> assign(:editing_location, location)
    end
  end
  
  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :selected_tab, tab)}
  end
  
  def handle_event("toggle_verification", _params, socket) do
    if socket.assigns.current_user.role == :admin do
      organization = socket.assigns.organization
      new_status = !organization.verified
      
      case Ash.update(organization, %{verified: new_status}, actor: socket.assigns.current_user) do
        {:ok, updated_organization} ->
          message = if new_status, do: "Organization verified", else: "Organization unverified"
          
          {:noreply,
           socket
           |> assign(:organization, updated_organization)
           |> put_flash(:info, message)}
        
        {:error, _error} ->
          {:noreply, put_flash(socket, :error, "Failed to update verification status")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only admins can change verification status")}
    end
  end
  
  def handle_event("delete_location", %{"id" => location_id}, socket) do
    if socket.assigns.current_user.role == :admin do
      case Enum.find(socket.assigns.locations, &(&1.id == location_id)) do
        nil ->
          {:noreply, put_flash(socket, :error, "Location not found")}
        
        location ->
          case Ash.destroy(location, actor: socket.assigns.current_user) do
            :ok ->
              # Reload locations
              updated_locations = Enum.reject(socket.assigns.locations, &(&1.id == location_id))
              
              {:noreply,
               socket
               |> assign(:locations, updated_locations)
               |> put_flash(:info, "Location deleted successfully")}
            
            {:error, _error} ->
              {:noreply, put_flash(socket, :error, "Failed to delete location")}
          end
      end
    else
      {:noreply, put_flash(socket, :error, "Only admins can delete locations")}
    end
  end
  
  @impl true
  def handle_info({:location_created, message}, socket) do
    # Reload locations
    case load_organization_with_details(socket.assigns.organization.id, socket.assigns.current_user) do
      {:ok, {organization, locations, users}} ->
        {:noreply,
         socket
         |> assign(:organization, organization)
         |> assign(:locations, locations)
         |> assign(:organization_users, users)
         |> assign(:show_location_modal, false)
         |> put_flash(:info, message)}
      
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to reload organization data")}
    end
  end
  
  def handle_info({:location_updated, message}, socket) do
    # Reload locations
    case load_organization_with_details(socket.assigns.organization.id, socket.assigns.current_user) do
      {:ok, {organization, locations, users}} ->
        {:noreply,
         socket
         |> assign(:organization, organization)
         |> assign(:locations, locations)
         |> assign(:organization_users, users)
         |> assign(:show_location_modal, false)
         |> put_flash(:info, message)}
      
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to reload organization data")}
    end
  end
  
  def handle_info({:close_modal}, socket) do
    {:noreply,
     socket
     |> assign(:show_location_modal, false)
     |> push_patch(to: ~p"/admin/organizations/#{socket.assigns.organization.id}")}
  end
  
  # Helper function to load organization with all related data
  defp load_organization_with_details(id, current_user) do
    with {:ok, organization} <- Ash.get(Organization, id, actor: current_user, load: [:locations, :total_locations, :is_multi_location]) do
      # Load locations separately for better control
      locations_result = Ash.read(OrganizationLocation, 
        filter: [organization_id: id], 
        actor: current_user,
        sort: [is_primary_location: :desc, location_name: :asc]
      )
      
      # Load organization users (this would need a relationship or separate query)
      # For now, we'll use an empty list - this can be implemented when user-organization relationships are added
      users = []
      
      case locations_result do
        {:ok, locations} ->
          {:ok, {organization, locations, users}}
        
        {:error, error} ->
          {:error, error}
      end
    end
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Header -->
      <div class="bg-white shadow">
        <div class="px-4 sm:px-6 lg:px-8">
          <div class="py-6">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-4">
                <.link
                  navigate={~p"/admin/organizations"}
                  class="text-gray-500 hover:text-gray-700"
                >
                  <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                  </svg>
                </.link>
                
                <div>
                  <h1 class="text-2xl font-bold text-gray-900">
                    <%= @organization.organization_name %>
                  </h1>
                  <p class="text-sm text-gray-500">
                    <%= @organization.email_domain %>
                  </p>
                </div>
                
                <div class="flex items-center space-x-2">
                  <%= if @organization.verified do %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      <svg class="mr-1 h-3 w-3" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                      Verified
                    </span>
                  <% else %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                      <svg class="mr-1 h-3 w-3" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                      </svg>
                      Unverified
                    </span>
                  <% end %>
                </div>
              </div>
              
              <div class="flex items-center space-x-3">
                <%= if @current_user.role == :admin do %>
                  <button
                    phx-click="toggle_verification"
                    class={"px-4 py-2 text-sm font-medium rounded-md border focus:outline-none focus:ring-2 focus:ring-offset-2 " <>
                           if(@organization.verified, 
                              do: "border-yellow-300 text-yellow-700 bg-yellow-50 hover:bg-yellow-100 focus:ring-yellow-500", 
                              else: "border-green-300 text-green-700 bg-green-50 hover:bg-green-100 focus:ring-green-500")}
                  >
                    <%= if @organization.verified, do: "Mark Unverified", else: "Mark Verified" %>
                  </button>
                <% end %>
                
                <.link
                  patch={~p"/admin/organizations/#{@organization.id}/edit"}
                  class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Edit Organization
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Tab Navigation -->
      <div class="bg-white shadow">
        <div class="px-4 sm:px-6 lg:px-8">
          <nav class="-mb-px flex space-x-8">
            <button
              phx-click="change_tab"
              phx-value-tab="overview"
              class={"py-4 px-1 border-b-2 font-medium text-sm " <>
                     if(@selected_tab == "overview", 
                        do: "border-blue-500 text-blue-600", 
                        else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")}
            >
              Overview
            </button>
            
            <button
              phx-click="change_tab"
              phx-value-tab="locations"
              class={"py-4 px-1 border-b-2 font-medium text-sm " <>
                     if(@selected_tab == "locations", 
                        do: "border-blue-500 text-blue-600", 
                        else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")}
            >
              Locations (<%= length(@locations) %>)
            </button>
            
            <button
              phx-click="change_tab"
              phx-value-tab="users"
              class={"py-4 px-1 border-b-2 font-medium text-sm " <>
                     if(@selected_tab == "users", 
                        do: "border-blue-500 text-blue-600", 
                        else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")}
            >
              Users (<%= length(@organization_users) %>)
            </button>
            
            <button
              phx-click="change_tab"
              phx-value-tab="analytics"
              class={"py-4 px-1 border-b-2 font-medium text-sm " <>
                     if(@selected_tab == "analytics", 
                        do: "border-blue-500 text-blue-600", 
                        else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")}
            >
              Analytics
            </button>
          </nav>
        </div>
      </div>

      <!-- Tab Content -->
      <div class="space-y-6">
        <%= case @selected_tab do %>
          <% "overview" -> %>
            <%= render_overview_tab(assigns) %>
          <% "locations" -> %>
            <%= render_locations_tab(assigns) %>
          <% "users" -> %>
            <%= render_users_tab(assigns) %>
          <% "analytics" -> %>
            <%= render_analytics_tab(assigns) %>
        <% end %>
      </div>
    </div>

    <!-- Location Form Modal -->
    <%= if @show_location_modal do %>
      <.live_component
        module={LocationFormComponent}
        id="location-form"
        organization={@organization}
        location={@editing_location}
        current_user={@current_user}
      />
    <% end %>
    """
  end
  
  # Overview tab content
  defp render_overview_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Organization Profile -->
      <div class="lg:col-span-2">
        <div class="bg-white shadow rounded-lg p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Organization Profile</h3>
          
          <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <dt class="text-sm font-medium text-gray-500">Organization Type</dt>
              <dd class="mt-1 text-sm text-gray-900 capitalize">
                <%= String.replace(@organization.core_profile["organization_type"] || "Not specified", "_", " ") %>
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Industry Sector</dt>
              <dd class="mt-1 text-sm text-gray-900 capitalize">
                <%= String.replace(@organization.core_profile["industry_sector"] || "Not specified", "_", " ") %>
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Headquarters Region</dt>
              <dd class="mt-1 text-sm text-gray-900 capitalize">
                <%= @organization.core_profile["headquarters_region"] || "Not specified" %>
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Registration Number</dt>
              <dd class="mt-1 text-sm text-gray-900">
                <%= @organization.core_profile["registration_number"] || "Not specified" %>
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Total Employees</dt>
              <dd class="mt-1 text-sm text-gray-900">
                <%= @organization.core_profile["total_employees"] || "Not specified" %>
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Primary SIC Code</dt>
              <dd class="mt-1 text-sm text-gray-900">
                <%= @organization.core_profile["primary_sic_code"] || "Not specified" %>
              </dd>
            </div>
            
            <div class="sm:col-span-2">
              <dt class="text-sm font-medium text-gray-500">Created</dt>
              <dd class="mt-1 text-sm text-gray-900">
                <%= Calendar.strftime(@organization.inserted_at, "%B %d, %Y at %I:%M %p") %>
              </dd>
            </div>
          </dl>
        </div>
      </div>
      
      <!-- Quick Stats -->
      <div class="space-y-6">
        <!-- Profile Completeness -->
        <div class="bg-white shadow rounded-lg p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Profile Completeness</h3>
          
          <div class="mb-4">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium text-gray-700">Overall</span>
              <span class="text-sm text-gray-500">
                <%= round(Decimal.to_float(@organization.profile_completeness_score || 0) * 100) %>%
              </span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-2">
              <div
                class="bg-blue-600 h-2 rounded-full transition-all duration-300"
                style={"width: #{round(Decimal.to_float(@organization.profile_completeness_score || 0) * 100)}%"}
              >
              </div>
            </div>
          </div>
          
          <div class="space-y-2 text-sm">
            <%= if Decimal.to_float(@organization.profile_completeness_score || 0) < 0.5 do %>
              <p class="text-yellow-600">⚠️ Profile needs more information</p>
            <% else %>
              <p class="text-green-600">✅ Profile is well-populated</p>
            <% end %>
          </div>
        </div>
        
        <!-- Location Summary -->
        <div class="bg-white shadow rounded-lg p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Location Summary</h3>
          
          <div class="space-y-3">
            <div class="flex justify-between">
              <span class="text-sm text-gray-500">Total Locations</span>
              <span class="text-sm font-medium text-gray-900"><%= length(@locations) %></span>
            </div>
            
            <div class="flex justify-between">
              <span class="text-sm text-gray-500">Active Locations</span>
              <span class="text-sm font-medium text-gray-900">
                <%= Enum.count(@locations, &(&1.operational_status == :active)) %>
              </span>
            </div>
            
            <div class="flex justify-between">
              <span class="text-sm text-gray-500">Primary Location</span>
              <span class="text-sm font-medium text-gray-900">
                <%= case Enum.find(@locations, &(&1.is_primary_location)) do %>
                  <% nil -> %> Not set
                  <% location -> %> <%= location.location_name %>
                <% end %>
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  # Locations tab content
  defp render_locations_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Locations Header -->
      <div class="bg-white shadow rounded-lg p-6">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="text-lg font-medium text-gray-900">Organization Locations</h3>
            <p class="mt-1 text-sm text-gray-500">
              Manage all locations for this organization
            </p>
          </div>
          
          <%= if @current_user.role == :admin do %>
            <div class="flex items-center space-x-3">
              <.link
                navigate={~p"/admin/organizations/#{@organization.id}/locations"}
                class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <svg class="mr-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                </svg>
                Manage All Locations
              </.link>
              
              <.link
                patch={~p"/admin/organizations/#{@organization.id}/locations/new"}
                class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Add Location
              </.link>
            </div>
          <% end %>
        </div>
      </div>
      
      <!-- Locations List -->
      <%= if length(@locations) > 0 do %>
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <div class="divide-y divide-gray-200">
            <%= for location <- @locations do %>
              <div class="p-6">
                <div class="flex items-start justify-between">
                  <div class="flex-1">
                    <div class="flex items-center space-x-3">
                      <h4 class="text-lg font-medium text-gray-900">
                        <%= location.location_name %>
                      </h4>
                      
                      <%= if location.is_primary_location do %>
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                          Primary
                        </span>
                      <% end %>
                      
                      <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium " <>
                                  case location.operational_status do
                                    :active -> "bg-green-100 text-green-800"
                                    :inactive -> "bg-gray-100 text-gray-800"
                                    :seasonal -> "bg-yellow-100 text-yellow-800"
                                    _ -> "bg-gray-100 text-gray-800"
                                  end}>
                        <%= String.capitalize(to_string(location.operational_status)) %>
                      </span>
                    </div>
                    
                    <div class="mt-2 grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm text-gray-600">
                      <div>
                        <span class="font-medium">Type:</span>
                        <%= String.replace(to_string(location.location_type), "_", " ") |> String.capitalize() %>
                      </div>
                      
                      <div>
                        <span class="font-medium">Region:</span>
                        <%= String.capitalize(location.geographic_region) %>
                      </div>
                      
                      <%= if location.employee_count do %>
                        <div>
                          <span class="font-medium">Employees:</span>
                          <%= location.employee_count %>
                        </div>
                      <% end %>
                    </div>
                    
                    <%= if location.address do %>
                      <div class="mt-2 text-sm text-gray-600">
                        <span class="font-medium">Address:</span>
                        <%= format_address(location.address) %>
                      </div>
                    <% end %>
                  </div>
                  
                  <%= if @current_user.role == :admin do %>
                    <div class="flex items-center space-x-2">
                      <.link
                        patch={~p"/admin/organizations/#{@organization.id}/locations/#{location.id}/edit"}
                        class="text-blue-600 hover:text-blue-900 text-sm font-medium"
                      >
                        Edit
                      </.link>
                      
                      <button
                        phx-click="delete_location"
                        phx-value-id={location.id}
                        data-confirm="Are you sure you want to delete this location?"
                        class="text-red-600 hover:text-red-900 text-sm font-medium"
                      >
                        Delete
                      </button>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="bg-white shadow rounded-lg p-12">
          <div class="text-center">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No locations</h3>
            <p class="mt-1 text-sm text-gray-500">
              This organization doesn't have any locations yet.
            </p>
            <%= if @current_user.role == :admin do %>
              <div class="mt-6">
                <.link
                  patch={~p"/admin/organizations/#{@organization.id}/locations/new"}
                  class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Add First Location
                </.link>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
  
  # Users tab content
  defp render_users_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Users Header -->
      <div class="bg-white shadow rounded-lg p-6">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="text-lg font-medium text-gray-900">Organization Users</h3>
            <p class="mt-1 text-sm text-gray-500">
              Manage user access and roles for this organization
            </p>
          </div>
          
          <%= if @current_user.role == :admin do %>
            <button
              disabled
              class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-400 bg-gray-100 cursor-not-allowed"
            >
              Add User (Coming Soon)
            </button>
          <% end %>
        </div>
      </div>
      
      <!-- User-Organization Relationships Placeholder -->
      <div class="bg-white shadow rounded-lg p-6">
        <div class="text-center py-12">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5 0a4 4 0 11-8 0 4 4 0 018 0z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">User-Organization Relationships</h3>
          <p class="mt-1 text-sm text-gray-500">
            This feature allows managing which users have access to this organization.
            Implementation requires:
          </p>
          <div class="mt-4 text-left max-w-md mx-auto">
            <ul class="text-sm text-gray-600 space-y-1">
              <li>• OrganizationUser resource/relationship</li>
              <li>• User role management within organizations</li>
              <li>• Access control and permissions</li>
              <li>• User invitation system</li>
            </ul>
          </div>
          <div class="mt-6">
            <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
              Planned for Phase 4
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  # Analytics tab content
  defp render_analytics_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Profile Analytics -->
      <div class="bg-white shadow rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Profile Analytics</h3>
        
        <div class="space-y-4">
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-600">Profile Completeness</span>
            <span class="text-lg font-semibold text-gray-900">
              <%= round(Decimal.to_float(@organization.profile_completeness_score || 0) * 100) %>%
            </span>
          </div>
          
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-600">Total Locations</span>
            <span class="text-lg font-semibold text-gray-900">
              <%= length(@locations) %>
            </span>
          </div>
          
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-600">Active Locations</span>
            <span class="text-lg font-semibold text-green-600">
              <%= Enum.count(@locations, &(&1.operational_status == :active)) %>
            </span>
          </div>
        </div>
      </div>
      
      <!-- Location Distribution -->
      <div class="bg-white shadow rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Location Distribution</h3>
        
        <%= if length(@locations) > 0 do %>
          <div class="space-y-3">
            <%= for {region, count} <- @locations |> Enum.group_by(&(&1.geographic_region)) |> Enum.map(fn {k, v} -> {k, length(v)} end) |> Enum.sort_by(&(elem(&1, 1)), :desc) do %>
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-600 capitalize"><%= region %></span>
                <span class="text-lg font-semibold text-gray-900"><%= count %></span>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="text-sm text-gray-500">No location data available</p>
        <% end %>
      </div>
    </div>
    """
  end
  
  # Helper function to format address
  defp format_address(address) when is_map(address) do
    [
      address["street"],
      address["city"],
      address["region"],
      address["postcode"]
    ]
    |> Enum.filter(&(!is_nil(&1) && &1 != ""))
    |> Enum.join(", ")
  end
  defp format_address(_), do: "Address not available"
end