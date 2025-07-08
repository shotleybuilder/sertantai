defmodule SertantaiWeb.DashboardLive do
  @moduledoc """
  Dashboard LiveView for authenticated users.
  Shows sync configurations, selected records, and quick actions.
  """
  
  use SertantaiWeb, :live_view

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Get sync configurations for user
    sync_configs = case Ash.read(
      Sertantai.Sync.SyncConfiguration 
      |> Ash.Query.for_read(:for_user, %{user_id: user.id}),
      domain: Sertantai.Sync
    ) do
      {:ok, configs} -> configs
      {:error, _} -> []
    end

    # Get selected records count
    selected_records_count = case Ash.read(
      Sertantai.Sync.SelectedRecord 
      |> Ash.Query.for_read(:for_user, %{user_id: user.id}),
      domain: Sertantai.Sync
    ) do
      {:ok, records} -> length(records)
      {:error, _} -> 0
    end

    # Get sync summary
    sync_summary = case Sertantai.Sync.SelectedRecord.get_sync_summary(user.id) do
      {:ok, summary} -> summary
      {:error, _} -> %{total: 0, pending: 0, synced: 0, failed: 0}
    end

    {:ok, assign(socket,
      sync_configs: sync_configs,
      selected_records_count: selected_records_count,
      sync_summary: sync_summary,
      page_title: "Dashboard"
    )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-8">
        <div class="flex justify-between items-center mb-8">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Dashboard</h1>
            <p class="mt-2 text-sm text-gray-600">
              Welcome back, <%= @current_user.first_name || @current_user.email %>!
            </p>
          </div>
          <div class="flex space-x-4">
            <.link navigate={~p"/sync-configs/new"} 
                  class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 text-sm font-medium">
              New Sync Config
            </.link>
            <.link navigate={~p"/records"} 
                  class="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 text-sm font-medium">
              Select Records
            </.link>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4 mb-8">
          <!-- Sync Configurations Card -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-8 w-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4"></path>
                </svg>
              </div>
              <div class="ml-4">
                <h3 class="text-lg font-medium text-gray-900">Sync Configs</h3>
                <p class="text-3xl font-bold text-blue-600"><%= length(@sync_configs) %></p>
              </div>
            </div>
            <div class="mt-4">
              <.link navigate={~p"/sync-configs"} class="text-blue-600 hover:text-blue-800 text-sm">
                Manage configurations →
              </.link>
            </div>
          </div>

          <!-- Selected Records Card -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-8 w-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"></path>
                </svg>
              </div>
              <div class="ml-4">
                <h3 class="text-lg font-medium text-gray-900">Selected Records</h3>
                <p class="text-3xl font-bold text-green-600"><%= @selected_records_count %></p>
              </div>
            </div>
            <div class="mt-4">
              <.link navigate={~p"/records"} class="text-green-600 hover:text-green-800 text-sm">
                Select records →
              </.link>
            </div>
          </div>

          <!-- Pending Syncs Card -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-8 w-8 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
              </div>
              <div class="ml-4">
                <h3 class="text-lg font-medium text-gray-900">Pending Syncs</h3>
                <p class="text-3xl font-bold text-yellow-600"><%= @sync_summary.pending %></p>
              </div>
            </div>
            <div class="mt-4">
              <span class="text-yellow-600 text-sm">
                <%= @sync_summary.synced %> synced, <%= @sync_summary.failed %> failed
              </span>
            </div>
          </div>

          <!-- Active Configs Card -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-8 w-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
                </svg>
              </div>
              <div class="ml-4">
                <h3 class="text-lg font-medium text-gray-900">Active Configs</h3>
                <p class="text-3xl font-bold text-purple-600">
                  <%= @sync_configs |> Enum.count(& &1.is_active) %>
                </p>
              </div>
            </div>
            <div class="mt-4">
              <span class="text-purple-600 text-sm">
                <%= @sync_configs |> Enum.count(&(!&1.is_active)) %> inactive
              </span>
            </div>
          </div>
        </div>

        <!-- Recent Sync Configurations -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Recent Sync Configurations</h3>
          </div>
          <div class="px-6 py-4">
            <%= if Enum.empty?(@sync_configs) do %>
              <div class="text-center py-8">
                <svg class="h-12 w-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4"></path>
                </svg>
                <p class="text-gray-500 text-sm">No sync configurations yet</p>
                <.link navigate={~p"/sync-configs/new"} 
                      class="mt-4 inline-block bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 text-sm">
                  Create your first sync configuration
                </.link>
              </div>
            <% else %>
              <div class="space-y-4">
                <%= for config <- Enum.take(@sync_configs, 5) do %>
                  <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                        <span class={[
                          "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                          case config.provider do
                            :airtable -> "bg-orange-100 text-orange-800"
                            :notion -> "bg-gray-100 text-gray-800"
                            :zapier -> "bg-blue-100 text-blue-800"
                            _ -> "bg-gray-100 text-gray-800"
                          end
                        ]}>
                          <%= String.capitalize(to_string(config.provider)) %>
                        </span>
                      </div>
                      <div class="ml-4">
                        <h4 class="text-sm font-medium text-gray-900"><%= config.name %></h4>
                        <p class="text-sm text-gray-500">
                          <%= String.capitalize(to_string(config.sync_status)) %> • 
                          <%= String.capitalize(to_string(config.sync_frequency)) %> sync
                        </p>
                      </div>
                    </div>
                    <div class="flex items-center space-x-2">
                      <span class={[
                        "inline-flex items-center px-2 py-1 rounded-full text-xs font-medium",
                        if config.is_active do
                          "bg-green-100 text-green-800"
                        else
                          "bg-red-100 text-red-800"
                        end
                      ]}>
                        <%= if config.is_active, do: "Active", else: "Inactive" %>
                      </span>
                      <.link navigate={~p"/sync-configs/#{config.id}/edit"} 
                            class="text-blue-600 hover:text-blue-800 text-sm">
                        Edit
                      </.link>
                    </div>
                  </div>
                <% end %>
              </div>
              <%= if length(@sync_configs) > 5 do %>
                <div class="mt-4 text-center">
                  <.link navigate={~p"/sync-configs"} class="text-blue-600 hover:text-blue-800 text-sm">
                    View all configurations →
                  </.link>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end