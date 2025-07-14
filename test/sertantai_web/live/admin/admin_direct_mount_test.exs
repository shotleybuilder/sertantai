defmodule SertantaiWeb.Admin.AdminDirectMountTest do
  @moduledoc """
  Test admin LiveView by calling mount/3 directly, completely bypassing router.
  This should work without any database issues.
  
  See README.md in this directory for testing approach documentation.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Sertantai.AccountsFixtures
  alias Phoenix.LiveView.Socket
  
  describe "direct mount testing" do
    test "mount with admin user" do
      admin = user_fixture(%{role: :admin})
      
      # Create a minimal socket with required assigns
      socket = %Socket{
        assigns: %{
          current_user: admin,
          __changed__: %{},
          flash: %{},
          live_action: nil
        }
      }
      
      # Call mount directly
      assert {:ok, socket} = SertantaiWeb.Admin.AdminLive.mount(%{}, %{}, socket)
      assert socket.assigns.page_title == "Admin Dashboard"
    end
    
    test "mount with support user" do
      support = user_fixture(%{role: :support})
      
      socket = %Socket{
        assigns: %{
          current_user: support,
          __changed__: %{},
          flash: %{},
          live_action: nil
        }
      }
      
      assert {:ok, socket} = SertantaiWeb.Admin.AdminLive.mount(%{}, %{}, socket)
      assert socket.assigns.page_title == "Admin Dashboard"
    end
    
    test "mount with non-admin user redirects" do
      member = user_fixture(%{role: :member})
      
      socket = %Socket{
        assigns: %{
          current_user: member,
          __changed__: %{},
          flash: %{},
          live_action: nil
        },
        redirected: nil
      }
      
      {:ok, socket} = SertantaiWeb.Admin.AdminLive.mount(%{}, %{}, socket)
      
      # Check that socket was redirected
      assert {:redirect, %{to: "/dashboard"}} = socket.redirected
    end
    
    test "mount without user redirects to login" do
      socket = %Socket{
        assigns: %{
          current_user: nil,
          __changed__: %{},
          flash: %{},
          live_action: nil
        },
        redirected: nil
      }
      
      {:ok, socket} = SertantaiWeb.Admin.AdminLive.mount(%{}, %{}, socket)
      
      # Check that socket was redirected
      assert {:redirect, %{to: "/login"}} = socket.redirected
    end
    
    test "handle_params works correctly" do
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          __changed__: %{},
          flash: %{},
          live_action: nil,
          page_title: "Admin Dashboard"
        }
      }
      
      # Test handle_params
      {:noreply, socket} = SertantaiWeb.Admin.AdminLive.handle_params(%{}, "http://localhost/admin", socket)
      
      # Should still have the same assigns
      assert socket.assigns.page_title == "Admin Dashboard"
    end
  end
end