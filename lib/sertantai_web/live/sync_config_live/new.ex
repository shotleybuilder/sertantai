defmodule SertantaiWeb.SyncConfigLive.New do
  @moduledoc """
  New Sync Configuration LiveView for creating sync configurations.
  """
  
  use SertantaiWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      page_title: "New Sync Configuration",
      form: to_form(%{}),
      provider: nil,
      errors: []
    )}
  end

  def handle_event("select_provider", %{"provider" => provider}, socket) do
    {:noreply, assign(socket, provider: String.to_existing_atom(provider))}
  end

  def handle_event("create", %{"config" => config_params}, socket) do
    user = socket.assigns.current_user
    provider = socket.assigns.provider
    
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

    # Create sync configuration
    case Ash.create(Sertantai.Sync.SyncConfiguration, %{
      user_id: user.id,
      name: config_params["name"],
      provider: provider,
      sync_frequency: String.to_existing_atom(config_params["sync_frequency"]),
      credentials: credentials
    }, domain: Sertantai.Sync) do
      {:ok, _config} ->
        {:noreply, 
          socket
          |> put_flash(:info, "Sync configuration created successfully")
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
          <h1 class="text-3xl font-bold text-gray-900">New Sync Configuration</h1>
          <p class="mt-2 text-sm text-gray-600">
            Create a new configuration to sync your selected records with external services
          </p>
        </div>

        <div class="bg-white shadow rounded-lg p-6">
          <%= if @provider == nil do %>
            <!-- Provider Selection -->
            <div>
              <h3 class="text-lg font-medium text-gray-900 mb-4">Choose a Provider</h3>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
                <button phx-click="select_provider" phx-value-provider="airtable"
                        class="relative rounded-lg border border-gray-300 bg-white px-6 py-4 shadow-sm hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500">
                  <div class="flex items-center">
                    <div class="flex-shrink-0">
                      <div class="h-8 w-8 bg-orange-100 rounded-lg flex items-center justify-center">
                        <span class="text-orange-600 font-bold text-sm">A</span>
                      </div>
                    </div>
                    <div class="ml-4">
                      <h4 class="text-sm font-medium text-gray-900">Airtable</h4>
                      <p class="text-sm text-gray-500">Sync to Airtable bases</p>
                    </div>
                  </div>
                </button>

                <button phx-click="select_provider" phx-value-provider="notion"
                        class="relative rounded-lg border border-gray-300 bg-white px-6 py-4 shadow-sm hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500">
                  <div class="flex items-center">
                    <div class="flex-shrink-0">
                      <div class="h-8 w-8 bg-gray-100 rounded-lg flex items-center justify-center">
                        <span class="text-gray-600 font-bold text-sm">N</span>
                      </div>
                    </div>
                    <div class="ml-4">
                      <h4 class="text-sm font-medium text-gray-900">Notion</h4>
                      <p class="text-sm text-gray-500">Sync to Notion databases</p>
                    </div>
                  </div>
                </button>

                <button phx-click="select_provider" phx-value-provider="zapier"
                        class="relative rounded-lg border border-gray-300 bg-white px-6 py-4 shadow-sm hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500">
                  <div class="flex items-center">
                    <div class="flex-shrink-0">
                      <div class="h-8 w-8 bg-blue-100 rounded-lg flex items-center justify-center">
                        <span class="text-blue-600 font-bold text-sm">Z</span>
                      </div>
                    </div>
                    <div class="ml-4">
                      <h4 class="text-sm font-medium text-gray-900">Zapier</h4>
                      <p class="text-sm text-gray-500">Sync via Zapier webhooks</p>
                    </div>
                  </div>
                </button>
              </div>
            </div>
          <% else %>
            <!-- Configuration Form -->
            <form phx-submit="create" class="space-y-6">
              <!-- Basic Info -->
              <div>
                <h3 class="text-lg font-medium text-gray-900 mb-4">
                  Configuration Details
                  <span class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                    <%= String.capitalize(to_string(@provider)) %>
                  </span>
                </h3>
                
                <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Configuration Name</label>
                    <input type="text" name="config[name]" required
                           class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                           placeholder="My Airtable Sync" />
                  </div>
                  
                  <div>
                    <label class="block text-sm font-medium text-gray-700">Sync Frequency</label>
                    <select name="config[sync_frequency]" required
                            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm">
                      <option value="manual">Manual</option>
                      <option value="hourly">Hourly</option>
                      <option value="daily">Daily</option>
                      <option value="weekly">Weekly</option>
                    </select>
                  </div>
                </div>
              </div>

              <!-- Provider-specific fields -->
              <%= case @provider do %>
                <% :airtable -> %>
                  <div>
                    <h4 class="text-md font-medium text-gray-900 mb-4">Airtable Configuration</h4>
                    <div class="space-y-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-700">API Key</label>
                        <input type="password" name="config[airtable_api_key]" required
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                               placeholder="pat14.eRo1..." />
                        <p class="mt-1 text-sm text-gray-500">
                          Get your API key from <a href="https://airtable.com/developers/web/api/introduction" class="text-blue-600 hover:text-blue-500" target="_blank">Airtable Developer Hub</a>
                        </p>
                      </div>
                      
                      <div>
                        <label class="block text-sm font-medium text-gray-700">Base ID</label>
                        <input type="text" name="config[airtable_base_id]" required
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                               placeholder="appXXXXXXXXXXXXXX" />
                      </div>
                      
                      <div>
                        <label class="block text-sm font-medium text-gray-700">Table ID</label>
                        <input type="text" name="config[airtable_table_id]" required
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
                        <input type="password" name="config[notion_api_key]" required
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                               placeholder="secret_XXXXXXXXXX" />
                        <p class="mt-1 text-sm text-gray-500">
                          Get your API key from <a href="https://developers.notion.com/" class="text-blue-600 hover:text-blue-500" target="_blank">Notion Developers</a>
                        </p>
                      </div>
                      
                      <div>
                        <label class="block text-sm font-medium text-gray-700">Database ID</label>
                        <input type="text" name="config[notion_database_id]" required
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
                        <input type="url" name="config[zapier_webhook_url]" required
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                               placeholder="https://hooks.zapier.com/hooks/catch/..." />
                      </div>
                      
                      <div>
                        <label class="block text-sm font-medium text-gray-700">API Key (Optional)</label>
                        <input type="password" name="config[zapier_api_key]"
                               class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                               placeholder="Optional authentication key" />
                      </div>
                    </div>
                  </div>
              <% end %>

              <!-- Form Actions -->
              <div class="flex justify-between">
                <button type="button" phx-click="select_provider" phx-value-provider=""
                        class="bg-gray-300 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-400">
                  ← Back to Provider Selection
                </button>
                <div class="flex space-x-3">
                  <.link navigate={~p"/sync-configs"} 
                        class="bg-gray-300 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-400">
                    Cancel
                  </.link>
                  <button type="submit"
                          class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700">
                    Create Configuration
                  </button>
                </div>
              </div>
            </form>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end