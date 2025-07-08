# User Authentication & Record Syncing Action Plan

## Project Overview
Build user authentication and record syncing functionality for an Elixir Phoenix app using the Ash framework. Users will authenticate, select records, and sync them to external no-code databases (Airtable, etc.).

## Prerequisites
- ✅ Phoenix app with Ash framework configured
- ✅ Supabase backend connection established
- ✅ Records successfully pulling through from Supabase

## Phase 1: User Authentication Setup

### 1.1 Install Authentication Dependencies
```bash
# Add to mix.exs dependencies
{:ash_authentication, "~> 4.0"},
{:ash_authentication_phoenix, "~> 2.0"},
{:bcrypt_elixir, "~> 3.0"}
```

### 1.2 Create User Resource
Create `lib/your_app/accounts/user.ex`:
```elixir
defmodule YourApp.Accounts.User do
  use Ash.Resource,
    domain: YourApp.Accounts,
    extensions: [AshAuthentication]

  attributes do
    uuid_primary_key :id
    attribute :email, :ci_string, allow_nil?: false, public?: true
    attribute :hashed_password, :string, allow_nil?: false, sensitive?: true

    # Additional user profile fields
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :timezone, :string, default: "UTC"

    timestamps()
  end

  authentication do
    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
      end
    end

    tokens do
      enabled? true
      token_resource YourApp.Accounts.Token
      signing_secret fn _, _ ->
        Application.fetch_env(:your_app, :token_signing_secret)
      end
    end
  end

  identities do
    identity :unique_email, [:email]
  end

  actions do
    defaults [:read]

    create :register_with_password do
      argument :password, :string, allow_nil?: false, sensitive?: true
      argument :password_confirmation, :string, allow_nil?: false, sensitive?: true

      validate confirm(:password, :password_confirmation)

      change AshAuthentication.Strategy.Password.HashPasswordChange
      change set_attribute(:email, &String.downcase/1)
    end
  end

  preparations do
    prepare build(load: [:sync_configurations])
  end

  relationships do
    has_many :sync_configurations, YourApp.Sync.SyncConfiguration
    has_many :selected_records, YourApp.Sync.SelectedRecord
  end
end
```

### 1.3 Create Token Resource
Create `lib/your_app/accounts/token.ex`:
```elixir
defmodule YourApp.Accounts.Token do
  use Ash.Resource,
    domain: YourApp.Accounts,
    extensions: [AshAuthentication.TokenResource]

  token do
    domain YourApp.Accounts
  end
end
```

### 1.4 Update Accounts Domain
Update `lib/your_app/accounts.ex`:
```elixir
defmodule YourApp.Accounts do
  use Ash.Domain,
    extensions: [AshAuthentication.Domain]

  resources do
    resource YourApp.Accounts.User
    resource YourApp.Accounts.Token
  end

  authentication do
    domain YourApp.Accounts
  end
end
```

### 1.5 Test Authentication Setup
- Test that dependencies are installed correctly
- Verify that the application compiles without errors
- Check that basic authentication structures are in place

### 1.6 Commit Phase 1
```bash
git add .
git commit -m "feat: complete phase 1 - user authentication with Ash framework"
git push origin main
```

**⏸️ PAUSE: Wait for confirmation that Phase 1 is working before proceeding to Phase 2**

---

## Phase 2: Sync Configuration Resources

### 2.1 Create SyncConfiguration Resource
Create `lib/your_app/sync/sync_configuration.ex`:
```elixir
defmodule YourApp.Sync.SyncConfiguration do
  use Ash.Resource,
    domain: YourApp.Sync

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :provider, :atom, constraints: [one_of: [:airtable, :notion, :zapier]]
    attribute :is_active, :boolean, default: true

    # Encrypted credentials storage
    attribute :encrypted_credentials, :string, sensitive?: true
    attribute :credentials_iv, :string, sensitive?: true

    # Sync settings
    attribute :sync_frequency, :atom,
      constraints: [one_of: [:manual, :hourly, :daily, :weekly]],
      default: :manual
    attribute :last_synced_at, :utc_datetime
    attribute :sync_status, :atom,
      constraints: [one_of: [:pending, :syncing, :completed, :failed]],
      default: :pending

    timestamps()
  end

  relationships do
    belongs_to :user, YourApp.Accounts.User, allow_nil?: false
    has_many :selected_records, YourApp.Sync.SelectedRecord
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :provider, :sync_frequency]
      argument :credentials, :map, allow_nil?: false

      change before_action(fn changeset, _context ->
        case changeset.arguments[:credentials] do
          nil -> changeset
          creds -> encrypt_and_store_credentials(changeset, creds)
        end
      end)
    end

    update :update do
      accept [:name, :is_active, :sync_frequency]
      argument :credentials, :map

      change before_action(fn changeset, _context ->
        case changeset.arguments[:credentials] do
          nil -> changeset
          creds -> encrypt_and_store_credentials(changeset, creds)
        end
      end)
    end

    update :update_sync_status do
      accept [:sync_status, :last_synced_at]
    end
  end

  defp encrypt_and_store_credentials(changeset, credentials) do
    # Implementation for encrypting credentials
    # Use :crypto.strong_rand_bytes(16) for IV
    # Store encrypted data in encrypted_credentials field
    changeset
  end
end
```

