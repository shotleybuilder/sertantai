defmodule SertantaiWeb.Admin.Components.AdminForm do
  @moduledoc """
  Reusable admin form components for consistent styling and functionality.
  
  Provides form controls, validation, and styling consistent with admin interface.
  """
  
  use Phoenix.Component
  # import Phoenix.HTML.Form  # Consider using Phoenix.Component.form instead
  
  @doc """
  Renders an admin form with consistent styling.
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"
  attr :rest, :global, include: ~w(autocomplete name rel action enctype method novalidate target multipart)
  slot :inner_block, required: true
  
  def admin_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="bg-white shadow rounded-lg">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-medium text-gray-900">Form</h3>
        </div>
        <div class="px-6 py-4 space-y-6">
          <%= render_slot(@inner_block, f) %>
        </div>
      </div>
    </.form>
    """
  end
  
  @doc """
  Renders an admin input field with label and error handling.
  """
  attr :id, :string, required: true
  attr :name, :string, required: true  
  attr :label, :string, required: true
  attr :value, :any, default: nil
  attr :type, :string, default: "text"
  attr :class, :string, default: ""
  attr :errors, :list, default: []
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :placeholder, :string, default: nil
  attr :help_text, :string, default: nil
  attr :rest, :global, include: ~w(accept autocomplete cols disabled form list max maxlength min minlength
                                   multiple pattern placeholder readonly required rows size step)
  
  def admin_input(assigns) do
    ~H"""
    <div>
      <label for={@id} class="block text-sm font-medium text-gray-700">
        <%= @label %>
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      
      <div class="mt-1">
        <input
          type={@type}
          name={@name}
          id={@id}
          value={@value}
          placeholder={@placeholder}
          disabled={@disabled}
          class={[
            "shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md",
            @errors != [] && "border-red-300 text-red-900 placeholder-red-300 focus:ring-red-500 focus:border-red-500",
            @disabled && "bg-gray-50 text-gray-500 cursor-not-allowed",
            @class
          ]}
          {@rest}
        />
      </div>
      
      <%= if @help_text do %>
        <p class="mt-1 text-sm text-gray-500"><%= @help_text %></p>
      <% end %>
      
      <%= if @errors != [] do %>
        <div class="mt-1">
          <%= for error <- @errors do %>
            <p class="text-sm text-red-600"><%= error %></p>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Renders an admin select field with options.
  """
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, default: nil
  attr :options, :list, required: true
  attr :class, :string, default: ""
  attr :errors, :list, default: []
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :prompt, :string, default: nil
  attr :help_text, :string, default: nil
  
  def admin_select(assigns) do
    ~H"""
    <div>
      <label for={@id} class="block text-sm font-medium text-gray-700">
        <%= @label %>
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      
      <div class="mt-1">
        <select
          name={@name}
          id={@id}
          disabled={@disabled}
          class={[
            "shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md",
            @errors != [] && "border-red-300 text-red-900 focus:ring-red-500 focus:border-red-500",
            @disabled && "bg-gray-50 text-gray-500 cursor-not-allowed",
            @class
          ]}
        >
          <%= if @prompt do %>
            <option value=""><%= @prompt %></option>
          <% end %>
          
          <%= for option <- @options do %>
            <%= if is_tuple(option) do %>
              <option value={elem(option, 1)} selected={@value == elem(option, 1)}>
                <%= elem(option, 0) %>
              </option>
            <% else %>
              <option value={option} selected={@value == option}>
                <%= String.capitalize(to_string(option)) %>
              </option>
            <% end %>
          <% end %>
        </select>
      </div>
      
      <%= if @help_text do %>
        <p class="mt-1 text-sm text-gray-500"><%= @help_text %></p>
      <% end %>
      
      <%= if @errors != [] do %>
        <div class="mt-1">
          <%= for error <- @errors do %>
            <p class="text-sm text-red-600"><%= error %></p>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
  
  @doc """
  Renders admin form buttons with consistent styling.
  """
  attr :submit_label, :string, default: "Save"
  attr :cancel_url, :string, default: nil
  attr :cancel_label, :string, default: "Cancel"
  attr :disabled, :boolean, default: false
  attr :class, :string, default: ""
  
  def admin_form_buttons(assigns) do
    ~H"""
    <div class={["flex justify-end space-x-3 px-6 py-4 bg-gray-50 border-t border-gray-200", @class]}>
      <%= if @cancel_url do %>
        <.link
          href={@cancel_url}
          class="inline-flex justify-center py-2 px-4 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          <%= @cancel_label %>
        </.link>
      <% end %>
      
      <button
        type="submit"
        disabled={@disabled}
        class={[
          "inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500",
          @disabled && "bg-gray-300 cursor-not-allowed" || "bg-blue-600 hover:bg-blue-700"
        ]}
      >
        <%= @submit_label %>
      </button>
    </div>
    """
  end
  
  @doc """
  Renders a textarea input for admin forms.
  """
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, default: nil
  attr :class, :string, default: ""
  attr :errors, :list, default: []
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :placeholder, :string, default: nil
  attr :help_text, :string, default: nil
  attr :rows, :integer, default: 4
  attr :rest, :global
  
  def admin_textarea(assigns) do
    ~H"""
    <div>
      <label for={@id} class="block text-sm font-medium text-gray-700">
        <%= @label %>
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      
      <div class="mt-1">
        <textarea
          name={@name}
          id={@id}
          rows={@rows}
          placeholder={@placeholder}
          disabled={@disabled}
          class={[
            "shadow-sm focus:ring-blue-500 focus:border-blue-500 block w-full sm:text-sm border-gray-300 rounded-md",
            @errors != [] && "border-red-300 text-red-900 placeholder-red-300 focus:ring-red-500 focus:border-red-500",
            @disabled && "bg-gray-50 text-gray-500 cursor-not-allowed",
            @class
          ]}
          {@rest}
        ><%= @value %></textarea>
      </div>
      
      <%= if @help_text do %>
        <p class="mt-1 text-sm text-gray-500"><%= @help_text %></p>
      <% end %>
      
      <%= if @errors != [] do %>
        <div class="mt-1">
          <%= for error <- @errors do %>
            <p class="text-sm text-red-600"><%= error %></p>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end