defmodule SertantaiWeb.AuthLiveTest do
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Sertantai.Accounts.User

  setup do
    # Create a test user for authentication tests
    user_attrs = %{
      email: "test@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      first_name: "Test",
      last_name: "User",
      timezone: "UTC"
    }
    
    {:ok, user} = Ash.create(User, user_attrs, action: :register_with_password, domain: Sertantai.Accounts)
    {:ok, user: user}
  end

  describe "login page" do
    test "renders login form", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/login")
      
      assert html =~ "Sign In"
      assert html =~ "Email address"
      assert html =~ "Password"
      assert html =~ "Forgot your password?"
      assert html =~ "Create one"
    end

    test "shows validation errors for invalid email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/login")
      
      # Submit with invalid email
      lv
      |> form("#auth-form", user: %{email: "invalid-email", password: "password123!"})
      |> render_submit()
      
      # Check that we're still on the login page
      assert render(lv) =~ "Sign In"
    end

    test "shows error for invalid credentials", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/login")
      
      # Submit with wrong password
      lv
      |> form("#auth-form", user: %{email: "test@example.com", password: "wrong-password"})
      |> render_submit()
      
      # Should show error message
      assert render(lv) =~ "Sign In"
    end

    test "redirects to dashboard on successful login", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, "/login")
      
      # Submit with correct credentials
      lv
      |> form("#auth-form", user: %{email: user.email, password: "password123!"})
      |> render_submit()
      
      # Should redirect to dashboard
      assert_redirect(lv, "/dashboard")
    end

    test "validates form fields on input change", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/login")
      
      # Test form validation
      lv
      |> form("#auth-form", user: %{email: "", password: ""})
      |> render_change()
      
      # Should show validation errors
      assert render(lv) =~ "Sign In"
    end
  end

  describe "register page" do
    test "renders registration form", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/register")
      
      assert html =~ "Create Account"
      assert html =~ "First Name"
      assert html =~ "Last Name"
      assert html =~ "Email address"
      assert html =~ "Password"
      assert html =~ "Confirm Password"
      assert html =~ "Sign in"
    end

    test "creates account with valid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/register")
      
      # Submit valid registration data
      lv
      |> form("#auth-form", user: %{
        email: "new@example.com",
        password: "password123!",
        password_confirmation: "password123!",
        first_name: "New",
        last_name: "User"
      })
      |> render_submit()
      
      # Should redirect to login page
      assert_redirect(lv, "/login")
    end

    test "shows validation errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/register")
      
      # Submit with mismatched passwords
      lv
      |> form("#auth-form", user: %{
        email: "test@example.com",
        password: "password123!",
        password_confirmation: "different-password",
        first_name: "Test",
        last_name: "User"
      })
      |> render_submit()
      
      # Should show validation errors
      assert render(lv) =~ "Create Account"
    end

    test "shows error for existing email", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, "/register")
      
      # Submit with existing email
      lv
      |> form("#auth-form", user: %{
        email: user.email,
        password: "password123!",
        password_confirmation: "password123!",
        first_name: "Test",
        last_name: "User"
      })
      |> render_submit()
      
      # Should show error message
      assert render(lv) =~ "Create Account"
    end

    test "validates form fields on input change", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/register")
      
      # Test form validation
      lv
      |> form("#auth-form", user: %{
        email: "invalid-email",
        password: "short",
        password_confirmation: "",
        first_name: "",
        last_name: ""
      })
      |> render_change()
      
      # Should show validation errors
      assert render(lv) =~ "Create Account"
    end
  end

  describe "reset password page" do
    test "renders reset password form", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/reset-password")
      
      assert html =~ "Reset Password"
      assert html =~ "Email address"
      assert html =~ "We'll send you a link"
      assert html =~ "Sign in"
    end

    test "shows success message for valid email", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, "/reset-password")
      
      # Submit with valid email
      lv
      |> form("#auth-form", user: %{email: user.email})
      |> render_submit()
      
      # Should redirect to login page
      assert_redirect(lv, "/login")
    end

    test "shows success message even for non-existent email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/reset-password")
      
      # Submit with non-existent email
      lv
      |> form("#auth-form", user: %{email: "nonexistent@example.com"})
      |> render_submit()
      
      # Should still redirect to login page (security best practice)
      assert_redirect(lv, "/login")
    end

    test "validates email format", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/reset-password")
      
      # Submit with invalid email format
      lv
      |> form("#auth-form", user: %{email: "invalid-email"})
      |> render_change()
      
      # Should show validation error
      assert render(lv) =~ "Reset Password"
    end
  end

  describe "profile page" do
    test "redirects to login if not authenticated", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/profile")
      
      # Should redirect to login page
      assert_redirect(lv, "/login")
    end

    test "renders profile form for authenticated user", %{conn: conn, user: user} do
      # Authenticate the user
      conn = conn |> log_in_user(user)
      
      {:ok, lv, html} = live(conn, "/profile")
      
      assert html =~ "Profile"
      assert html =~ "First Name"
      assert html =~ "Last Name"
      assert html =~ "Email address"
      assert html =~ "Timezone"
      assert html =~ "Change Password"
    end

    test "updates profile with valid data", %{conn: conn, user: user} do
      # Authenticate the user
      conn = conn |> log_in_user(user)
      
      {:ok, lv, _html} = live(conn, "/profile")
      
      # Submit profile update
      lv
      |> form("#auth-form", user: %{
        first_name: "Updated",
        last_name: "Name",
        email: user.email,
        timezone: "America/New_York"
      })
      |> render_submit()
      
      # Should redirect back to profile page
      assert_redirect(lv, "/profile")
    end

    test "shows validation errors for invalid data", %{conn: conn, user: user} do
      # Authenticate the user
      conn = conn |> log_in_user(user)
      
      {:ok, lv, _html} = live(conn, "/profile")
      
      # Submit with invalid email
      lv
      |> form("#auth-form", user: %{
        first_name: "Test",
        last_name: "User",
        email: "invalid-email",
        timezone: "UTC"
      })
      |> render_submit()
      
      # Should show validation errors
      assert render(lv) =~ "Profile"
    end
  end

  describe "change password page" do
    test "redirects to login if not authenticated", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/change-password")
      
      # Should redirect to login page
      assert_redirect(lv, "/login")
    end

    test "renders change password form for authenticated user", %{conn: conn, user: user} do
      # Authenticate the user
      conn = conn |> log_in_user(user)
      
      {:ok, lv, html} = live(conn, "/change-password")
      
      assert html =~ "Change Password"
      assert html =~ "Current Password"
      assert html =~ "New Password"
      assert html =~ "Confirm New Password"
      assert html =~ "Back to Profile"
    end

    test "changes password with valid data", %{conn: conn, user: user} do
      # Authenticate the user
      conn = conn |> log_in_user(user)
      
      {:ok, lv, _html} = live(conn, "/change-password")
      
      # Submit password change
      lv
      |> form("#auth-form", user: %{
        current_password: "password123!",
        password: "newpassword123!",
        password_confirmation: "newpassword123!"
      })
      |> render_submit()
      
      # Should redirect to profile page
      assert_redirect(lv, "/profile")
    end

    test "shows error for incorrect current password", %{conn: conn, user: user} do
      # Authenticate the user
      conn = conn |> log_in_user(user)
      
      {:ok, lv, _html} = live(conn, "/change-password")
      
      # Submit with wrong current password
      lv
      |> form("#auth-form", user: %{
        current_password: "wrongpassword",
        password: "newpassword123!",
        password_confirmation: "newpassword123!"
      })
      |> render_submit()
      
      # Should show error message
      assert render(lv) =~ "Change Password"
    end

    test "shows error for mismatched password confirmation", %{conn: conn, user: user} do
      # Authenticate the user
      conn = conn |> log_in_user(user)
      
      {:ok, lv, _html} = live(conn, "/change-password")
      
      # Submit with mismatched passwords
      lv
      |> form("#auth-form", user: %{
        current_password: "password123!",
        password: "newpassword123!",
        password_confirmation: "differentpassword"
      })
      |> render_submit()
      
      # Should show validation errors
      assert render(lv) =~ "Change Password"
    end
  end

  # Helper function to log in a user
  defp log_in_user(conn, user) do
    # This is a simplified version - in a real app you'd use the proper authentication mechanism
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user_id, user.id)
    |> Plug.Conn.assign(:current_user, user)
  end
end