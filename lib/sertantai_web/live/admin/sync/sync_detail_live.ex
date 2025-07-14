defmodule SertantaiWeb.Admin.Sync.SyncDetailLive do
  @moduledoc """
  Sync configuration detail view for admin users.
  
  Shows comprehensive sync configuration information including status,
  monitoring, selected records, and sync history.
  """
  
  use SertantaiWeb, :live_view
  
  alias Sertantai.Sync.{SyncConfiguration, SelectedRecord}
  
  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case load_sync_config_with_details(id, socket.assigns.current_user) do
      {:ok, {config, selected_records, sync_summary}} ->
        {:ok,
         socket
         |> assign(:config, config)
         |> assign(:selected_records, selected_records)
         |> assign(:sync_summary, sync_summary)
         |> assign(:selected_tab, "overview")
         |> assign(:credentials_visible, false)}
      
      {:error, _error} ->
        {:ok,
         socket
         |> put_flash(:error, "Sync configuration not found")
         |> push_navigate(to: ~p"/admin/sync")}
    end
  end
  
  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end
  
  defp apply_action(socket, :show, _params) do
    socket
  end
  
  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :selected_tab, tab)}
  end
  
  def handle_event("toggle_active", _params, socket) do
    config = socket.assigns.config
    new_status = !config.is_active
    
    case Ash.update(config, %{is_active: new_status}, actor: socket.assigns.current_user) do
      {:ok, updated_config} ->
        message = if new_status, do: "Sync configuration activated", else: "Sync configuration deactivated"
        
        {:noreply,
         socket
         |> assign(:config, updated_config)
         |> put_flash(:info, message)}
      
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to update sync configuration")}
    end
  end
  
  def handle_event("toggle_credentials", _params, socket) do
    {:noreply, assign(socket, :credentials_visible, !socket.assigns.credentials_visible)}
  end
  
  def handle_event("trigger_sync", _params, socket) do
    # This would trigger a manual sync - placeholder for now
    config = socket.assigns.config
    
    case Ash.update(config, %{sync_status: :syncing}, action: :update_sync_status, actor: socket.assigns.current_user) do
      {:ok, updated_config} ->
        {:noreply,
         socket
         |> assign(:config, updated_config)
         |> put_flash(:info, "Manual sync triggered")}
      
      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to trigger sync")}
    end
  end
  
  # Helper function to load sync config with all related data
  defp load_sync_config_with_details(id, current_user) do
    with {:ok, config} <- Ash.get(SyncConfiguration, id, actor: current_user) do
      # Load selected records
      selected_records_result = Ash.read(SelectedRecord, 
        filter: [sync_configuration_id: id], 
        actor: current_user,
        sort: [inserted_at: :desc]
      )
      
      # Get sync summary
      sync_summary_result = SelectedRecord.get_sync_summary(config.user_id)
      
      case {selected_records_result, sync_summary_result} do
        {{:ok, selected_records}, {:ok, sync_summary}} ->
          {:ok, {config, selected_records, sync_summary}}
        
        {{:error, error}, _} ->
          {:error, error}
          
        {_, {:error, error}} ->
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
                  navigate={~p"/admin/sync"}
                  class="text-gray-500 hover:text-gray-700"
                >
                  <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                  </svg>
                </.link>
                
                <div>
                  <h1 class="text-2xl font-bold text-gray-900">
                    <%= @config.name %>
                  </h1>
                  <p class="text-sm text-gray-500">
                    <%= String.capitalize(to_string(@config.provider)) %> • <%= String.capitalize(to_string(@config.sync_frequency)) %>
                  </p>
                </div>
                
                <div class="flex items-center space-x-2">
                  <%= if @config.is_active do %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      <div class="w-2 h-2 bg-green-400 rounded-full mr-1.5"></div>
                      Active
                    </span>
                  <% else %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                      <div class="w-2 h-2 bg-gray-400 rounded-full mr-1.5"></div>
                      Inactive
                    </span>
                  <% end %>
                  
                  <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium " <>
                             case @config.sync_status do
                               :completed -> "bg-green-100 text-green-800"
                               :syncing -> "bg-blue-100 text-blue-800"
                               :failed -> "bg-red-100 text-red-800"
                               :pending -> "bg-yellow-100 text-yellow-800"
                               _ -> "bg-gray-100 text-gray-800"
                             end}>
                    <%= String.capitalize(to_string(@config.sync_status)) %>
                  </span>
                </div>
              </div>
              
              <div class="flex items-center space-x-3">
                <button
                  phx-click="toggle_active"
                  class={"px-4 py-2 text-sm font-medium rounded-md border focus:outline-none focus:ring-2 focus:ring-offset-2 " <>
                         if(@config.is_active, 
                            do: "border-gray-300 text-gray-700 bg-white hover:bg-gray-50 focus:ring-gray-500", 
                            else: "border-green-300 text-green-700 bg-green-50 hover:bg-green-100 focus:ring-green-500")}
                >
                  <%= if @config.is_active, do: "Deactivate", else: "Activate" %>
                </button>
                
                <%= if @config.is_active do %>
                  <button
                    phx-click="trigger_sync"
                    class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    Trigger Sync
                  </button>
                <% end %>
                
                <.link
                  patch={~p"/admin/sync/#{@config.id}/edit"}
                  class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  Edit Configuration
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
              phx-value-tab="records"
              class={"py-4 px-1 border-b-2 font-medium text-sm " <>
                     if(@selected_tab == "records", 
                        do: "border-blue-500 text-blue-600", 
                        else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")}
            >
              Selected Records (<%= length(@selected_records) %>)
            </button>
            
            <button
              phx-click="change_tab"
              phx-value-tab="monitoring"
              class={"py-4 px-1 border-b-2 font-medium text-sm " <>
                     if(@selected_tab == "monitoring", 
                        do: "border-blue-500 text-blue-600", 
                        else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")}
            >
              Monitoring
            </button>
            
            <button
              phx-click="change_tab"
              phx-value-tab="credentials"
              class={"py-4 px-1 border-b-2 font-medium text-sm " <>
                     if(@selected_tab == "credentials", 
                        do: "border-blue-500 text-blue-600", 
                        else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")}
            >
              Credentials
            </button>
          </nav>
        </div>
      </div>

      <!-- Tab Content -->
      <div class="space-y-6">
        <%= case @selected_tab do %>
          <% "overview" -> %>
            <%= render_overview_tab(assigns) %>
          <% "records" -> %>
            <%= render_records_tab(assigns) %>
          <% "monitoring" -> %>
            <%= render_monitoring_tab(assigns) %>
          <% "credentials" -> %>
            <%= render_credentials_tab(assigns) %>
        <% end %>
      </div>
    </div>
    """
  end
  
  # Overview tab content
  defp render_overview_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Configuration Details -->
      <div class="lg:col-span-2">
        <div class="bg-white shadow rounded-lg p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Configuration Details</h3>
          
          <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <dt class="text-sm font-medium text-gray-500">Provider</dt>
              <dd class="mt-1 text-sm text-gray-900 capitalize flex items-center">
                <%= case @config.provider do %>
                  <% :airtable -> %>
                    <div class="w-3 h-3 bg-yellow-500 rounded-full mr-2"></div>
                    Airtable
                  <% :notion -> %>
                    <div class="w-3 h-3 bg-gray-900 rounded-full mr-2"></div>
                    Notion
                  <% :zapier -> %>
                    <div class="w-3 h-3 bg-orange-500 rounded-full mr-2"></div>
                    Zapier
                <% end %>
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Sync Frequency</dt>
              <dd class="mt-1 text-sm text-gray-900 capitalize">
                <%= String.replace(to_string(@config.sync_frequency), "_", " ") %>
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Status</dt>
              <dd class="mt-1 text-sm text-gray-900">
                <%= if @config.is_active, do: "Active", else: "Inactive" %>
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Sync Status</dt>
              <dd class="mt-1 text-sm text-gray-900 capitalize">
                <%= String.replace(to_string(@config.sync_status), "_", " ") %>
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Last Sync</dt>
              <dd class="mt-1 text-sm text-gray-900">
                <%= if @config.last_synced_at do %>
                  <%= Calendar.strftime(@config.last_synced_at, "%B %d, %Y at %I:%M %p") %>
                <% else %>
                  Never synced
                <% end %>
              </dd>
            </div>
            
            <div>
              <dt class="text-sm font-medium text-gray-500">Created</dt>
              <dd class="mt-1 text-sm text-gray-900">
                <%= Calendar.strftime(@config.inserted_at, "%B %d, %Y at %I:%M %p") %>
              </dd>
            </div>
          </dl>
        </div>
      </div>
      
      <!-- Sync Statistics -->
      <div class="space-y-6">
        <!-- Record Summary -->
        <div class="bg-white shadow rounded-lg p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Record Summary</h3>
          
          <div class="space-y-3">
            <div class="flex justify-between">
              <span class="text-sm text-gray-500">Total Records</span>
              <span class="text-sm font-medium text-gray-900"><%= @sync_summary.total %></span>
            </div>
            
            <div class="flex justify-between">
              <span class="text-sm text-gray-500">Pending Sync</span>
              <span class="text-sm font-medium text-yellow-600"><%= @sync_summary.pending %></span>
            </div>
            
            <div class="flex justify-between">
              <span class="text-sm text-gray-500">Successfully Synced</span>
              <span class="text-sm font-medium text-green-600"><%= @sync_summary.synced %></span>
            </div>
            
            <div class="flex justify-between">
              <span class="text-sm text-gray-500">Failed</span>
              <span class="text-sm font-medium text-red-600"><%= @sync_summary.failed %></span>
            </div>
          </div>
          
          <%= if @sync_summary.total > 0 do %>
            <div class="mt-4">
              <div class="flex items-center justify-between mb-2">
                <span class="text-sm font-medium text-gray-700">Sync Progress</span>
                <span class="text-sm text-gray-500">
                  <%= round(@sync_summary.synced / @sync_summary.total * 100) %>%
                </span>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-2">
                <div
                  class="bg-green-600 h-2 rounded-full transition-all duration-300"
                  style={"width: #{round(@sync_summary.synced / @sync_summary.total * 100)}%"}
                >
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
  
  # Records tab content
  defp render_records_tab(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg">
      <div class="px-4 py-5 sm:p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Selected Records</h3>
        
        <%= if length(@selected_records) > 0 do %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Record ID
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Type
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Last Sync
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Error
                  </th>
                </tr>
              </thead>
              
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for record <- @selected_records do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      <%= record.external_record_id %>
                    </td>
                    
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= record.record_type %>
                    </td>
                    
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium " <>
                                 case record.sync_status do
                                   :synced -> "bg-green-100 text-green-800"
                                   :pending -> "bg-yellow-100 text-yellow-800"
                                   :failed -> "bg-red-100 text-red-800"
                                   _ -> "bg-gray-100 text-gray-800"
                                 end}>
                        <%= String.capitalize(to_string(record.sync_status)) %>
                      </span>
                    </td>
                    
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= if record.last_synced_at do %>
                        <%= Calendar.strftime(record.last_synced_at, "%Y-%m-%d %H:%M") %>
                      <% else %>
                        Never
                      <% end %>
                    </td>
                    
                    <td class="px-6 py-4 text-sm text-red-600">
                      <%= record.sync_error %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <div class="text-center py-12">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            <h3 class="mt-2 text-sm font-medium text-gray-900">No records selected</h3>
            <p class="mt-1 text-sm text-gray-500">
              No records have been selected for syncing with this configuration.
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
  
  # Monitoring tab content
  defp render_monitoring_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Sync Performance -->
      <div class="bg-white shadow rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Sync Performance</h3>
        
        <div class="space-y-4">
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-600">Success Rate</span>
            <span class="text-lg font-semibold text-green-600">
              <%= if @sync_summary.total > 0 do %>
                <%= round(@sync_summary.synced / @sync_summary.total * 100) %>%
              <% else %>
                N/A
              <% end %>
            </span>
          </div>
          
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-600">Total Records</span>
            <span class="text-lg font-semibold text-gray-900">
              <%= @sync_summary.total %>
            </span>
          </div>
          
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-600">Failed Records</span>
            <span class="text-lg font-semibold text-red-600">
              <%= @sync_summary.failed %>
            </span>
          </div>
        </div>
      </div>
      
      <!-- Sync Status -->
      <div class="bg-white shadow rounded-lg p-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Current Status</h3>
        
        <div class="space-y-4">
          <div class="flex items-center">
            <div class={"w-3 h-3 rounded-full mr-3 " <>
                       case @config.sync_status do
                         :completed -> "bg-green-500"
                         :syncing -> "bg-blue-500 animate-pulse"
                         :failed -> "bg-red-500"
                         :pending -> "bg-yellow-500"
                         _ -> "bg-gray-500"
                       end}>
            </div>
            <span class="text-sm font-medium text-gray-900 capitalize">
              <%= String.replace(to_string(@config.sync_status), "_", " ") %>
            </span>
          </div>
          
          <div class="text-sm text-gray-600">
            <%= case @config.sync_status do %>
              <% :completed -> %>
                Last sync completed successfully
              <% :syncing -> %>
                Sync currently in progress...
              <% :failed -> %>
                Last sync failed - check error logs
              <% :pending -> %>
                Waiting for next sync cycle
              <% _ -> %>
                Status unknown
            <% end %>
          </div>
          
          <%= if @config.last_synced_at do %>
            <div class="text-xs text-gray-500">
              Last activity: <%= Calendar.strftime(@config.last_synced_at, "%B %d, %Y at %I:%M %p") %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
  
  # Credentials tab content
  defp render_credentials_tab(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-medium text-gray-900">Authentication Credentials</h3>
        <button
          phx-click="toggle_credentials"
          class="px-3 py-1 text-sm font-medium text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500"
        >
          <%= if @credentials_visible, do: "Hide", else: "Show" %> Credentials
        </button>
      </div>
      
      <%= if @credentials_visible do %>
        <%= case SyncConfiguration.decrypt_credentials(@config) do %>
          <% {:ok, credentials} -> %>
            <div class="space-y-4">
              <div class="p-3 bg-yellow-50 border border-yellow-200 rounded-md">
                <div class="flex">
                  <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                  </svg>
                  <div class="ml-3">
                    <p class="text-sm text-yellow-700">
                      <strong>Warning:</strong> Sensitive credentials are displayed below. Handle with care.
                    </p>
                  </div>
                </div>
              </div>
              
              <dl class="grid grid-cols-1 gap-4">
                <%= for {key, value} <- credentials do %>
                  <div>
                    <dt class="text-sm font-medium text-gray-500 capitalize">
                      <%= String.replace(key, "_", " ") %>
                    </dt>
                    <dd class="mt-1 text-sm text-gray-900 font-mono bg-gray-50 p-2 rounded border">
                      <%= if String.contains?(key, "key") or String.contains?(key, "token") do %>
                        <%= String.slice(value, 0..10) <> "..." %>
                      <% else %>
                        <%= value %>
                      <% end %>
                    </dd>
                  </div>
                <% end %>
              </dl>
            </div>
          
          <% {:error, _error} -> %>
            <div class="p-3 bg-red-50 border border-red-200 rounded-md">
              <div class="flex">
                <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                </svg>
                <div class="ml-3">
                  <p class="text-sm text-red-700">
                    <strong>Error:</strong> Unable to decrypt credentials. They may be corrupted or the encryption key has changed.
                  </p>
                </div>
              </div>
            </div>
        <% end %>
      <% else %>
        <div class="text-center py-8">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">Credentials Hidden</h3>
          <p class="mt-1 text-sm text-gray-500">
            Click "Show Credentials" to view encrypted authentication details.
          </p>
        </div>
      <% end %>
    </div>
    """
  end
end