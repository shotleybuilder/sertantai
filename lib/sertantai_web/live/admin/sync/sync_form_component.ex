defmodule SertantaiWeb.Admin.Sync.SyncFormComponent do
  @moduledoc """
  Sync configuration form component for creating and editing sync configurations.
  
  Handles encrypted credential management and proper validation
  with Ash Framework integration.
  """
  
  use SertantaiWeb, :live_component
  
  alias Sertantai.Sync.SyncConfiguration
  
  @impl true
  def update(%{config: config} = assigns, socket) do
    form = 
      if config do
        AshPhoenix.Form.for_update(config, :update, forms: [auto?: false])
      else
        AshPhoenix.Form.for_create(SyncConfiguration, :create, forms: [auto?: false])
      end
    
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, form)
     |> assign(:action, if(config, do: :edit, else: :create))}
  end
  
  @impl true
  def handle_event("validate", %{"sync_config" => config_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, config_params)
    
    {:noreply, assign(socket, :form, form)}
  end
  
  def handle_event("save", %{"sync_config" => config_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, config_params)
    
    # Build credentials map based on provider
    credentials = build_credentials(config_params["provider"], config_params)
    
    # Add credentials to params
    params_with_credentials = Map.put(config_params, "credentials", credentials)
    
    case socket.assigns.action do
      :create ->
        # Add user_id for new configurations
        params_with_user = Map.put(params_with_credentials, "user_id", socket.assigns.current_user.id)
        
        case AshPhoenix.Form.submit(form, params: params_with_user) do
          {:ok, _config} ->
            message = "Sync configuration created successfully"
            send(self(), {:sync_config_created, message})
            {:noreply, socket}
          
          {:error, form} ->
            {:noreply, assign(socket, :form, form)}
        end
      
      :edit ->
        case AshPhoenix.Form.submit(form, params: params_with_credentials) do
          {:ok, _config} ->
            message = "Sync configuration updated successfully"
            send(self(), {:sync_config_updated, message})
            {:noreply, socket}
          
          {:error, form} ->
            {:noreply, assign(socket, :form, form)}
        end
    end
  end
  
  def handle_event("close", _params, socket) do
    send(self(), {:close_modal})
    {:noreply, socket}
  end
  
  # Build credentials map based on provider type
  defp build_credentials("airtable", params) do
    %{
      "api_key" => params["airtable_api_key"],
      "base_id" => params["airtable_base_id"],
      "table_name" => params["airtable_table_name"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end
  
  defp build_credentials("notion", params) do
    %{
      "api_key" => params["notion_api_key"],
      "database_id" => params["notion_database_id"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end
  
  defp build_credentials("zapier", params) do
    %{
      "webhook_url" => params["zapier_webhook_url"],
      "api_key" => params["zapier_api_key"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end
  
  defp build_credentials(_, _params), do: %{}
  
  # Get decrypted credentials for editing
  defp get_decrypted_credentials(nil), do: %{}
  defp get_decrypted_credentials(config) do
    case SyncConfiguration.decrypt_credentials(config) do
      {:ok, credentials} -> credentials
      {:error, _} -> %{}
    end
  end
  
  @impl true
  def render(assigns) do
    # Get decrypted credentials for editing
    assigns = assign(assigns, :credentials, get_decrypted_credentials(assigns.config))
    
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto">
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <!-- Background overlay -->
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" phx-click="close"></div>
        
        <!-- Modal panel -->
        <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full sm:p-6">
          <div>
            <div class="mt-3 text-center sm:mt-0 sm:text-left">
              <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                <%= if @action == :create, do: "Create New Sync Configuration", else: "Edit Sync Configuration" %>
              </h3>
              
              <.form
                for={@form}
                phx-target={assigns[:myself]}
                phx-change="validate"
                phx-submit="save"
                class="space-y-6"
              >
                <!-- Basic Configuration -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <!-- Configuration Name -->
                  <div class="md:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Configuration Name *
                    </label>
                    <input
                      type="text"
                      name="sync_config[name]"
                      value={AshPhoenix.Form.value(@form, :name)}
                      required
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    />
                    <%= if error = @form.errors[:name] do %>
                      <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                    <% end %>
                  </div>
                  
                  <!-- Provider -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Provider *
                    </label>
                    <select
                      name="sync_config[provider]"
                      value={AshPhoenix.Form.value(@form, :provider)}
                      required
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="">Select provider...</option>
                      <option value="airtable">Airtable</option>
                      <option value="notion">Notion</option>
                      <option value="zapier">Zapier</option>
                    </select>
                    <%= if error = @form.errors[:provider] do %>
                      <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                    <% end %>
                  </div>
                  
                  <!-- Sync Frequency -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Sync Frequency
                    </label>
                    <select
                      name="sync_config[sync_frequency]"
                      value={AshPhoenix.Form.value(@form, :sync_frequency) || "manual"}
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="manual">Manual</option>
                      <option value="hourly">Hourly</option>
                      <option value="daily">Daily</option>
                      <option value="weekly">Weekly</option>
                    </select>
                  </div>
                </div>
                
                <!-- Provider-Specific Credentials -->
                <div class="border-t border-gray-200 pt-6">
                  <h4 class="text-md font-medium text-gray-900 mb-4">Authentication Credentials</h4>
                  
                  <!-- Airtable Credentials -->
                  <div id="airtable-credentials" style={"display: #{if AshPhoenix.Form.value(@form, :provider) == :airtable, do: "block", else: "none"}"}>
                    <div class="space-y-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                          API Key *
                        </label>
                        <input
                          type="password"
                          name="sync_config[airtable_api_key]"
                          value={@credentials["api_key"]}
                          placeholder="Enter your Airtable API key"
                          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        />
                      </div>
                      
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                          Base ID *
                        </label>
                        <input
                          type="text"
                          name="sync_config[airtable_base_id]"
                          value={@credentials["base_id"]}
                          placeholder="e.g., appXXXXXXXXXXXXXX"
                          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        />
                      </div>
                      
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                          Table Name *
                        </label>
                        <input
                          type="text"
                          name="sync_config[airtable_table_name]"
                          value={@credentials["table_name"]}
                          placeholder="e.g., UK LRT Records"
                          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        />
                      </div>
                    </div>
                  </div>
                  
                  <!-- Notion Credentials -->
                  <div id="notion-credentials" style={"display: #{if AshPhoenix.Form.value(@form, :provider) == :notion, do: "block", else: "none"}"}>
                    <div class="space-y-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                          Integration Token *
                        </label>
                        <input
                          type="password"
                          name="sync_config[notion_api_key]"
                          value={@credentials["api_key"]}
                          placeholder="secret_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
                          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        />
                      </div>
                      
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                          Database ID *
                        </label>
                        <input
                          type="text"
                          name="sync_config[notion_database_id]"
                          value={@credentials["database_id"]}
                          placeholder="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
                          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        />
                      </div>
                    </div>
                  </div>
                  
                  <!-- Zapier Credentials -->
                  <div id="zapier-credentials" style={"display: #{if AshPhoenix.Form.value(@form, :provider) == :zapier, do: "block", else: "none"}"}>
                    <div class="space-y-4">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                          Webhook URL *
                        </label>
                        <input
                          type="url"
                          name="sync_config[zapier_webhook_url]"
                          value={@credentials["webhook_url"]}
                          placeholder="https://hooks.zapier.com/hooks/catch/..."
                          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        />
                      </div>
                      
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">
                          API Key (Optional)
                        </label>
                        <input
                          type="password"
                          name="sync_config[zapier_api_key]"
                          value={@credentials["api_key"]}
                          placeholder="Optional API key for authentication"
                          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                        />
                      </div>
                    </div>
                  </div>
                  
                  <!-- Security Notice -->
                  <div class="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-md">
                    <div class="flex">
                      <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                      </svg>
                      <div class="ml-3">
                        <p class="text-sm text-blue-700">
                          <strong>Security:</strong> All credentials are encrypted before storage and cannot be viewed after saving.
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
                
                <!-- Action Buttons -->
                <div class="flex justify-end space-x-3 pt-4 border-t border-gray-200">
                  <button
                    type="button"
                    phx-click="close"
                    phx-target={assigns[:myself]}
                    class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    Cancel
                  </button>
                  
                  <button
                    type="submit"
                    class="px-4 py-2 text-sm font-medium text-white bg-blue-600 border border-transparent rounded-md shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                  >
                    <%= if @action == :create, do: "Create Configuration", else: "Update Configuration" %>
                  </button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </div>
    
    <script>
      // Show/hide provider-specific credentials
      document.addEventListener('change', function(e) {
        if (e.target.name === 'sync_config[provider]') {
          const provider = e.target.value;
          
          // Hide all credential sections
          document.getElementById('airtable-credentials').style.display = 'none';
          document.getElementById('notion-credentials').style.display = 'none';
          document.getElementById('zapier-credentials').style.display = 'none';
          
          // Show selected provider credentials
          if (provider) {
            const credentialsSection = document.getElementById(provider + '-credentials');
            if (credentialsSection) {
              credentialsSection.style.display = 'block';
            }
          }
        }
      });
    </script>
    """
  end
end