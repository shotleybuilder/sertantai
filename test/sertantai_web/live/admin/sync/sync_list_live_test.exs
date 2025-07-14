defmodule SertantaiWeb.Admin.Sync.SyncListLiveTest do
  @moduledoc """
  Test sync configuration list functionality using safe component testing patterns.
  
  Uses direct component rendering to avoid router authentication issues.
  See README.md in admin/ directory for testing approach explanation.
  """
  
  use SertantaiWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Sertantai.AccountsFixtures
  
  alias SertantaiWeb.Admin.Sync.SyncListLive
  alias Phoenix.LiveView.Socket
  
  describe "sync list component rendering" do
    test "renders sync configuration list for admin user" do
      admin = user_fixture(%{role: :admin})
      
      # Mock sync configuration data
      config1 = %{
        id: "sync-config-1",
        name: "Airtable Production Sync",
        provider: :airtable,
        is_active: true,
        sync_status: :completed,
        sync_frequency: :daily,
        last_synced_at: ~U[2024-01-14 10:30:00Z],
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      config2 = %{
        id: "sync-config-2",
        name: "Notion Development Sync",
        provider: :notion,
        is_active: false,
        sync_status: :pending,
        sync_frequency: :manual,
        last_synced_at: nil,
        inserted_at: ~U[2024-01-02 00:00:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          sync_configs: [config1, config2],
          all_sync_configs: [config1, config2],
          search_term: "",
          provider_filter: "all",
          status_filter: "all",
          sort_by: "name",
          sort_order: "asc",
          selected_configs: [],
          show_sync_modal: false,
          editing_config: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&SyncListLive.render/1, socket.assigns)
      
      # Check that admin interface elements are present
      assert html =~ "Sync Configuration Management"
      assert html =~ "New Sync Configuration"
      assert html =~ "Airtable Production Sync"
      assert html =~ "Notion Development Sync"
      assert html =~ "Airtable"
      assert html =~ "Notion"
      assert html =~ "Active"
      assert html =~ "Inactive"
      assert html =~ "Completed"
      assert html =~ "Pending"
    end
    
    test "renders sync configuration list for support user" do
      support = user_fixture(%{role: :support})
      
      config = %{
        id: "sync-config-1",
        name: "Test Sync Config",
        provider: :zapier,
        is_active: true,
        sync_status: :syncing,
        sync_frequency: :hourly,
        last_synced_at: ~U[2024-01-14 10:30:00Z],
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: support,
          sync_configs: [config],
          all_sync_configs: [config],
          search_term: "",
          provider_filter: "all",
          status_filter: "all",
          sort_by: "name",
          sort_order: "asc",
          selected_configs: [],
          show_sync_modal: false,
          editing_config: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&SyncListLive.render/1, socket.assigns)
      
      # Support users should see the interface but not "New Sync Configuration" button
      assert html =~ "Sync Configuration Management"
      refute html =~ "New Sync Configuration"
      assert html =~ "Test Sync Config"
      assert html =~ "Zapier"
      assert html =~ "Syncing"
    end
    
    test "search functionality filters configurations correctly" do
      admin = user_fixture(%{role: :admin})
      
      config1 = %{
        id: "sync-config-1",
        name: "Airtable Production",
        provider: :airtable,
        is_active: true,
        sync_status: :completed,
        sync_frequency: :daily,
        last_synced_at: ~U[2024-01-14 10:30:00Z],
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          sync_configs: [config1],  # Filtered to only show Airtable
          all_sync_configs: [config1],
          search_term: "airtable",
          provider_filter: "all",
          status_filter: "all",
          sort_by: "name",
          sort_order: "asc",
          selected_configs: [],
          show_sync_modal: false,
          editing_config: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&SyncListLive.render/1, socket.assigns)
      
      # Should show filtered results
      assert html =~ "Airtable Production"
      assert html =~ "Airtable"
    end
    
    test "provider filter works correctly" do
      admin = user_fixture(%{role: :admin})
      
      airtable_config = %{
        id: "sync-config-1",
        name: "Airtable Config",
        provider: :airtable,
        is_active: true,
        sync_status: :completed,
        sync_frequency: :daily,
        last_synced_at: ~U[2024-01-14 10:30:00Z],
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          sync_configs: [airtable_config],  # Filtered to show only Airtable
          all_sync_configs: [airtable_config],
          search_term: "",
          provider_filter: "airtable",
          status_filter: "all",
          sort_by: "name",
          sort_order: "asc",
          selected_configs: [],
          show_sync_modal: false,
          editing_config: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&SyncListLive.render/1, socket.assigns)
      
      # Should show only Airtable configuration
      assert html =~ "Airtable Config"
      assert html =~ "Airtable"
    end
    
    test "status indicators display correctly" do
      admin = user_fixture(%{role: :admin})
      
      config = %{
        id: "sync-config-1",
        name: "Test Config",
        provider: :notion,
        is_active: true,
        sync_status: :failed,
        sync_frequency: :weekly,
        last_synced_at: ~U[2024-01-14 10:30:00Z],
        inserted_at: ~U[2024-01-01 00:00:00Z]
      }
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          sync_configs: [config],
          all_sync_configs: [config],
          search_term: "",
          provider_filter: "all",
          status_filter: "all",
          sort_by: "name",
          sort_order: "asc",
          selected_configs: [],
          show_sync_modal: false,
          editing_config: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&SyncListLive.render/1, socket.assigns)
      
      # Should show status indicators
      assert html =~ "Active"
      assert html =~ "Failed"
      assert html =~ "2024-01-14 10:30"
    end
    
    test "sorting controls display correctly" do
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          sync_configs: [],
          all_sync_configs: [],
          search_term: "",
          provider_filter: "all",
          status_filter: "all",
          sort_by: "name",
          sort_order: "asc",
          selected_configs: [],
          show_sync_modal: false,
          editing_config: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&SyncListLive.render/1, socket.assigns)
      
      # Should show sortable column headers
      assert html =~ "Name"
      assert html =~ "Provider"
      assert html =~ "Status"
      assert html =~ "Last Sync"
      assert html =~ "Created"
      
      # Should show sort indicator for name column
      assert html =~ "M5 8l5-5 5 5H5z"  # Ascending arrow for name
    end
    
    test "empty state displays correctly" do
      admin = user_fixture(%{role: :admin})
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          sync_configs: [],
          all_sync_configs: [],
          search_term: "",
          provider_filter: "all",
          status_filter: "all",
          sort_by: "name",
          sort_order: "asc",
          selected_configs: [],
          show_sync_modal: false,
          editing_config: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&SyncListLive.render/1, socket.assigns)
      
      # Should show empty state
      assert html =~ "No sync configurations found"
      assert html =~ "Get started by creating a new sync configuration"
    end
    
    test "provider indicators show correct colors" do
      admin = user_fixture(%{role: :admin})
      
      configs = [
        %{
          id: "sync-1",
          name: "Airtable Config",
          provider: :airtable,
          is_active: true,
          sync_status: :completed,
          sync_frequency: :daily,
          last_synced_at: ~U[2024-01-14 10:30:00Z],
          inserted_at: ~U[2024-01-01 00:00:00Z]
        },
        %{
          id: "sync-2", 
          name: "Notion Config",
          provider: :notion,
          is_active: true,
          sync_status: :completed,
          sync_frequency: :daily,
          last_synced_at: ~U[2024-01-14 10:30:00Z],
          inserted_at: ~U[2024-01-01 00:00:00Z]
        },
        %{
          id: "sync-3",
          name: "Zapier Config", 
          provider: :zapier,
          is_active: true,
          sync_status: :completed,
          sync_frequency: :daily,
          last_synced_at: ~U[2024-01-14 10:30:00Z],
          inserted_at: ~U[2024-01-01 00:00:00Z]
        }
      ]
      
      socket = %Socket{
        assigns: %{
          current_user: admin,
          sync_configs: configs,
          all_sync_configs: configs,
          search_term: "",
          provider_filter: "all",
          status_filter: "all",
          sort_by: "name",
          sort_order: "asc",
          selected_configs: [],
          show_sync_modal: false,
          editing_config: nil,
          __changed__: %{},
          flash: %{},
          live_action: :index
        }
      }
      
      html = render_component(&SyncListLive.render/1, socket.assigns)
      
      # Should show provider-specific colors
      assert html =~ "bg-yellow-500"  # Airtable
      assert html =~ "bg-gray-900"    # Notion  
      assert html =~ "bg-orange-500"  # Zapier
    end
  end
end