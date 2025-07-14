defmodule SertantaiWeb.Admin.Components.AdminModal do
  @moduledoc """
  Reusable admin modal component for dialogs and overlays.
  
  Provides consistent modal styling and behavior for admin interface.
  """
  
  use Phoenix.Component
  # import Phoenix.LiveView.JS  # Functions available via alias
  alias Phoenix.LiveView.JS
  
  @doc """
  Renders an admin modal dialog.
  
  ## Examples
  
      <.admin_modal id="confirm-delete" show={@show_delete_modal}>
        <:title>Delete User</:title>
        <:body>
          Are you sure you want to delete this user? This action cannot be undone.
        </:body>
        <:footer>
          <button 
            type="button" 
            phx-click={JS.push("cancel-delete")}
            class="btn btn-secondary"
          >
            Cancel
          </button>
          <button 
            type="button" 
            phx-click={JS.push("confirm-delete")}
            class="btn btn-danger"
          >
            Delete
          </button>
        </:footer>
      </.admin_modal>
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :size, :string, default: "md", values: ["sm", "md", "lg", "xl"]
  attr :on_cancel, :any, default: nil
  
  slot :title, required: true
  slot :body, required: true  
  slot :footer
  
  def admin_modal(assigns) do
    size_classes = case assigns.size do
      "sm" -> "max-w-md"
      "md" -> "max-w-lg"
      "lg" -> "max-w-2xl"
      "xl" -> "max-w-4xl"
    end
    
    assigns = assign(assigns, :size_classes, size_classes)
    
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <!-- Background backdrop -->
      <div 
        id={"#{@id}-bg"}
        class="fixed inset-0 bg-black bg-opacity-50 transition-opacity"
        aria-hidden="true"
      >
      </div>
      
      <!-- Modal dialog -->
      <div class="fixed inset-0 z-10 overflow-y-auto">
        <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
          <div
            id={"#{@id}-container"}
            class={[
              "relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl transition-all sm:my-8 sm:w-full",
              @size_classes
            ]}
            phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
            phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
            phx-key="escape"
          >
            <!-- Modal header -->
            <div class="bg-white px-4 pb-4 pt-5 sm:p-6 sm:pb-4">
              <div class="sm:flex sm:items-start">
                <div class="mt-3 text-center sm:ml-4 sm:mt-0 sm:text-left w-full">
                  <h3 class="text-lg font-semibold leading-6 text-gray-900" id={"#{@id}-title"}>
                    <%= render_slot(@title) %>
                  </h3>
                  
                  <!-- Modal body -->
                  <div class="mt-4">
                    <%= render_slot(@body) %>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- Modal footer -->
            <%= if @footer != [] do %>
              <div class="bg-gray-50 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
                <%= render_slot(@footer) %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Shows the modal by adding show class and focus.
  """
  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "##{id}-container",
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-container")
  end
  
  @doc """
  Hides the modal by removing show class.
  """
  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "##{id}-container",
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
  
  @doc """
  Renders a confirmation modal for dangerous actions.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :confirm_text, :string, default: "Confirm"
  attr :cancel_text, :string, default: "Cancel"
  attr :on_confirm, :any, required: true
  attr :on_cancel, :any, required: true
  attr :danger, :boolean, default: false
  
  def confirmation_modal(assigns) do
    ~H"""
    <.admin_modal id={@id} show={@show} on_cancel={@on_cancel}>
      <:title><%= @title %></:title>
      <:body>
        <div class="mt-2">
          <p class="text-sm text-gray-500">
            <%= @message %>
          </p>
        </div>
      </:body>
      <:footer>
        <button
          type="button"
          phx-click={@on_cancel}
          class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:mt-0 sm:w-auto"
        >
          <%= @cancel_text %>
        </button>
        
        <button
          type="button"
          phx-click={@on_confirm}
          class={[
            "inline-flex w-full justify-center rounded-md px-3 py-2 text-sm font-semibold text-white shadow-sm sm:ml-3 sm:w-auto",
            @danger && "bg-red-600 hover:bg-red-500" || "bg-blue-600 hover:bg-blue-500"
          ]}
        >
          <%= @confirm_text %>
        </button>
      </:footer>
    </.admin_modal>
    """
  end
  
  @doc """
  Renders a simple alert modal for notifications.
  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :type, :string, default: "info", values: ["success", "error", "warning", "info"]
  attr :on_close, :any, required: true
  
  def alert_modal(assigns) do
    {icon_color, icon_bg, icon_svg} = case assigns.type do
      "success" -> 
        {"text-green-600", "bg-green-100", 
         ~s(<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />)}
      "error" ->
        {"text-red-600", "bg-red-100",
         ~s(<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />)}
      "warning" ->
        {"text-yellow-600", "bg-yellow-100",
         ~s(<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16c-.77.833.192 2.5 1.732 2.5z" />)}
      "info" ->
        {"text-blue-600", "bg-blue-100",
         ~s(<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />)}
    end
    
    assigns = assign(assigns, :icon_color, icon_color) 
              |> assign(:icon_bg, icon_bg) 
              |> assign(:icon_svg, icon_svg)
    
    ~H"""
    <.admin_modal id={@id} show={@show} on_cancel={@on_close}>
      <:title><%= @title %></:title>
      <:body>
        <div class="sm:flex sm:items-start">
          <div class={["mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full sm:mx-0 sm:h-10 sm:w-10", @icon_bg]}>
            <svg class={["h-6 w-6", @icon_color]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <%= Phoenix.HTML.raw(@icon_svg) %>
            </svg>
          </div>
          <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
            <div class="mt-2">
              <p class="text-sm text-gray-500">
                <%= @message %>
              </p>
            </div>
          </div>
        </div>
      </:body>
      <:footer>
        <button
          type="button"
          phx-click={@on_close}
          class="inline-flex w-full justify-center rounded-md bg-blue-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-blue-500 sm:w-auto"
        >
          OK
        </button>
      </:footer>
    </.admin_modal>
    """
  end
end