### 2.2 Create SelectedRecord Resource
Create `lib/your_app/sync/selected_record.ex`:
```elixir
defmodule YourApp.Sync.SelectedRecord do
  use Ash.Resource,
    domain: YourApp.Sync

  attributes do
    uuid_primary_key :id
    attribute :external_record_id, :string, allow_nil?: false
    attribute :record_type, :string, allow_nil?: false
    attribute :sync_status, :atom,
      constraints: [one_of: [:pending, :synced, :failed]],
      default: :pending
    attribute :last_synced_at, :utc_datetime
    attribute :sync_error, :string

    # Store original record data for comparison
    attribute :cached_data, :map

    timestamps()
  end

  relationships do
    belongs_to :user, YourApp.Accounts.User, allow_nil?: false
    belongs_to :sync_configuration, YourApp.Sync.SyncConfiguration, allow_nil?: false
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:external_record_id, :record_type, :cached_data]
    end

    update :update_sync_status do
      accept [:sync_status, :last_synced_at, :sync_error]
    end
  end

  identities do
    identity :unique_record_per_config, [:sync_configuration_id, :external_record_id]
  end
end
```

### 2.3 Create Sync Domain
Create `lib/your_app/sync.ex`:
```elixir
defmodule YourApp.Sync do
  use Ash.Domain

  resources do
    resource YourApp.Sync.SyncConfiguration
    resource YourApp.Sync.SelectedRecord
  end
end
```

## Phase 3: Phoenix Integration

### 3.1 Update Router
Update `lib/your_app_web/router.ex`:
```elixir
defmodule YourAppWeb.Router do
  use YourAppWeb, :router
  use AshAuthentication.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {YourAppWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  scope "/", YourAppWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Authentication routes
    sign_in_route()
    sign_out_route AuthController
    auth_routes_for YourApp.Accounts.User, to: AuthController
    reset_route []
  end

  # Protected routes
  scope "/", YourAppWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/dashboard", DashboardLive
    live "/sync-configs", SyncConfigLive.Index
    live "/sync-configs/new", SyncConfigLive.New
    live "/sync-configs/:id/edit", SyncConfigLive.Edit
    live "/records", RecordSelectionLive
  end
end
```

### 3.2 Create Authentication Controller
Create `lib/your_app_web/controllers/auth_controller.ex`:
```elixir
defmodule YourAppWeb.AuthController do
  use YourAppWeb, :controller
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
    |> clear_session()
    |> redirect(to: return_to)
  end
end
```

## Phase 4: LiveView Components

### 4.1 Create Dashboard LiveView
Create `lib/your_app_web/live/dashboard_live.ex`:
```elixir
defmodule YourAppWeb.DashboardLive do
  use YourAppWeb, :live_view

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    sync_configs = YourApp.Sync.SyncConfiguration
    |> Ash.Query.filter(user_id == ^user.id)
    |> YourApp.Sync.read!()

    selected_records_count = YourApp.Sync.SelectedRecord
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.Query.aggregate(:count, :id)
    |> YourApp.Sync.read!()

    {:ok, assign(socket,
      sync_configs: sync_configs,
      selected_records_count: selected_records_count
    )}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-8">
        <h1 class="text-3xl font-bold text-gray-900">Dashboard</h1>

        <div class="mt-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <!-- Sync Configurations Card -->
          <div class="bg-white shadow rounded-lg p-6">
            <h3 class="text-lg font-medium text-gray-900">Sync Configurations</h3>
            <p class="mt-2 text-3xl font-bold text-blue-600"><%= length(@sync_configs) %></p>
            <.link navigate={~p"/sync-configs"} class="mt-4 text-blue-600 hover:text-blue-800">
              Manage configurations →
            </.link>
          </div>

          <!-- Selected Records Card -->
          <div class="bg-white shadow rounded-lg p-6">
            <h3 class="text-lg font-medium text-gray-900">Selected Records</h3>
            <p class="mt-2 text-3xl font-bold text-green-600"><%= @selected_records_count %></p>
            <.link navigate={~p"/records"} class="mt-4 text-green-600 hover:text-green-800">
              Select records →
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
```

