defmodule SertantaiWeb.Admin.Billing.PlanLive do
  use SertantaiWeb, :live_view

  alias Sertantai.Billing
  alias Sertantai.Billing.Plan
  alias AshPhoenix.Form
  
  require Ash.Query
  import Ash.Expr

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Billing Plans")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Billing Plans")
    |> assign(:plan, nil)
    |> assign(:form, nil)
    |> load_plans()
  end

  defp apply_action(socket, :new, _params) do
    form = Form.for_create(Plan, :create, forms: [auto?: false])
    
    socket
    |> assign(:page_title, "New Plan")
    |> assign(:plan, nil)
    |> assign(:form, form)
    |> load_plans()
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    plan = Ash.get!(Plan, id, actor: socket.assigns.current_user)
    form = Form.for_update(plan, :update, forms: [auto?: false])
    
    socket
    |> assign(:page_title, "Edit Plan")
    |> assign(:plan, plan)
    |> assign(:form, form)
    |> load_plans()
  end

  defp load_plans(socket) do
    plans = Ash.read!(Plan, actor: socket.assigns.current_user)
    assign(socket, :plans, plans)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    plan = Ash.get!(Plan, id, actor: socket.assigns.current_user)
    
    case Ash.destroy(plan, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply, 
         socket
         |> put_flash(:info, "Plan deleted successfully")
         |> load_plans()}
      
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete plan: #{inspect(error)}")}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _plan} ->
        {:noreply,
         socket
         |> put_flash(:info, "Plan saved successfully")
         |> push_patch(to: ~p"/admin/billing/plans")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    plan = Ash.get!(Plan, id, actor: socket.assigns.current_user)
    
    case Ash.update(plan, %{active: !plan.active}, actor: socket.assigns.current_user) do
      {:ok, _updated_plan} ->
        {:noreply, 
         socket
         |> put_flash(:info, "Plan status updated")
         |> load_plans()}
      
      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Failed to update plan: #{inspect(error)}")}
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
            patch={~p"/admin/billing/plans/new"} 
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-plus" class="w-4 h-4 mr-2" />
            New Plan
          </.link>
        </:actions>
      </.header>

      <%= if @form do %>
        <div class="bg-white shadow rounded-lg p-6 mb-6">
          <.simple_form for={@form} phx-change="validate" phx-submit="save">
            <.input field={@form[:name]} type="text" label="Plan Name" />
            <.input field={@form[:stripe_price_id]} type="text" label="Stripe Price ID" />
            <.input field={@form[:amount]} type="number" label="Amount" step="0.01" />
            <.input field={@form[:currency]} type="text" label="Currency" />
            <.input 
              field={@form[:interval]} 
              type="select" 
              label="Billing Interval"
              options={[{"Monthly", "month"}, {"Yearly", "year"}]}
            />
            <.input field={@form[:user_role]} type="text" label="User Role" />
            <.input field={@form[:trial_days]} type="number" label="Trial Days" />
            <.input field={@form[:active]} type="checkbox" label="Active" />
            
            <div class="space-y-2">
              <label class="block text-sm font-medium text-gray-700">Features</label>
              <.input 
                field={@form[:features]} 
                type="textarea" 
                label="Features (one per line)"
                rows="4"
              />
            </div>

            <:actions>
              <.button type="submit" phx-disable-with="Saving...">
                <%= if @plan, do: "Update Plan", else: "Create Plan" %>
              </.button>
              <.link patch={~p"/admin/billing/plans"} class="ml-3 text-gray-500 hover:text-gray-700">
                Cancel
              </.link>
            </:actions>
          </.simple_form>
        </div>
      <% end %>

      <div class="bg-white shadow rounded-lg overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Name
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Amount
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Interval
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Role
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for plan <- @plans do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="text-sm font-medium text-gray-900"><%= plan.name %></div>
                    <div class="text-sm text-gray-500"><%= plan.stripe_price_id %></div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    $<%= plan.amount %> <%= plan.currency %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= plan.interval %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <%= plan.user_role %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={[
                      "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                      if(plan.active, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800")
                    ]}>
                      <%= if plan.active, do: "Active", else: "Inactive" %>
                    </span>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <.link 
                      patch={~p"/admin/billing/plans/#{plan.id}/edit"}
                      class="text-blue-600 hover:text-blue-900 mr-4"
                    >
                      Edit
                    </.link>
                    
                    <button 
                      phx-click="toggle_active"
                      phx-value-id={plan.id}
                      class="text-yellow-600 hover:text-yellow-900 mr-4"
                    >
                      <%= if plan.active, do: "Deactivate", else: "Activate" %>
                    </button>
                    
                    <button 
                      phx-click="delete"
                      phx-value-id={plan.id}
                      class="text-red-600 hover:text-red-900"
                      data-confirm="Are you sure you want to delete this plan?"
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
end