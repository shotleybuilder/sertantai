defmodule SertantaiWeb.Admin.Billing.CustomerLive do
  use SertantaiWeb, :live_view

  alias Sertantai.Billing
  alias Sertantai.Billing.Customer
  alias AshPhoenix.Form
  
  require Ash.Query
  import Ash.Expr

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Billing Customers")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Billing Customers")
    |> assign(:customer, nil)
    |> load_customers()
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    customer = Ash.get!(Customer, id, 
      load: [:user, :subscriptions, :payments], 
      actor: socket.assigns.current_user
    )
    
    socket
    |> assign(:page_title, "Customer Details")
    |> assign(:customer, customer)
    |> load_customers()
  end

  defp load_customers(socket) do
    customers = Ash.read!(Customer, 
      load: [:user, :subscriptions], 
      actor: socket.assigns.current_user
    )
    assign(socket, :customers, customers)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    customer = Ash.get!(Customer, id, actor: socket.assigns.current_user)
    
    case Ash.destroy(customer, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply, 
         socket
         |> put_flash(:info, "Customer deleted successfully")
         |> load_customers()}
      
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete customer: #{inspect(error)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <.header class="mb-6">
        <%= @page_title %>
      </.header>

      <%= if @customer do %>
        <div class="bg-white shadow rounded-lg p-6 mb-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Customer Details</h3>
          
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
            <div>
              <label class="block text-sm font-medium text-gray-500">Name</label>
              <p class="mt-1 text-sm text-gray-900"><%= @customer.name || "N/A" %></p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-500">Email</label>
              <p class="mt-1 text-sm text-gray-900"><%= @customer.email %></p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-500">Company</label>
              <p class="mt-1 text-sm text-gray-900"><%= @customer.company || "N/A" %></p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-500">Phone</label>
              <p class="mt-1 text-sm text-gray-900"><%= @customer.phone || "N/A" %></p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-500">Stripe Customer ID</label>
              <p class="mt-1 text-sm text-gray-900"><%= @customer.stripe_customer_id %></p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-500">User Account</label>
              <p class="mt-1 text-sm text-gray-900"><%= @customer.user.email %></p>
            </div>
          </div>

          <%= if @customer.address do %>
            <div class="mb-6">
              <label class="block text-sm font-medium text-gray-500">Address</label>
              <div class="mt-1 text-sm text-gray-900">
                <%= for {key, value} <- @customer.address, value != nil do %>
                  <div><%= String.capitalize(to_string(key)) %>: <%= value %></div>
                <% end %>
              </div>
            </div>
          <% end %>

          <div class="border-t pt-6">
            <h4 class="text-md font-medium text-gray-900 mb-4">Subscriptions</h4>
            <%= if length(@customer.subscriptions) > 0 do %>
              <div class="space-y-2">
                <%= for subscription <- @customer.subscriptions do %>
                  <div class="flex items-center justify-between p-3 bg-gray-50 rounded">
                    <div>
                      <span class="font-medium"><%= subscription.plan.name %></span>
                      <span class="text-sm text-gray-500 ml-2">(<%= subscription.status %>)</span>
                    </div>
                    <div class="text-sm text-gray-500">
                      $<%= subscription.plan.amount %> / <%= subscription.plan.interval %>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <p class="text-gray-500">No subscriptions found</p>
            <% end %>
          </div>

          <div class="mt-6 flex space-x-3">
            <.link 
              patch={~p"/admin/billing/customers"}
              class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
            >
              Back to Customers
            </.link>
          </div>
        </div>
      <% end %>

      <div class="bg-white shadow rounded-lg overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Customer
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  User Account
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Subscriptions
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Stripe ID
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Created
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for customer <- @customers do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900">
                      <%= customer.name || "N/A" %>
                    </div>
                    <div class="text-sm text-gray-500">
                      <%= customer.email %>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= customer.user.email %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= length(customer.subscriptions) %> subscription(s)
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= customer.stripe_customer_id %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= format_date(customer.inserted_at) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <.link 
                      patch={~p"/admin/billing/customers/#{customer.id}"}
                      class="text-blue-600 hover:text-blue-900 mr-4"
                    >
                      View
                    </.link>
                    
                    <button 
                      phx-click="delete"
                      phx-value-id={customer.id}
                      class="text-red-600 hover:text-red-900"
                      data-confirm="Are you sure you want to delete this customer?"
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp format_date(nil), do: "N/A"
  defp format_date(date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end
end