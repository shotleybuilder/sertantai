defmodule SertantaiWeb.AuthController do
  @moduledoc """
  Authentication controller for handling user sign-in/sign-out operations.
  Uses Ash Authentication for user management.
  """
  
  use SertantaiWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/dashboard"

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: return_to)
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Authentication failed")
    |> redirect(to: ~p"/")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:sertantai)
    |> redirect(to: return_to)
  end
end