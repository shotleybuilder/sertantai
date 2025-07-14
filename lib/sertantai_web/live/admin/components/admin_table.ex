defmodule SertantaiWeb.Admin.Components.AdminTable do
  @moduledoc """
  Reusable admin table component for displaying data in admin interface.
  
  Provides consistent styling, pagination, and interactive features
  for all admin data tables.
  """
  
  use Phoenix.Component
  
  @doc """
  Renders an admin table with consistent styling and functionality.
  
  ## Examples
  
      <.admin_table
        id="users-table"
        rows={@users}
      >
        <:col :let={user} label="Email"><%= user.email %></:col>
        <:col :let={user} label="Role">
          <.role_badge role={user.role} />
        </:col>
        <:col :let={user} label="Created">
          <%= Calendar.strftime(user.inserted_at, "%Y-%m-%d") %>
        </:col>
      </.admin_table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_click, :any, default: nil
  attr :row_item, :any, default: &Function.identity/1, doc: "function to map each row before calling the :col and :action slots"
  
  slot :col, required: true do
    attr :label, :string
    attr :sortable, :boolean
  end
  
  slot :action, doc: "the slot for showing user actions in the last table column"
  
  def admin_table(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg overflow-hidden">
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th
                :for={col <- @col}
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                <%= col[:label] %>
              </th>
              <th :if={@action != []} class="relative px-6 py-3">
                <span class="sr-only">Actions</span>
              </th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr
              :for={row <- @rows}
              id={@id && "#{@id}-#{Phoenix.Param.to_param(row)}"}
              class={[
                "hover:bg-gray-50",
                @row_click && "cursor-pointer"
              ]}
              phx-click={@row_click && @row_click.(@row_item.(row))}
            >
              <td
                :for={{col, i} <- Enum.with_index(@col)}
                class={[
                  "px-6 py-4 whitespace-nowrap text-sm text-gray-900",
                  i == 0 && "font-medium"
                ]}
              >
                <%= render_slot(col, @row_item.(row)) %>
              </td>
              <td :if={@action != []} class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                <%= for action <- @action do %>
                  <%= render_slot(action, @row_item.(row)) %>
                <% end %>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      
      <!-- Empty state -->
      <div :if={@rows == []} class="text-center py-12">
        <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No data found</h3>
        <p class="mt-1 text-sm text-gray-500">Get started by creating a new item.</p>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders a role badge with appropriate styling based on role.
  """
  attr :role, :atom, required: true
  
  def role_badge(assigns) do
    {color_class, text} = case assigns.role do
      :admin -> {"bg-red-100 text-red-800", "Admin"}
      :support -> {"bg-yellow-100 text-yellow-800", "Support"}
      :professional -> {"bg-blue-100 text-blue-800", "Professional"}
      :member -> {"bg-green-100 text-green-800", "Member"}
      :guest -> {"bg-gray-100 text-gray-800", "Guest"}
      _ -> {"bg-gray-100 text-gray-800", String.capitalize(to_string(assigns.role))}
    end
    
    assigns = assign(assigns, :color_class, color_class) |> assign(:text, text)
    
    ~H"""
    <span class={["inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium", @color_class]}>
      <%= @text %>
    </span>
    """
  end
  
  @doc """
  Renders a status badge with appropriate styling.
  """
  attr :status, :atom, required: true
  attr :label, :string, default: nil
  
  def status_badge(assigns) do
    {color_class, text} = case assigns.status do
      :active -> {"bg-green-100 text-green-800", "Active"}
      :inactive -> {"bg-red-100 text-red-800", "Inactive"}
      :pending -> {"bg-yellow-100 text-yellow-800", "Pending"}
      :suspended -> {"bg-red-100 text-red-800", "Suspended"}
      _ -> {"bg-gray-100 text-gray-800", String.capitalize(to_string(assigns.status))}
    end
    
    display_text = assigns.label || text
    assigns = assign(assigns, :color_class, color_class) |> assign(:display_text, display_text)
    
    ~H"""
    <span class={["inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium", @color_class]}>
      <%= @display_text %>
    </span>
    """
  end
  
  @doc """
  Renders action buttons for table rows.
  """
  attr :actions, :list, required: true
  
  def action_buttons(assigns) do
    ~H"""
    <div class="flex space-x-2">
      <%= for action <- @actions do %>
        <.link
          patch={action[:to]}
          class={[
            "text-sm font-medium hover:underline",
            action[:class] || "text-blue-600 hover:text-blue-900"
          ]}
        >
          <%= action[:label] %>
        </.link>
      <% end %>
    </div>
    """
  end
end