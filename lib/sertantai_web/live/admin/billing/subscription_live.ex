defmodule SertantaiWeb.Admin.Billing.SubscriptionLive do
  use SertantaiWeb, :live_view

  alias Sertantai.Billing
  alias Sertantai.Billing.{Plan, Subscription, Customer}
  
  require Ash.Query
  import Ash.Expr

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Billing Subscriptions")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Billing Subscriptions")
    |> assign(:subscription, nil)
    |> load_data()
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    subscription = Ash.get!(Subscription, id, load: [:customer, :plan], actor: socket.assigns.current_user)
    
    socket
    |> assign(:page_title, "Subscription Details")
    |> assign(:subscription, subscription)
    |> load_data()
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Subscription")
    |> assign(:subscription, %Subscription{})
    |> load_data()
  end

  defp load_data(socket) do
    subscriptions = Ash.read!(Subscription, 
      load: [:customer, :plan], 
      actor: socket.assigns.current_user
    )
    
    plans = Plan
      |> Ash.Query.filter(active == true)
      |> Ash.read!(actor: socket.assigns.current_user)
    
    customers = Ash.read!(Customer, 
      load: [:user], 
      actor: socket.assigns.current_user
    )

    socket
    |> assign(:subscriptions, subscriptions)
    |> assign(:plans, plans)
    |> assign(:customers, customers)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    subscription = Ash.get!(Subscription, id, actor: socket.assigns.current_user)
    
    case Ash.destroy(subscription, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply, 
         socket
         |> put_flash(:info, "Subscription deleted successfully")
         |> load_data()}
      
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete subscription: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_event("cancel_subscription", %{"id" => id}, socket) do
    subscription = Ash.get!(Subscription, id, actor: socket.assigns.current_user)
    
    case Ash.update(subscription, %{cancel_at_period_end: true}, actor: socket.assigns.current_user) do
      {:ok, _updated_subscription} ->
        {:noreply, 
         socket
         |> put_flash(:info, "Subscription will be cancelled at the end of the current period")
         |> load_data()}
      
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel subscription: #{inspect(error)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <.header class="mb-6">
        <%= @page_title %>
        <:actions>
          <.link 
            patch={~p"/admin/billing/subscriptions/new"} 
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-plus" class="w-4 h-4 mr-2" />
            New Subscription
          </.link>
        </:actions>
      </.header>

      <div class="bg-white shadow rounded-lg overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Customer
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Plan
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Current Period
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Amount
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for subscription <- @subscriptions do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900">
                      <%= subscription.customer.email %>
                    </div>
                    <div class="text-sm text-gray-500">
                      <%= subscription.customer.name %>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm text-gray-900"><%= subscription.plan.name %></div>
                    <div class="text-sm text-gray-500"><%= subscription.plan.interval %></div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={[
                      "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                      status_color(subscription.status)
                    ]}>
                      <%= subscription.status %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= format_date(subscription.current_period_start) %> - 
                    <%= format_date(subscription.current_period_end) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    $<%= subscription.plan.amount %> / <%= subscription.plan.interval %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <.link 
                      patch={~p"/admin/billing/subscriptions/#{subscription.id}"}
                      class="text-blue-600 hover:text-blue-900 mr-4"
                    >
                      View
                    </.link>
                    
                    <%= if subscription.status == "active" and not subscription.cancel_at_period_end do %>
                      <button 
                        phx-click="cancel_subscription"
                        phx-value-id={subscription.id}
                        class="text-yellow-600 hover:text-yellow-900 mr-4"
                        data-confirm="Are you sure you want to cancel this subscription?"
                      >
                        Cancel
                      </button>
                    <% end %>
                    
                    <button 
                      phx-click="delete"
                      phx-value-id={subscription.id}
                      class="text-red-600 hover:text-red-900"
                      data-confirm="Are you sure you want to delete this subscription?"
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

  defp status_color("active"), do: "bg-green-100 text-green-800"
  defp status_color("canceled"), do: "bg-red-100 text-red-800"
  defp status_color("past_due"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("incomplete"), do: "bg-gray-100 text-gray-800"
  defp status_color("trialing"), do: "bg-blue-100 text-blue-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp format_date(nil), do: "N/A"
  defp format_date(date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end
end