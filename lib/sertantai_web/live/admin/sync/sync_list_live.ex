defmodule SertantaiWeb.Admin.Sync.SyncListLive do
  @moduledoc """
  Sync configuration management interface for admin users.
  
  Provides comprehensive sync configuration CRUD operations with monitoring,
  filtering, and encrypted credential management.
  """
  
  use SertantaiWeb, :live_view
  
  alias Sertantai.Sync.SyncConfiguration
  alias SertantaiWeb.Admin.Sync.SyncFormComponent
  
  @impl true
  def mount(_params, _session, socket) do
    # Load sync configurations using Ash
    case Ash.read(SyncConfiguration, actor: socket.assigns.current_user) do
      {:ok, sync_configs} ->
        {:ok,
         socket
         |> assign(:sync_configs, sync_configs)
         |> assign(:all_sync_configs, sync_configs)
         |> assign(:search_term, "")
         |> assign(:provider_filter, "all")
         |> assign(:status_filter, "all")
         |> assign(:sort_by, "name")
         |> assign(:sort_order, "asc")
         |> assign(:selected_configs, [])
         |> assign(:show_sync_modal, false)
         |> assign(:editing_config, nil)}
      
      {:error, _error} ->
        {:ok,
         socket
         |> put_flash(:error, "Failed to load sync configurations")
         |> assign(:sync_configs, [])
         |> assign(:all_sync_configs, [])
         |> assign(:search_term, "")
         |> assign(:provider_filter, "all")
         |> assign(:status_filter, "all")
         |> assign(:sort_by, "name")
         |> assign(:sort_order, "asc")
         |> assign(:selected_configs, [])
         |> assign(:show_sync_modal, false)
         |> assign(:editing_config, nil)}
    end
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end
  
  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:show_sync_modal, true)
    |> assign(:editing_config, nil)
  end
  
  defp apply_action(socket, :edit, %{"id" => id}) do
    case Ash.get(SyncConfiguration, id, actor: socket.assigns.current_user) do
      {:ok, config} ->
        socket
        |> assign(:show_sync_modal, true)
        |> assign(:editing_config, config)
      
      {:error, _error} ->
        socket
        |> put_flash(:error, "Sync configuration not found")
        |> assign(:show_sync_modal, false)
        |> assign(:editing_config, nil)
    end
  end
  
  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:show_sync_modal, false)
    |> assign(:editing_config, nil)
  end
  
  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    configs = filter_and_sort_configs(socket.assigns.all_sync_configs, search_term, socket.assigns.provider_filter, socket.assigns.status_filter, socket.assigns.sort_by, socket.assigns.sort_order)
    
    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:sync_configs, configs)
     |> assign(:selected_configs, [])}
  end
  
  def handle_event("filter_provider", %{"provider" => provider}, socket) do
    configs = filter_and_sort_configs(socket.assigns.all_sync_configs, socket.assigns.search_term, provider, socket.assigns.status_filter, socket.assigns.sort_by, socket.assigns.sort_order)
    
    {:noreply,
     socket
     |> assign(:provider_filter, provider)
     |> assign(:sync_configs, configs)
     |> assign(:selected_configs, [])}
  end
  
  def handle_event("filter_status", %{"status" => status}, socket) do
    configs = filter_and_sort_configs(socket.assigns.all_sync_configs, socket.assigns.search_term, socket.assigns.provider_filter, status, socket.assigns.sort_by, socket.assigns.sort_order)
    
    {:noreply,
     socket
     |> assign(:status_filter, status)
     |> assign(:sync_configs, configs)
     |> assign(:selected_configs, [])}
  end
  
  def handle_event("sort", %{"field" => field}, socket) do
    {sort_by, sort_order} = 
      if socket.assigns.sort_by == field do
        {field, if(socket.assigns.sort_order == "asc", do: "desc", else: "asc")}
      else
        {field, "asc"}
      end
    
    configs = filter_and_sort_configs(socket.assigns.all_sync_configs, socket.assigns.search_term, socket.assigns.provider_filter, socket.assigns.status_filter, sort_by, sort_order)
    
    {:noreply,
     socket
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> assign(:sync_configs, configs)}
  end
  
  def handle_event("select_config", %{"id" => id}, socket) do
    selected = socket.assigns.selected_configs
    new_selected = 
      if id in selected do
        List.delete(selected, id)
      else
        [id | selected]
      end
    
    {:noreply, assign(socket, :selected_configs, new_selected)}
  end
  
  def handle_event("select_all", _params, socket) do
    all_ids = Enum.map(socket.assigns.sync_configs, & &1.id)
    {:noreply, assign(socket, :selected_configs, all_ids)}
  end
  
  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_configs, [])}
  end
  
  def handle_event("toggle_active", %{"id" => id}, socket) do
    case Ash.get(SyncConfiguration, id, actor: socket.assigns.current_user) do
      {:ok, config} ->
        new_status = !config.is_active
        
        case Ash.update(config, %{is_active: new_status}, actor: socket.assigns.current_user) do
          {:ok, _updated_config} ->
            # Reload configurations
            case Ash.read(SyncConfiguration, actor: socket.assigns.current_user) do
              {:ok, configs} ->
                filtered_configs = filter_and_sort_configs(configs, socket.assigns.search_term, socket.assigns.provider_filter, socket.assigns.status_filter, socket.assigns.sort_by, socket.assigns.sort_order)
                
                message = if new_status, do: "Sync configuration activated", else: "Sync configuration deactivated"
                
                {:noreply,
                 socket
                 |> assign(:sync_configs, filtered_configs)
                 |> assign(:all_sync_configs, configs)
                 |> put_flash(:info, message)}
              
              {:error, _error} ->
                {:noreply, put_flash(socket, :error, "Failed to reload sync configurations")}
            end
          
          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Failed to update sync configuration")}
        end
      
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Sync configuration not found")}
    end
  end
  
  def handle_event("delete_config", %{"id" => id}, socket) do
    if socket.assigns.current_user.role == :admin do
      case Ash.get(SyncConfiguration, id, actor: socket.assigns.current_user) do
        {:ok, config} ->
          case Ash.destroy(config, actor: socket.assigns.current_user) do
            :ok ->
              # Reload configurations
              case Ash.read(SyncConfiguration, actor: socket.assigns.current_user) do
                {:ok, configs} ->
                  filtered_configs = filter_and_sort_configs(configs, socket.assigns.search_term, socket.assigns.provider_filter, socket.assigns.status_filter, socket.assigns.sort_by, socket.assigns.sort_order)
                  
                  {:noreply,
                   socket
                   |> assign(:sync_configs, filtered_configs)
                   |> assign(:all_sync_configs, configs)
                   |> put_flash(:info, "Sync configuration deleted successfully")}
                
                {:error, _error} ->
                  {:noreply, put_flash(socket, :error, "Failed to reload sync configurations")}
              end
            
            {:error, _error} ->
              {:noreply, put_flash(socket, :error, "Failed to delete sync configuration")}
          end
        
        {:error, _error} ->
          {:noreply, put_flash(socket, :error, "Sync configuration not found")}
      end
    else
      {:noreply, put_flash(socket, :error, "Only admins can delete sync configurations")}
    end
  end
  
  @impl true
  def handle_info({:sync_config_created, message}, socket) do
    # Reload configurations
    case Ash.read(SyncConfiguration, actor: socket.assigns.current_user) do
      {:ok, configs} ->
        filtered_configs = filter_and_sort_configs(configs, socket.assigns.search_term, socket.assigns.provider_filter, socket.assigns.status_filter, socket.assigns.sort_by, socket.assigns.sort_order)
        
        {:noreply,
         socket
         |> assign(:sync_configs, filtered_configs)
         |> assign(:all_sync_configs, configs)
         |> assign(:show_sync_modal, false)
         |> put_flash(:info, message)}
      
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to reload sync configurations")}
    end
  end
  
  def handle_info({:sync_config_updated, message}, socket) do
    # Reload configurations
    case Ash.read(SyncConfiguration, actor: socket.assigns.current_user) do
      {:ok, configs} ->
        filtered_configs = filter_and_sort_configs(configs, socket.assigns.search_term, socket.assigns.provider_filter, socket.assigns.status_filter, socket.assigns.sort_by, socket.assigns.sort_order)
        
        {:noreply,
         socket
         |> assign(:sync_configs, filtered_configs)
         |> assign(:all_sync_configs, configs)
         |> assign(:show_sync_modal, false)
         |> put_flash(:info, message)}
      
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to reload sync configurations")}
    end
  end
  
  def handle_info({:close_modal}, socket) do
    {:noreply,
     socket
     |> assign(:show_sync_modal, false)
     |> push_patch(to: ~p"/admin/sync")}
  end
  
  # Helper function to filter and sort sync configurations
  defp filter_and_sort_configs(configs, search_term, provider_filter, status_filter, sort_by, sort_order) do
    configs
    |> filter_by_search(search_term)
    |> filter_by_provider(provider_filter)
    |> filter_by_status(status_filter)
    |> sort_configs(sort_by, sort_order)
  end
  
  defp filter_by_search(configs, ""), do: configs
  defp filter_by_search(configs, search_term) do
    search_lower = String.downcase(search_term)
    
    Enum.filter(configs, fn config ->
      String.contains?(String.downcase(config.name), search_lower)
    end)
  end
  
  defp filter_by_provider(configs, "all"), do: configs
  defp filter_by_provider(configs, provider) do
    provider_atom = String.to_existing_atom(provider)
    Enum.filter(configs, &(&1.provider == provider_atom))
  end
  
  defp filter_by_status(configs, "all"), do: configs
  defp filter_by_status(configs, "active") do
    Enum.filter(configs, & &1.is_active)
  end
  defp filter_by_status(configs, "inactive") do
    Enum.filter(configs, &(!&1.is_active))
  end
  
  defp sort_configs(configs, sort_by, sort_order) do
    sorted = 
      case sort_by do
        "name" ->
          Enum.sort_by(configs, & &1.name)
        "provider" ->
          Enum.sort_by(configs, & &1.provider)
        "sync_status" ->
          Enum.sort_by(configs, & &1.sync_status)
        "last_synced_at" ->
          Enum.sort_by(configs, & &1.last_synced_at, DateTime)
        "inserted_at" ->
          Enum.sort_by(configs, & &1.inserted_at, DateTime)
        _ ->
          configs
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
      <!-- Header -->
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="text-2xl font-semibold text-gray-900">Sync Configuration Management</h1>
          <p class="mt-2 text-sm text-gray-700">
            Manage external sync configurations for Airtable, Notion, and Zapier integrations.
          </p>
        </div>
        <%= if @current_user.role == :admin do %>
          <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
            <.link
              patch={~p"/admin/sync/new"}
              class="inline-flex items-center justify-center rounded-md border border-transparent bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 sm:w-auto"
            >
              New Sync Configuration
            </.link>
          </div>
        <% end %>
      </div>

      <!-- Search and Filters -->
      <div class="bg-white p-4 rounded-lg shadow space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <!-- Search -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
            <input
              type="text"
              value={@search_term}
              phx-change="search"
              name="search"
              placeholder="Search by name..."
              class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            />
          </div>

          <!-- Provider Filter -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Provider</label>
            <select
              phx-change="filter_provider"
              name="provider"
              value={@provider_filter}
              class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            >
              <option value="all">All Providers</option>
              <option value="airtable">Airtable</option>
              <option value="notion">Notion</option>
              <option value="zapier">Zapier</option>
            </select>
          </div>

          <!-- Status Filter -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
            <select
              phx-change="filter_status"
              name="status"
              value={@status_filter}
              class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            >
              <option value="all">All Statuses</option>
              <option value="active">Active Only</option>
              <option value="inactive">Inactive Only</option>
            </select>
          </div>

          <!-- Results Info -->
          <div class="flex items-center justify-between">
            <span class="text-sm text-gray-500">
              <%= length(@sync_configs) %> configuration(s)
            </span>
            <%= if length(@selected_configs) > 0 do %>
              <span class="text-sm font-medium text-blue-600">
                <%= length(@selected_configs) %> selected
              </span>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Sync Configurations Table -->
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
                phx-value-field="name"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Name</span>
                  <%= if @sort_by == "name" do %>
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
                phx-value-field="provider"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Provider</span>
                  <%= if @sort_by == "provider" do %>
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
                Status
              </th>
              
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Sync Status
              </th>
              
              <th
                phx-click="sort"
                phx-value-field="last_synced_at"
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
              >
                <div class="flex items-center space-x-1">
                  <span>Last Sync</span>
                  <%= if @sort_by == "last_synced_at" do %>
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
            <%= for config <- @sync_configs do %>
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4">
                  <input
                    type="checkbox"
                    checked={config.id in @selected_configs}
                    phx-click="select_config"
                    phx-value-id={config.id}
                    class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  />
                </td>
                
                <td class="px-6 py-4">
                  <div class="text-sm font-medium text-gray-900">
                    <%= config.name %>
                  </div>
                  <div class="text-sm text-gray-500">
                    Frequency: <%= String.capitalize(to_string(config.sync_frequency)) %>
                  </div>
                </td>
                
                <td class="px-6 py-4">
                  <div class="flex items-center">
                    <%= case config.provider do %>
                      <% :airtable -> %>
                        <div class="flex items-center">
                          <div class="w-2 h-2 bg-yellow-500 rounded-full mr-2"></div>
                          <span class="text-sm text-gray-900">Airtable</span>
                        </div>
                      <% :notion -> %>
                        <div class="flex items-center">
                          <div class="w-2 h-2 bg-gray-900 rounded-full mr-2"></div>
                          <span class="text-sm text-gray-900">Notion</span>
                        </div>
                      <% :zapier -> %>
                        <div class="flex items-center">
                          <div class="w-2 h-2 bg-orange-500 rounded-full mr-2"></div>
                          <span class="text-sm text-gray-900">Zapier</span>
                        </div>
                    <% end %>
                  </div>
                </td>
                
                <td class="px-6 py-4">
                  <button
                    phx-click="toggle_active"
                    phx-value-id={config.id}
                    class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium " <>
                           if(config.is_active, 
                              do: "bg-green-100 text-green-800 hover:bg-green-200", 
                              else: "bg-gray-100 text-gray-800 hover:bg-gray-200")}
                  >
                    <%= if config.is_active, do: "Active", else: "Inactive" %>
                  </button>
                </td>
                
                <td class="px-6 py-4">
                  <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium " <>
                             case config.sync_status do
                               :completed -> "bg-green-100 text-green-800"
                               :syncing -> "bg-blue-100 text-blue-800"
                               :failed -> "bg-red-100 text-red-800"
                               :pending -> "bg-yellow-100 text-yellow-800"
                               _ -> "bg-gray-100 text-gray-800"
                             end}>
                    <%= String.capitalize(to_string(config.sync_status)) %>
                  </span>
                </td>
                
                <td class="px-6 py-4 text-sm text-gray-500">
                  <%= if config.last_synced_at do %>
                    <%= Calendar.strftime(config.last_synced_at, "%Y-%m-%d %H:%M") %>
                  <% else %>
                    Never
                  <% end %>
                </td>
                
                <td class="px-6 py-4 text-sm text-gray-500">
                  <%= Calendar.strftime(config.inserted_at, "%Y-%m-%d") %>
                </td>
                
                <td class="px-6 py-4 text-right text-sm font-medium space-x-2">
                  <.link
                    patch={~p"/admin/sync/#{config.id}/edit"}
                    class="text-blue-600 hover:text-blue-900"
                  >
                    Edit
                  </.link>
                  <%= if @current_user.role == :admin do %>
                    <button
                      phx-click="delete_config"
                      phx-value-id={config.id}
                      data-confirm="Are you sure you want to delete this sync configuration?"
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
        
        <%= if length(@sync_configs) == 0 do %>
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No sync configurations found</h3>
            <p class="mt-1 text-sm text-gray-500">
              <%= if @search_term != "" or @provider_filter != "all" or @status_filter != "all" do %>
                Try adjusting your search or filters.
              <% else %>
                Get started by creating a new sync configuration.
              <% end %>
            </p>
          </div>
        <% end %>
      </div>
    </div>

    <!-- Sync Configuration Form Modal -->
    <%= if @show_sync_modal do %>
      <.live_component
        module={SyncFormComponent}
        id="sync-form"
        config={@editing_config}
        current_user={@current_user}
      />
    <% end %>
    """
  end
end