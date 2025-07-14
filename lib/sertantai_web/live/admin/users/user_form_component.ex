defmodule SertantaiWeb.Admin.Users.UserFormComponent do
  @moduledoc """
  User form component for creating and editing users.
  
  Handles both user creation and editing with role-based permissions.
  """
  
  use SertantaiWeb, :live_component
  
  alias Sertantai.Accounts.User
  
  @impl true
  def update(%{user: user} = assigns, socket) do
    form = 
      if user do
        AshPhoenix.Form.for_update(user, :update, forms: [auto?: false])
      else
        AshPhoenix.Form.for_create(User, :register_with_password, forms: [auto?: false])
      end
    
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, form)
     |> assign(:action, if(user, do: :edit, else: :create))}
  end
  
  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, user_params)
    
    {:noreply, assign(socket, :form, form)}
  end
  
  def handle_event("save", %{"user" => user_params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, user_params)
    
    case AshPhoenix.Form.submit(form, params: user_params) do
      {:ok, _user} ->
        message = if socket.assigns.action == :create, do: "User created successfully", else: "User updated successfully"
        send(self(), {:"user_#{socket.assigns.action}d", message})
        {:noreply, socket}
      
      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end
  
  def handle_event("close", _params, socket) do
    send(self(), {:close_modal})
    {:noreply, socket}
  end
  
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto">
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <!-- Background overlay -->
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" phx-click="close"></div>
        
        <!-- Modal panel -->
        <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
          <div>
            <div class="mt-3 text-center sm:mt-0 sm:text-left">
              <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                <%= if @action == :create, do: "Create New User", else: "Edit User" %>
              </h3>
              
              <.form
                for={@form}
                phx-target={assigns[:myself]}
                phx-change="validate"
                phx-submit="save"
                class="space-y-4"
              >
                <!-- Email Field -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Email Address
                  </label>
                  <input
                    type="email"
                    name="user[email]"
                    value={AshPhoenix.Form.value(@form, :email)}
                    required
                    class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                  />
                  <%= if error = @form.errors[:email] do %>
                    <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                  <% end %>
                </div>
                
                <!-- First Name Field -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    First Name
                  </label>
                  <input
                    type="text"
                    name="user[first_name]"
                    value={AshPhoenix.Form.value(@form, :first_name)}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                  />
                  <%= if error = @form.errors[:first_name] do %>
                    <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                  <% end %>
                </div>
                
                <!-- Last Name Field -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Last Name
                  </label>
                  <input
                    type="text"
                    name="user[last_name]"
                    value={AshPhoenix.Form.value(@form, :last_name)}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                  />
                  <%= if error = @form.errors[:last_name] do %>
                    <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                  <% end %>
                </div>
                
                <!-- Role Field (Admin only) -->
                <%= if @current_user.role == :admin do %>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Role
                    </label>
                    <select
                      name="user[role]"
                      value={AshPhoenix.Form.value(@form, :role)}
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    >
                      <option value="guest">Guest</option>
                      <option value="member">Member</option>
                      <option value="professional">Professional</option>
                      <option value="support">Support</option>
                      <option value="admin">Admin</option>
                    </select>
                    <%= if error = @form.errors[:role] do %>
                      <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                    <% end %>
                  </div>
                <% end %>
                
                <!-- Timezone Field -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">
                    Timezone
                  </label>
                  <select
                    name="user[timezone]"
                    value={AshPhoenix.Form.value(@form, :timezone) || "UTC"}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                  >
                    <option value="UTC">UTC</option>
                    <option value="America/New_York">Eastern Time</option>
                    <option value="America/Chicago">Central Time</option>
                    <option value="America/Denver">Mountain Time</option>
                    <option value="America/Los_Angeles">Pacific Time</option>
                    <option value="Europe/London">London</option>
                    <option value="Europe/Paris">Paris</option>
                    <option value="Asia/Tokyo">Tokyo</option>
                    <option value="Australia/Sydney">Sydney</option>
                  </select>
                  <%= if error = @form.errors[:timezone] do %>
                    <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                  <% end %>
                </div>
                
                <!-- Password Fields (Create only) -->
                <%= if @action == :create do %>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Password
                    </label>
                    <input
                      type="password"
                      name="user[password]"
                      required
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    />
                    <%= if error = @form.errors[:password] do %>
                      <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                    <% end %>
                  </div>
                  
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Confirm Password
                    </label>
                    <input
                      type="password"
                      name="user[password_confirmation]"
                      required
                      class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    />
                    <%= if error = @form.errors[:password_confirmation] do %>
                      <p class="mt-1 text-sm text-red-600"><%= elem(error, 0) %></p>
                    <% end %>
                  </div>
                <% end %>
                
                <!-- Action Buttons -->
                <div class="flex justify-end space-x-3 pt-4">
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
                    <%= if @action == :create, do: "Create User", else: "Update User" %>
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