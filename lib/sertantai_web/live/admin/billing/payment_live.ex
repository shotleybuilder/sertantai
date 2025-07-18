defmodule SertantaiWeb.Admin.Billing.PaymentLive do
  use SertantaiWeb, :live_view

  alias Sertantai.Billing
  alias Sertantai.Billing.Payment
  
  require Ash.Query
  import Ash.Expr

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Payment History")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Payment History")
    |> assign(:payment, nil)
    |> load_payments()
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    payment = Ash.get!(Payment, id, 
      load: [:customer, :subscription], 
      actor: socket.assigns.current_user
    )
    
    socket
    |> assign(:page_title, "Payment Details")
    |> assign(:payment, payment)
    |> load_payments()
  end

  defp load_payments(socket) do
    payments = Payment
      |> Ash.Query.load([:customer, :subscription])
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!(actor: socket.assigns.current_user)
    assign(socket, :payments, payments)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    payment = Ash.get!(Payment, id, actor: socket.assigns.current_user)
    
    case Ash.destroy(payment, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply, 
         socket
         |> put_flash(:info, "Payment deleted successfully")
         |> load_payments()}
      
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete payment: #{inspect(error)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full">
      <.header class="mb-6">
        <%= @page_title %>
      </.header>

      <%= if @payment do %>
        <div class="bg-white shadow rounded-lg p-6 mb-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Payment Details</h3>
          
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
            <div>
              <label class="block text-sm font-medium text-gray-500">Customer</label>
              <p class="mt-1 text-sm text-gray-900"><%= @payment.customer.email %></p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-500">Amount</label>
              <p class="mt-1 text-sm text-gray-900">$<%= @payment.amount %> <%= @payment.currency %></p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-500">Status</label>
              <p class="mt-1">
                <span class={[
                  "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                  payment_status_color(@payment.status)
                ]}>
                  <%= @payment.status %>
                </span>
              </p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-500">Payment Method</label>
              <p class="mt-1 text-sm text-gray-900"><%= @payment.payment_method || "N/A" %></p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-500">Stripe Payment Intent</label>
              <p class="mt-1 text-sm text-gray-900"><%= @payment.stripe_payment_intent_id || "N/A" %></p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-500">Stripe Invoice</label>
              <p class="mt-1 text-sm text-gray-900"><%= @payment.stripe_invoice_id || "N/A" %></p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-500">Processed At</label>
              <p class="mt-1 text-sm text-gray-900"><%= format_datetime(@payment.processed_at) %></p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-500">Created At</label>
              <p class="mt-1 text-sm text-gray-900"><%= format_datetime(@payment.inserted_at) %></p>
            </div>
          </div>

          <%= if @payment.description do %>
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-500">Description</label>
              <p class="mt-1 text-sm text-gray-900"><%= @payment.description %></p>
            </div>
          <% end %>

          <%= if @payment.failure_reason do %>
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-500">Failure Reason</label>
              <p class="mt-1 text-sm text-red-600"><%= @payment.failure_reason %></p>
            </div>
          <% end %>

          <%= if @payment.subscription do %>
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-500">Related Subscription</label>
              <p class="mt-1 text-sm text-gray-900">
                <%= @payment.subscription.plan.name %> (<%= @payment.subscription.status %>)
              </p>
            </div>
          <% end %>

          <div class="mt-6 flex space-x-3">
            <.link 
              patch={~p"/admin/billing/payments"}
              class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
            >
              Back to Payments
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
                  Date
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Customer
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Amount
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Method
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Description
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for payment <- @payments do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= format_date(payment.inserted_at) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900">
                      <%= payment.customer.email %>
                    </div>
                    <div class="text-sm text-gray-500">
                      <%= payment.customer.name %>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= payment.amount %> <%= payment.currency %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={[
                      "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                      payment_status_color(payment.status)
                    ]}>
                      <%= payment.status %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= payment.payment_method || "N/A" %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= truncate_string(payment.description, 30) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <.link 
                      patch={~p"/admin/billing/payments/#{payment.id}"}
                      class="text-blue-600 hover:text-blue-900 mr-4"
                    >
                      View
                    </.link>
                    
                    <button 
                      phx-click="delete"
                      phx-value-id={payment.id}
                      class="text-red-600 hover:text-red-900"
                      data-confirm="Are you sure you want to delete this payment record?"
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

  defp payment_status_color("succeeded"), do: "bg-green-100 text-green-800"
  defp payment_status_color("failed"), do: "bg-red-100 text-red-800"
  defp payment_status_color("pending"), do: "bg-yellow-100 text-yellow-800"
  defp payment_status_color("processing"), do: "bg-blue-100 text-blue-800"
  defp payment_status_color("canceled"), do: "bg-gray-100 text-gray-800"
  defp payment_status_color(_), do: "bg-gray-100 text-gray-800"

  defp format_date(nil), do: "N/A"
  defp format_date(date) do
    Calendar.strftime(date, "%Y-%m-%d")
  end

  defp format_datetime(nil), do: "N/A"
  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp truncate_string(nil, _), do: "N/A"
  defp truncate_string(string, max_length) do
    if String.length(string) <= max_length do
      string
    else
      String.slice(string, 0, max_length) <> "..."
    end
  end
end