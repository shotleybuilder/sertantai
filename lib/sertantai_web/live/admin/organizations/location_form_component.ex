defmodule SertantaiWeb.Admin.Organizations.LocationFormComponent do
  @moduledoc """
  Location form component for creating and editing organization locations.
  
  Handles location creation and editing with proper validation
  and Ash Framework integration.
  """
  
  use SertantaiWeb, :live_component
  
  alias Sertantai.Organizations.OrganizationLocation
  
  @impl true
  def update(%{location: location, organization: _organization} = assigns, socket) do
    form = 
      if location do
        AshPhoenix.Form.for_update(location, :update, forms: [auto?: false])
      else
        AshPhoenix.Form.for_create(OrganizationLocation, :create, forms: [auto?: false])
      end
    
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, form)
     |> assign(:action, if(location, do: :edit, else: :create))}
  end
  
  @impl true
  def handle_event("validate", %{"location" => location_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, location_params)
    
    {:noreply, assign(socket, :form, form)}
  end
  
  def handle_event("save", %{"location" => location_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, location_params)
    
    # Build address map from form parameters
    address = %{
      "street" => location_params["address_street"],
      "city" => location_params["address_city"],
      "region" => location_params["address_region"],
      "postcode" => location_params["postcode"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
    
    # Build industry activities array
    industry_activities = 
      location_params["industry_activities"]
      |> split_comma_separated()
    
    # Build params with structured data
    structured_params = 
      location_params
      |> Map.put("address", address)
      |> Map.put("industry_activities", industry_activities)
      |> Map.put("employee_count", parse_integer(location_params["employee_count"]))
      |> Map.put("annual_revenue", parse_decimal(location_params["annual_revenue"]))
      |> Map.put("is_primary_location", location_params["is_primary_location"] == "true")
      |> Map.put("established_date", parse_date(location_params["established_date"]))
    
    case socket.assigns.action do
      :create ->
        # Add organization_id for new locations
        params_with_org = Map.put(structured_params, "organization_id", socket.assigns.organization.id)
        
        case AshPhoenix.Form.submit(form, params: params_with_org) do
          {:ok, _location} ->
            message = "Location created successfully"
            send(self(), {:location_created, message})
            {:noreply, socket}
          
          {:error, form} ->
            {:noreply, assign(socket, :form, form)}
        end
      
      :edit ->
        case AshPhoenix.Form.submit(form, params: structured_params) do
          {:ok, _location} ->
            message = "Location updated successfully"
            send(self(), {:location_updated, message})
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
  
  # Helper functions
  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil
  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end
  defp parse_integer(value) when is_integer(value), do: value
  
  defp parse_decimal(nil), do: nil
  defp parse_decimal(""), do: nil
  defp parse_decimal(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> nil
    end
  end
  defp parse_decimal(value), do: value
  
  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end
  defp parse_date(value), do: value
  
  defp split_comma_separated(nil), do: []
  defp split_comma_separated(""), do: []
  defp split_comma_separated(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
  defp split_comma_separated(value) when is_list(value), do: value
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto">
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <!-- Background overlay -->
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" phx-click="close"></div>
        
        <!-- Modal panel -->
        <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full sm:p-6">
          <div>
            <div class="mt-3 text-center sm:mt-0 sm:text-left">
              <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                <%= if @action == :create, do: "Add New Location", else: "Edit Location" %>
              </h3>
              
              <.form
                for={@form}
                phx-target={assigns[:myself]}
                phx-change="validate"
                phx-submit="save"
                class="space-y-6"
              >
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <!-- Left Column -->
                  <div class="space-y-4">
                    <!-- Location Name -->
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Location Name *
                      </label>
                      <input
                        type="text"
                        name="location[location_name]"
                        value={AshPhoenix.Form.value(@form, :location_name)}
                        required
                        class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      />
                      <%= if error = @form.errors[:location_name] do %>
                        <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                      <% end %>
                    </div>
                    
                    <!-- Location Type -->
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Location Type
                      </label>
                      <select
                        name="location[location_type]"
                        value={AshPhoenix.Form.value(@form, :location_type) || "branch_office"}
                        class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      >
                        <option value="headquarters">Headquarters</option>
                        <option value="branch_office">Branch Office</option>
                        <option value="warehouse">Warehouse</option>
                        <option value="manufacturing_site">Manufacturing Site</option>
                        <option value="retail_outlet">Retail Outlet</option>
                        <option value="project_site">Project Site</option>
                        <option value="temporary_location">Temporary Location</option>
                        <option value="home_office">Home Office</option>
                        <option value="other">Other</option>
                      </select>
                    </div>
                    
                    <!-- Geographic Region -->
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Geographic Region *
                      </label>
                      <select
                        name="location[geographic_region]"
                        value={AshPhoenix.Form.value(@form, :geographic_region)}
                        required
                        class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      >
                        <option value="">Select region...</option>
                        <option value="england">England</option>
                        <option value="scotland">Scotland</option>
                        <option value="wales">Wales</option>
                        <option value="northern_ireland">Northern Ireland</option>
                        <option value="international">International</option>
                      </select>
                      <%= if error = @form.errors[:geographic_region] do %>
                        <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                      <% end %>
                    </div>
                    
                    <!-- Operational Status -->
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Operational Status
                      </label>
                      <select
                        name="location[operational_status]"
                        value={AshPhoenix.Form.value(@form, :operational_status) || "active"}
                        class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      >
                        <option value="active">Active</option>
                        <option value="inactive">Inactive</option>
                        <option value="seasonal">Seasonal</option>
                        <option value="under_construction">Under Construction</option>
                        <option value="closing">Closing</option>
                      </select>
                    </div>
                    
                    <!-- Employee Count -->
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Employee Count
                      </label>
                      <input
                        type="number"
                        name="location[employee_count]"
                        value={AshPhoenix.Form.value(@form, :employee_count)}
                        min="0"
                        class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      />
                    </div>
                    
                    <!-- Annual Revenue -->
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Annual Revenue (£)
                      </label>
                      <input
                        type="number"
                        name="location[annual_revenue]"
                        value={AshPhoenix.Form.value(@form, :annual_revenue)}
                        min="0"
                        step="0.01"
                        class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      />
                    </div>
                  </div>
                  
                  <!-- Right Column -->
                  <div class="space-y-4">
                    <!-- Address Fields -->
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Street Address *
                      </label>
                      <input
                        type="text"
                        name="location[address_street]"
                        value={get_in(AshPhoenix.Form.value(@form, :address) || %{}, ["street"])}
                        required
                        class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      />
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        City *
                      </label>
                      <input
                        type="text"
                        name="location[address_city]"
                        value={get_in(AshPhoenix.Form.value(@form, :address) || %{}, ["city"])}
                        required
                        class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      />
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Region/County
                      </label>
                      <input
                        type="text"
                        name="location[address_region]"
                        value={get_in(AshPhoenix.Form.value(@form, :address) || %{}, ["region"])}
                        class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      />
                    </div>
                    
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Postcode
                      </label>
                      <input
                        type="text"
                        name="location[postcode]"
                        value={AshPhoenix.Form.value(@form, :postcode)}
                        class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      />
                    </div>
                    
                    <!-- Local Authority -->
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Local Authority
                      </label>
                      <input
                        type="text"
                        name="location[local_authority]"
                        value={AshPhoenix.Form.value(@form, :local_authority)}
                        class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      />
                    </div>
                    
                    <!-- Established Date -->
                    <div>
                      <label class="block text-sm font-medium text-gray-700 mb-1">
                        Established Date
                      </label>
                      <input
                        type="date"
                        name="location[established_date]"
                        value={AshPhoenix.Form.value(@form, :established_date)}
                        class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      />
                    </div>
                  </div>
                </div>
                
                <!-- Full Width Fields -->
                <div class="space-y-4">
                  <!-- Industry Activities -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Industry Activities
                    </label>
                    <input
                      type="text"
                      name="location[industry_activities]"
                      value={Enum.join(AshPhoenix.Form.value(@form, :industry_activities) || [], ", ")}
                      placeholder="e.g., construction, civil engineering, project management"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    />
                    <p class="mt-1 text-sm text-gray-500">Separate multiple activities with commas</p>
                  </div>
                  
                  <!-- Compliance Notes -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Compliance Notes
                    </label>
                    <textarea
                      name="location[compliance_notes]"
                      rows="3"
                      value={AshPhoenix.Form.value(@form, :compliance_notes)}
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Any special compliance considerations for this location..."
                    ></textarea>
                  </div>
                  
                  <!-- Primary Location Checkbox -->
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      name="location[is_primary_location]"
                      value="true"
                      checked={AshPhoenix.Form.value(@form, :is_primary_location)}
                      class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                    />
                    <label class="ml-2 block text-sm text-gray-900">
                      Mark as primary location for this organization
                    </label>
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
                    <%= if @action == :create, do: "Add Location", else: "Update Location" %>
                  </button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end