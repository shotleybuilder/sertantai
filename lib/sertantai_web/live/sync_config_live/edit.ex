defmodule SertantaiWeb.SyncConfigLive.Edit do
  @moduledoc """
  Edit Sync Configuration LiveView for updating existing sync configurations.
  """
  
  use SertantaiWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user

    sync_config = case Ash.get(Sertantai.Sync.SyncConfiguration, id, domain: Sertantai.Sync) do
      {:ok, config} ->
        # Ensure user owns this configuration
        if config.user_id == user.id do
          config
        else
          nil
        end
      {:error, _} -> nil
    end

    if sync_config do
      # Decrypt credentials for form display
      decrypted_credentials = case Sertantai.Sync.SyncConfiguration.decrypt_credentials(sync_config) do
        {:ok, creds} -> creds
        {:error, _} -> %{}
      end

      {:ok, assign(socket,
        sync_config: sync_config,
        credentials: decrypted_credentials,
        form: to_form(%{}),
        errors: [],
        page_title: "Edit Sync Configuration"
      )}
    else
      {:ok,
        socket
        |> put_flash(:error, "Sync configuration not found")
        |> push_navigate(to: ~p"/sync-configs")}
    end
  end

  def handle_event("update", %{"config" => config_params}, socket) do
    sync_config = socket.assigns.sync_config
    provider = sync_config.provider
    
    # Extract credentials based on provider
    credentials = case provider do
      :airtable ->
        %{
          "api_key" => config_params["airtable_api_key"],
          "base_id" => config_params["airtable_base_id"],
          "table_id" => config_params["airtable_table_id"]
        }
      :notion ->
        %{
          "api_key" => config_params["notion_api_key"],
          "database_id" => config_params["notion_database_id"]
        }
      :zapier ->
        %{
          "webhook_url" => config_params["zapier_webhook_url"],
          "api_key" => config_params["zapier_api_key"]
        }
      _ ->
        %{}
    end

    # Update sync configuration
    update_params = %{
      name: config_params["name"],
      sync_frequency: String.to_existing_atom(config_params["sync_frequency"]),
      credentials: credentials
    }

    case Ash.update(sync_config, update_params, domain: Sertantai.Sync) do
      {:ok, _updated_config} ->
        {:noreply, 
          socket
          |> put_flash(:info, "Sync configuration updated successfully")
          |> push_navigate(to: ~p"/sync-configs")}

      {:error, error} ->
        {:noreply, assign(socket, errors: [error])}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-8">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Edit Sync Configuration</h1>
          <p class="mt-2 text-sm text-gray-600">
            Update your <%= String.capitalize(to_string(@sync_config.provider)) %> sync configuration
          </p>
        </div>

        <div class="bg-white shadow rounded-lg p-6">
          <form phx-submit="update" class="space-y-6">
            <!-- Basic Info -->
            <div>
              <h3 class="text-lg font-medium text-gray-900 mb-4">
                Configuration Details
                <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                  <%= String.capitalize(to_string(@sync_config.provider)) %>
                </span>
              </h3>
              
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <label class="block text-sm font-medium text-gray-700">Configuration Name</label>
                  <input type="text" name="config[name]" value={@sync_config.name} required
                         class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                         placeholder="My Airtable Sync" />
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-gray-700">Sync Frequency</label>
                  <select name="config[sync_frequency]" required
                          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm">
                    <option value="manual" selected={@sync_config.sync_frequency == :manual}>Manual</option>
                    <option value="hourly" selected={@sync_config.sync_frequency == :hourly}>Hourly</option>
                    <option value="daily" selected={@sync_config.sync_frequency == :daily}>Daily</option>
                    <option value="weekly" selected={@sync_config.sync_frequency == :weekly}>Weekly</option>
                  </select>
                </div>
              </div>
            </div>

            <!-- Provider-specific fields -->
            <%= case @sync_config.provider do %>
              <% :airtable -> %>
                <div>
                  <h4 class="text-md font-medium text-gray-900 mb-4">Airtable Configuration</h4>
                  <div class="space-y-4">
                    <div>
                      <label class="block text-sm font-medium text-gray-700">API Key</label>
                      <input type="password" name="config[airtable_api_key]" 
                             value={Map.get(@credentials, "api_key", "")} required
                             class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                             placeholder="pat14.eRo1..." />
                      <p class="mt-1 text-sm text-gray-500">
                        Get your API key from <a href="https://airtable.com/developers/web/api/introduction" class="text-blue-600 hover:text-blue-500" target="_blank">Airtable Developer Hub</a>
                      </p>
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Base ID</label>
                      <input type="text" name="config[airtable_base_id]" 
                             value={Map.get(@credentials, "base_id", "")} required
                             class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                             placeholder="appXXXXXXXXXXXXXX" />
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Table ID</label>
                      <input type="text" name="config[airtable_table_id]" 
                             value={Map.get(@credentials, "table_id", "")} required
                             class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                             placeholder="tblXXXXXXXXXXXXXX" />
                    </div>
                  </div>
                </div>

              <% :notion -> %>
                <div>
                  <h4 class="text-md font-medium text-gray-900 mb-4">Notion Configuration</h4>
                  <div class="space-y-4">
                    <div>
                      <label class="block text-sm font-medium text-gray-700">API Key</label>
                      <input type="password" name="config[notion_api_key]" 
                             value={Map.get(@credentials, "api_key", "")} required
                             class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                             placeholder="secret_XXXXXXXXXX" />
                      <p class="mt-1 text-sm text-gray-500">
                        Get your API key from <a href="https://developers.notion.com/" class="text-blue-600 hover:text-blue-500" target="_blank">Notion Developers</a>
                      </p>
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Database ID</label>
                      <input type="text" name="config[notion_database_id]" 
                             value={Map.get(@credentials, "database_id", "")} required
                             class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                             placeholder="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" />
                    </div>
                  </div>
                </div>

              <% :zapier -> %>
                <div>
                  <h4 class="text-md font-medium text-gray-900 mb-4">Zapier Configuration</h4>
                  <div class="space-y-4">
                    <div>
                      <label class="block text-sm font-medium text-gray-700">Webhook URL</label>
                      <input type="url" name="config[zapier_webhook_url]" 
                             value={Map.get(@credentials, "webhook_url", "")} required
                             class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                             placeholder="https://hooks.zapier.com/hooks/catch/..." />
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-700">API Key (Optional)</label>
                      <input type="password" name="config[zapier_api_key]"
                             value={Map.get(@credentials, "api_key", "")}
                             class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                             placeholder="Optional authentication key" />
                    </div>
                  </div>
                </div>
            <% end %>

            <!-- Form Actions -->
            <div class="flex justify-between">
              <.link navigate={~p"/sync-configs"} 
                    class="bg-gray-300 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-400">
                ← Back to Configurations
              </.link>
              <div class="flex space-x-3">
                <.link navigate={~p"/sync-configs"} 
                      class="bg-gray-300 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-400">
                  Cancel
                </.link>
                <button type="submit"
                        class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700">
                  Update Configuration
                </button>
              </div>
            </div>
          </form>

          <!-- Display Errors -->
          <%= if not Enum.empty?(@errors) do %>
            <div class="mt-6 bg-red-50 border border-red-200 rounded-md p-4">
              <h4 class="text-sm font-medium text-red-800">Please fix the following errors:</h4>
              <ul class="mt-2 text-sm text-red-700 list-disc list-inside">
                <%= for error <- @errors do %>
                  <li><%= inspect(error) %></li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end