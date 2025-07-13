defmodule SertantaiWeb.AuthLive do
  @moduledoc """
  LiveView for authentication operations: login, register, reset password, and profile management.
  """
  use SertantaiWeb, :live_view

  alias Sertantai.Accounts.User

  def mount(_params, session, socket) do
    # Store return_to from connect_params if available
    return_to = get_connect_params(socket)["return_to"] || ~p"/dashboard"
    
    # Load current user from session if available
    socket = 
      socket
      |> assign(:page_title, "Authentication")
      |> assign(:return_to, return_to)
      |> assign_current_user_from_session(session)
    
    {:ok, socket}
  end

  # Helper to load current user from session using AshAuthentication
  defp assign_current_user_from_session(socket, session) do
    # Use AshAuthentication.Phoenix.LiveSession to properly assign resources
    AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # Login page
  defp apply_action(socket, :login, _params) do
    form = AshPhoenix.Form.for_action(User, :sign_in_with_password, domain: Sertantai.Accounts)
    
    socket
    |> assign(:page_title, "Sign In")
    |> assign(:form, to_form(form))
    |> assign(:action, :login)
    |> assign(:errors, [])
  end

  # Register page
  defp apply_action(socket, :register, _params) do
    form = AshPhoenix.Form.for_action(User, :register_with_password, domain: Sertantai.Accounts)
    
    socket
    |> assign(:page_title, "Create Account")
    |> assign(:form, to_form(form))
    |> assign(:action, :register)
    |> assign(:errors, [])
  end

  # Reset password page
  defp apply_action(socket, :reset_password, _params) do
    form = AshPhoenix.Form.for_action(User, :request_password_reset)
    
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
      form = AshPhoenix.Form.for_action(User, :update, current_user)
      
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
      form = AshPhoenix.Form.for_action(User, :change_password, current_user)
      
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
    require Logger
    Logger.info("Form submitted with action: #{socket.assigns.action}, params: #{inspect(user_params)}")
    
    case socket.assigns.action do
      :login -> handle_login(socket, user_params)
      :register -> handle_register(socket, user_params)
      :reset_password -> handle_reset_password(socket, user_params)
      :profile -> handle_profile_update(socket, user_params)
      :change_password -> handle_change_password(socket, user_params)
    end
  end

  # Handle validation events
  def handle_event("validate", %{"user" => user_params}, socket) do
    form = case socket.assigns.action do
      :login -> AshPhoenix.Form.for_action(User, :sign_in_with_password, domain: Sertantai.Accounts)
      :register -> AshPhoenix.Form.for_action(User, :register_with_password, domain: Sertantai.Accounts)
      :reset_password -> AshPhoenix.Form.for_action(User, :request_password_reset, domain: Sertantai.Accounts)
      :profile -> AshPhoenix.Form.for_action(User, :update, domain: Sertantai.Accounts, initial: socket.assigns.current_user)
      :change_password -> AshPhoenix.Form.for_action(User, :change_password, domain: Sertantai.Accounts, initial: socket.assigns.current_user)
    end
    
    form = AshPhoenix.Form.validate(form, user_params)
    {:noreply, assign(socket, :form, to_form(form))}
  end

  # Handle other form events (e.g., field focus/blur events)
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  # Handle login form submission - no longer needed as form posts directly to auth controller
  defp handle_login(socket, _user_params) do
    {:noreply, socket}
  end

  # Handle registration form submission
  defp handle_register(socket, user_params) do
    require Logger
    Logger.info("Attempting registration with params: #{inspect(user_params)}")
    
    form = AshPhoenix.Form.for_action(User, :register_with_password, domain: Sertantai.Accounts)
    
    case AshPhoenix.Form.submit(form, params: user_params) do
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
    form = AshPhoenix.Form.for_action(User, :request_password_reset)
    
    case AshPhoenix.Form.submit(form, params: user_params) do
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
    form = AshPhoenix.Form.for_action(User, :update, current_user)
    
    case AshPhoenix.Form.submit(form, params: user_params) do
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
    form = AshPhoenix.Form.for_action(User, :change_password, current_user)
    
    case AshPhoenix.Form.submit(form, params: user_params) do
      {:ok, _user} ->
        socket
        |> put_flash(:info, "Password changed successfully!")
        |> redirect(to: ~p"/profile")

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end
end