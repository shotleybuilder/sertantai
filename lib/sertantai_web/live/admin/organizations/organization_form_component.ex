defmodule SertantaiWeb.Admin.Organizations.OrganizationFormComponent do
  @moduledoc """
  Organization form component for creating and editing organizations.
  
  Handles both organization creation and editing with proper
  Ash Framework integration and validation.
  """
  
  use SertantaiWeb, :live_component
  
  alias Sertantai.Organizations.Organization
  
  @impl true
  def update(%{organization: organization} = assigns, socket) do
    form = 
      if organization do
        AshPhoenix.Form.for_update(organization, :update, forms: [auto?: false])
      else
        AshPhoenix.Form.for_create(Organization, :create, forms: [auto?: false])
      end
    
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, form)
     |> assign(:action, if(organization, do: :edit, else: :create))}
  end
  
  @impl true
  def handle_event("validate", %{"organization" => org_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, org_params)
    
    {:noreply, assign(socket, :form, form)}
  end
  
  def handle_event("save", %{"organization" => org_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, org_params)
    
    # Build organization attributes for core profile
    organization_attrs = %{
      "organization_name" => org_params["organization_name"],
      "organization_type" => org_params["organization_type"],
      "registration_number" => org_params["registration_number"],
      "headquarters_region" => org_params["headquarters_region"],
      "total_employees" => parse_integer(org_params["total_employees"]),
      "primary_sic_code" => org_params["primary_sic_code"],
      "industry_sector" => org_params["industry_sector"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
    
    # Add organization_attrs argument for core profile building
    params_with_attrs = Map.put(org_params, "organization_attrs", organization_attrs)
    
    case socket.assigns.action do
      :create ->
        # Add created_by_user_id for new organizations
        params_with_user = Map.put(params_with_attrs, "created_by_user_id", socket.assigns.current_user.id)
        
        case AshPhoenix.Form.submit(form, params: params_with_user) do
          {:ok, _organization} ->
            message = "Organization created successfully"
            send(self(), {:organization_created, message})
            {:noreply, socket}
          
          {:error, form} ->
            {:noreply, assign(socket, :form, form)}
        end
      
      :edit ->
        case AshPhoenix.Form.submit(form, params: params_with_attrs) do
          {:ok, _organization} ->
            message = "Organization updated successfully"
            send(self(), {:organization_updated, message})
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
  
  # Helper function to parse integer fields
  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil
  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end
  defp parse_integer(value) when is_integer(value), do: value
  
  @impl true
  def render(assigns) do
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
                <%= if @action == :create, do: "Create New Organization", else: "Edit Organization" %>
              </h3>
              
              <.form
                for={@form}
                phx-target={assigns[:myself]}
                phx-change="validate"
                phx-submit="save"
                class="space-y-6"
              >
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <!-- Organization Name Field -->
                  <div class="md:col-span-2">
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Organization Name *
                    </label>
                    <input
                      type="text"
                      name="organization[organization_name]"
                      value={AshPhoenix.Form.value(@form, :organization_name)}
                      required
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    />
                    <%= if error = @form.errors[:organization_name] do %>
                      <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                    <% end %>
                  </div>
                  
                  <!-- Email Domain Field -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Email Domain *
                    </label>
                    <input
                      type="text"
                      name="organization[email_domain]"
                      value={AshPhoenix.Form.value(@form, :email_domain)}
                      placeholder="example.com"
                      required
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    />
                    <%= if error = @form.errors[:email_domain] do %>
                      <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                    <% end %>
                  </div>
                  
                  <!-- Organization Type Field -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Organization Type *
                    </label>
                    <select
                      name="organization[organization_type]"
                      value={@form.params["organization_type"]}
                      required
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="">Select type...</option>
                      <option value="limited_company">Limited Company</option>
                      <option value="partnership">Partnership</option>
                      <option value="sole_trader">Sole Trader</option>
                      <option value="charity">Charity</option>
                      <option value="public_sector">Public Sector</option>
                      <option value="other">Other</option>
                    </select>
                  </div>
                  
                  <!-- Registration Number Field -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Registration Number
                    </label>
                    <input
                      type="text"
                      name="organization[registration_number]"
                      value={@form.params["registration_number"]}
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    />
                  </div>
                  
                  <!-- Headquarters Region Field -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Headquarters Region *
                    </label>
                    <select
                      name="organization[headquarters_region]"
                      value={@form.params["headquarters_region"]}
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
                  </div>
                  
                  <!-- Total Employees Field -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Total Employees
                    </label>
                    <input
                      type="number"
                      name="organization[total_employees]"
                      value={@form.params["total_employees"]}
                      min="1"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    />
                  </div>
                  
                  <!-- Primary SIC Code Field -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Primary SIC Code
                    </label>
                    <input
                      type="text"
                      name="organization[primary_sic_code]"
                      value={@form.params["primary_sic_code"]}
                      placeholder="e.g., 41201"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    />
                  </div>
                  
                  <!-- Industry Sector Field -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Industry Sector *
                    </label>
                    <select
                      name="organization[industry_sector]"
                      value={@form.params["industry_sector"]}
                      required
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="">Select sector...</option>
                      <option value="construction">Construction</option>
                      <option value="manufacturing">Manufacturing</option>
                      <option value="retail">Retail</option>
                      <option value="hospitality">Hospitality</option>
                      <option value="healthcare">Healthcare</option>
                      <option value="education">Education</option>
                      <option value="finance">Finance</option>
                      <option value="technology">Technology</option>
                      <option value="transport">Transport</option>
                      <option value="agriculture">Agriculture</option>
                      <option value="energy">Energy</option>
                      <option value="professional_services">Professional Services</option>
                      <option value="public_sector">Public Sector</option>
                      <option value="other">Other</option>
                    </select>
                  </div>
                  
                  <!-- Verified Status (Admin only) -->
                  <%= if @current_user.role == :admin do %>
                    <div class="md:col-span-2">
                      <label class="flex items-center">
                        <input
                          type="checkbox"
                          name="organization[verified]"
                          value="true"
                          checked={AshPhoenix.Form.value(@form, :verified)}
                          class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                        />
                        <span class="ml-2 text-sm font-medium text-gray-700">
                          Mark as verified
                        </span>
                      </label>
                    </div>
                  <% end %>
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
                    <%= if @action == :create, do: "Create Organization", else: "Update Organization" %>
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