defmodule SertantaiWeb.SyncConfigLive.Index do
  @moduledoc """
  Sync Configuration Index LiveView for managing user's sync configurations.
  """
  
  use SertantaiWeb, :live_view

  def mount(_params, session, socket) do
    require Logger
    Logger.info("SyncConfig mount starting...")
    Logger.info("Session: #{inspect(session)}")
    
    # Load current user from session using the user token
    case Map.get(session, "user") do
      nil ->
        Logger.info("No user in session, redirecting to login")
        {:ok, redirect(socket, to: "/login")}
        
      user_token when is_binary(user_token) ->
        Logger.info("Found user token in session: #{user_token}")
        
        # Extract user ID from token and load user
        case extract_user_id_from_token(user_token) do
          {:ok, user_id} ->
            case Ash.get(Sertantai.Accounts.User, user_id, domain: Sertantai.Accounts) do
              {:ok, user} ->
                Logger.info("User authenticated: #{inspect(user.email)}")
                
                sync_configs = case Ash.read(
                  Sertantai.Sync.SyncConfiguration
                  |> Ash.Query.for_read(:for_user, %{user_id: user.id})
                  |> Ash.Query.load([:selected_records]),
                  domain: Sertantai.Sync
                ) do
                  {:ok, configs} -> configs
                  {:error, _} -> []
                end

                {:ok, assign(socket, 
                  current_user: user,
                  sync_configs: sync_configs,
                  page_title: "Sync Configurations"
                )}
                
              {:error, error} ->
                Logger.error("Failed to load user: #{inspect(error)}")
                {:ok, redirect(socket, to: "/login")}
            end
            
          {:error, _} ->
            Logger.error("Failed to extract user ID from token")
            {:ok, redirect(socket, to: "/login")}
        end
        
      _ ->
        Logger.error("Invalid user session data")
        {:ok, redirect(socket, to: "/login")}
    end
  end
  
  # Helper function to extract user ID from session token
  defp extract_user_id_from_token(token) when is_binary(token) do
    case String.split(token, ":") do
      [_session_id, user_part] ->
        case String.split(user_part, "?") do
          ["user", params] ->
            case String.split(params, "=") do
              ["id", user_id] -> {:ok, user_id}
              _ -> {:error, :invalid_format}
            end
          _ -> {:error, :invalid_format}
        end
      _ -> {:error, :invalid_format}
    end
  end
  defp extract_user_id_from_token(_), do: {:error, :invalid_token}

  def handle_event("delete", %{"id" => id}, socket) do
    sync_config = Enum.find(socket.assigns.sync_configs, &(&1.id == id))

    case Ash.destroy(sync_config, domain: Sertantai.Sync) do
      :ok ->
        sync_configs = Enum.reject(socket.assigns.sync_configs, &(&1.id == id))

        {:noreply,
          socket
          |> assign(sync_configs: sync_configs)
          |> put_flash(:info, "Sync configuration deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete sync configuration")}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    sync_config = Enum.find(socket.assigns.sync_configs, &(&1.id == id))
    
    case Ash.update(sync_config, %{is_active: !sync_config.is_active}, domain: Sertantai.Sync) do
      {:ok, updated_config} ->
        sync_configs = Enum.map(socket.assigns.sync_configs, fn config ->
          if config.id == id, do: updated_config, else: config
        end)

        status = if updated_config.is_active, do: "activated", else: "deactivated"
        
        {:noreply,
          socket
          |> assign(sync_configs: sync_configs)
          |> put_flash(:info, "Sync configuration #{status} successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update sync configuration")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-8">
        <div class="flex justify-between items-center mb-8">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Sync Configurations</h1>
            <p class="mt-2 text-sm text-gray-600">
              Manage your external database sync configurations
            </p>
          </div>
          <.link navigate={~p"/sync-configs/new"}
                class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 font-medium">
            New Configuration
          </.link>
        </div>

        <%= if Enum.empty?(@sync_configs) do %>
          <div class="text-center py-12">
            <svg class="h-24 w-24 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4"></path>
            </svg>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No sync configurations</h3>
            <p class="text-gray-500 mb-6">Get started by creating your first sync configuration</p>
            <.link navigate={~p"/sync-configs/new"}
                  class="bg-blue-600 text-white px-6 py-3 rounded-md hover:bg-blue-700 font-medium">
              Create Configuration
            </.link>
          </div>
        <% else %>
          <div class="grid gap-6">
            <%= for config <- @sync_configs do %>
              <div class="bg-white shadow rounded-lg overflow-hidden">
                <div class="p-6">
                  <div class="flex items-start justify-between">
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                        <span class={[
                          "inline-flex items-center px-3 py-1 rounded-full text-sm font-medium",
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
                        <h3 class="text-lg font-medium text-gray-900"><%= config.name %></h3>
                        <div class="flex items-center space-x-4 mt-1">
                          <span class="text-sm text-gray-500">
                            Sync: <%= String.capitalize(to_string(config.sync_frequency)) %>
                          </span>
                          <span class="text-sm text-gray-500">
                            Status: <%= String.capitalize(to_string(config.sync_status)) %>
                          </span>
                          <span class="text-sm text-gray-500">
                            Records: <%= length(config.selected_records || []) %>
                          </span>
                        </div>
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
                    </div>
                  </div>

                  <%= if config.last_synced_at do %>
                    <div class="mt-4 text-sm text-gray-500">
                      Last synced: <%= Calendar.strftime(config.last_synced_at, "%B %d, %Y at %I:%M %p") %>
                    </div>
                  <% end %>

                  <div class="mt-6 flex items-center justify-between">
                    <div class="flex space-x-3">
                      <.link navigate={~p"/sync-configs/#{config.id}/edit"}
                            class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                        Edit Configuration
                      </.link>
                      <button phx-click="toggle_active" phx-value-id={config.id}
                              class="text-yellow-600 hover:text-yellow-800 text-sm font-medium">
                        <%= if config.is_active, do: "Deactivate", else: "Activate" %>
                      </button>
                    </div>
                    <div class="flex space-x-3">
                      <button class="text-green-600 hover:text-green-800 text-sm font-medium">
                        Test Connection
                      </button>
                      <button phx-click="delete" phx-value-id={config.id}
                              class="text-red-600 hover:text-red-800 text-sm font-medium"
                              data-confirm="Are you sure you want to delete this configuration?">
                        Delete
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end