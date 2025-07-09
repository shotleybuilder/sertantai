defmodule SertantaiWeb.AuthLive do
  @moduledoc """
  LiveView for authentication operations: login, register, reset password, and profile management.
  """
  use SertantaiWeb, :live_view

  alias Sertantai.Accounts.User
  alias AshAuthentication.Form

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Authentication")}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # Login page
  defp apply_action(socket, :login, _params) do
    form = AshAuthentication.Form.for_authentication(User, :password)
    
    socket
    |> assign(:page_title, "Sign In")
    |> assign(:form, to_form(form))
    |> assign(:action, :login)
    |> assign(:errors, [])
  end

  # Register page
  defp apply_action(socket, :register, _params) do
    form = AshAuthentication.Form.for_action(User, :register_with_password)
    
    socket
    |> assign(:page_title, "Create Account")
    |> assign(:form, to_form(form))
    |> assign(:action, :register)
    |> assign(:errors, [])
  end

  # Reset password page
  defp apply_action(socket, :reset_password, _params) do
    form = Form.for_action(User, :request_password_reset)
    
    socket
    |> assign(:page_title, "Reset Password")
    |> assign(:form, to_form(form))
    |> assign(:action, :reset_password)
    |> assign(:errors, [])
  end

  # Profile page - requires authentication
  defp apply_action(socket, :profile, _params) do
    current_user = socket.assigns[:current_user]
    
    if current_user do
      form = Form.for_action(User, :update, current_user)
      
      socket
      |> assign(:page_title, "Profile")
      |> assign(:form, to_form(form))
      |> assign(:action, :profile)
      |> assign(:errors, [])
    else
      socket
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: ~p"/login")
    end
  end

  # Change password page - requires authentication
  defp apply_action(socket, :change_password, _params) do
    current_user = socket.assigns[:current_user]
    
    if current_user do
      form = Form.for_action(User, :change_password, current_user)
      
      socket
      |> assign(:page_title, "Change Password")
      |> assign(:form, to_form(form))
      |> assign(:action, :change_password)
      |> assign(:errors, [])
    else
      socket
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: ~p"/login")
    end
  end

  # Handle form submission
  def handle_event("submit", %{"user" => user_params}, socket) do
    case socket.assigns.action do
      :login -> handle_login(socket, user_params)
      :register -> handle_register(socket, user_params)
      :reset_password -> handle_reset_password(socket, user_params)
      :profile -> handle_profile_update(socket, user_params)
      :change_password -> handle_change_password(socket, user_params)
    end
  end

  # Handle login form submission
  defp handle_login(socket, user_params) do
    form = AshAuthentication.Form.for_authentication(User, :password)
    
    case AshAuthentication.Form.submit(form, user_params) do
      {:ok, _user} ->
        # Redirect to dashboard or return_to path
        return_to = get_connect_params(socket)["return_to"] || ~p"/dashboard"
        
        {:noreply,
         socket
         |> put_flash(:info, "Welcome back!")
         |> redirect(to: return_to)}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  # Handle registration form submission
  defp handle_register(socket, user_params) do
    form = AshAuthentication.Form.for_action(User, :register_with_password)
    
    case AshAuthentication.Form.submit(form, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully! You can now sign in.")
         |> redirect(to: ~p"/login")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  # Handle password reset form submission
  defp handle_reset_password(socket, user_params) do
    form = Form.for_action(User, :request_password_reset)
    
    case Form.submit(form, user_params) do
      {:ok, _} ->
        socket
        |> put_flash(:info, "If the email exists, you will receive password reset instructions.")
        |> redirect(to: ~p"/login")

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  # Handle profile update form submission
  defp handle_profile_update(socket, user_params) do
    current_user = socket.assigns.current_user
    form = Form.for_action(User, :update, current_user)
    
    case Form.submit(form, user_params) do
      {:ok, user} ->
        socket
        |> assign(:current_user, user)
        |> put_flash(:info, "Profile updated successfully!")
        |> redirect(to: ~p"/profile")

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  # Handle change password form submission
  defp handle_change_password(socket, user_params) do
    current_user = socket.assigns.current_user
    form = Form.for_action(User, :change_password, current_user)
    
    case Form.submit(form, user_params) do
      {:ok, _user} ->
        socket
        |> put_flash(:info, "Password changed successfully!")
        |> redirect(to: ~p"/profile")

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  # Handle validation events
  def handle_event("validate", %{"user" => user_params}, socket) do
    form = case socket.assigns.action do
      :login -> Form.for_authentication(User, :password)
      :register -> Form.for_action(User, :register_with_password)
      :reset_password -> Form.for_action(User, :request_password_reset)
      :profile -> Form.for_action(User, :update, socket.assigns.current_user)
      :change_password -> Form.for_action(User, :change_password, socket.assigns.current_user)
    end
    
    form = Form.validate(form, user_params)
    {:noreply, assign(socket, :form, to_form(form))}
  end
end