### 4.2 Create Sync Configuration LiveView
Create `lib/your_app_web/live/sync_config_live/index.ex`:
```elixir
defmodule YourAppWeb.SyncConfigLive.Index do
  use YourAppWeb, :live_view

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    sync_configs = YourApp.Sync.SyncConfiguration
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.Query.load([:selected_records])
    |> YourApp.Sync.read!()

    {:ok, assign(socket, sync_configs: sync_configs)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    sync_config = Enum.find(socket.assigns.sync_configs, &(&1.id == id))

    case YourApp.Sync.destroy(sync_config) do
      :ok ->
        sync_configs = Enum.reject(socket.assigns.sync_configs, &(&1.id == id))

        {:noreply,
          socket
          |> assign(sync_configs: sync_configs)
          |> put_flash(:info, "Sync configuration deleted successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete sync configuration")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="py-8">
        <div class="flex justify-between items-center">
          <h1 class="text-3xl font-bold text-gray-900">Sync Configurations</h1>
          <.link navigate={~p"/sync-configs/new"}
                class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700">
            New Configuration
          </.link>
        </div>

        <div class="mt-8 grid gap-6">
          <%= for config <- @sync_configs do %>
            <div class="bg-white shadow rounded-lg p-6">
              <div class="flex justify-between items-start">
                <div>
                  <h3 class="text-lg font-medium text-gray-900"><%= config.name %></h3>
                  <p class="text-sm text-gray-500">
                    Provider: <%= String.capitalize(to_string(config.provider)) %>
                  </p>
                  <p class="text-sm text-gray-500">
                    Records: <%= length(config.selected_records) %>
                  </p>
                  <p class="text-sm text-gray-500">
                    Status: <%= String.capitalize(to_string(config.sync_status)) %>
                  </p>
                </div>

                <div class="flex space-x-2">
                  <.link navigate={~p"/sync-configs/#{config.id}/edit"}
                        class="text-blue-600 hover:text-blue-800">
                    Edit
                  </.link>
                  <button phx-click="delete" phx-value-id={config.id}
                          class="text-red-600 hover:text-red-800"
                          data-confirm="Are you sure?">
                    Delete
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
```

## Phase 5: Database Migration & Configuration

### 5.1 Generate Migration
```bash
mix ash_postgres.generate_migrations --name add_user_auth_and_sync
```

### 5.2 Update Application Configuration
Update `config/config.exs`:
```elixir
config :your_app, :token_signing_secret, "your-secret-key-here"

config :your_app, YourApp.Repo,
  extensions: [AshPostgres.Extension]
```

### 5.3 Update Domain Configuration
Update your main domain to include the new domains:
```elixir
# In lib/your_app/application.ex or main domain file
config :your_app, ash_domains: [
  YourApp.Accounts,
  YourApp.Sync,
  # ... other existing domains
]
```

## Phase 6: External API Integration

### 6.1 Create Sync Service Module
Create `lib/your_app/sync/sync_service.ex`:
```elixir
defmodule YourApp.Sync.SyncService do
  @moduledoc """
  Service for syncing records to external no-code databases
  """

  def sync_configuration(sync_config_id) do
    # Load sync configuration with selected records
    # Decrypt credentials
    # Call appropriate provider API
    # Update sync status
  end

  defp sync_to_airtable(records, credentials) do
    # Airtable API implementation
  end

  defp sync_to_notion(records, credentials) do
    # Notion API implementation
  end
end
```

### 6.2 Create Background Job for Syncing
Create `lib/your_app/sync/sync_worker.ex`:
```elixir
defmodule YourApp.Sync.SyncWorker do
  use Oban.Worker, queue: :sync

  def perform(%Oban.Job{args: %{"sync_config_id" => sync_config_id}}) do
    YourApp.Sync.SyncService.sync_configuration(sync_config_id)
  end
end
```

## Phase 7: Testing Implementation

### 7.1 Test User Authentication
- [ ] User registration works
- [ ] User login/logout works
- [ ] Protected routes require authentication
- [ ] Session persistence works

### 7.2 Test Sync Configuration
- [ ] Users can create sync configurations
- [ ] Credentials are properly encrypted
- [ ] Users can edit/delete configurations
- [ ] Users can only see their own configurations

### 7.3 Test Record Selection
- [ ] Users can select records for syncing
- [ ] Selected records are properly associated with configurations
- [ ] Users can modify their selection

## Phase 8: Security & Deployment Checklist

### 8.1 Security Review
- [ ] Credentials encryption implemented
- [ ] User data isolation enforced
- [ ] CSRF protection enabled
- [ ] Input validation in place
- [ ] Rate limiting configured

### 8.2 Environment Configuration
- [ ] Production secrets configured
- [ ] Database migrations run
- [ ] SSL certificates configured
- [ ] Monitoring and logging set up

## Next Steps After Implementation

1. **Add API rate limiting** for external service calls
2. **Implement webhook endpoints** for real-time sync triggers
3. **Add sync scheduling** with cron jobs
4. **Create audit logging** for sync activities
5. **Add sync conflict resolution** strategies
6. **Implement bulk record operations**
7. **Add sync analytics and reporting**

## Resources & Documentation

- [Ash Framework Documentation](https://www.ash-hq.org/)
- [Ash Authentication](https://hexdocs.pm/ash_authentication/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)
- [Airtable API](https://airtable.com/developers/web/api/introduction)
- [Notion API](https://developers.notion.com/)

## Notes for AI Agent

- Follow Ash framework conventions strictly
- Use changesets for all data modifications
- Implement proper error handling for external API calls
- Ensure all user data is properly scoped and isolated
- Test each phase thoroughly before proceeding
- Use Phoenix LiveView for real-time UI updates
- Implement proper logging for debugging sync issues
