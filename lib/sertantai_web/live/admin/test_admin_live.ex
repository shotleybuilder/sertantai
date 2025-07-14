defmodule SertantaiWeb.Admin.TestAdminLive do
  @moduledoc """
  Minimal test version of AdminLive to isolate the memory leak issue.
  """
  
  use SertantaiWeb, :live_view
  
  alias Sertantai.Accounts.User
  
  @impl true
  def mount(_params, _session, socket) do
    # Minimal mount - just check if user exists
    case socket.assigns[:current_user] do
      %User{} ->
        {:ok, assign(socket, :page_title, "Test Admin")}
      
      _ ->
        {:ok, assign(socket, :page_title, "No User")}
    end
  end
  
  # Remove handle_params for isolated testing
  
  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1>Test Admin Page</h1>
      <p>Page title: <%= @page_title %></p>
      <%= if assigns[:current_user] do %>
        <p>User role: <%= @current_user.role %></p>
      <% else %>
        <p>No user assigned</p>
      <% end %>
    </div>
    """
  end
end