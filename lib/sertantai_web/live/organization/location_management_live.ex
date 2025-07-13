defmodule SertantaiWeb.Organization.LocationManagementLive do
  @moduledoc """
  LiveView for managing organization locations.
  Allows users to add, edit, and remove locations for their organization.
  """
  use SertantaiWeb, :live_view
  
  alias Sertantai.Organizations
  alias Sertantai.Organizations.{Organization, OrganizationLocation}
  alias Sertantai.Organizations.SingleLocationAdapter
  require Ash.Query
  
  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-3xl">
        <.header>
          Location Management
          <:subtitle>
            Manage your organization's locations and operational sites
          </:subtitle>
          <:actions>
            <.button phx-click="add_location" class="bg-blue-600 hover:bg-blue-700">
              <.icon name="hero-plus-circle" class="mr-2" />
              Add Location
            </.button>
          </:actions>
        </.header>

        <%= if @show_add_form do %>
          <div class="mt-8 bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Add New Location</h3>
              <.location_form form={@location_form} phx-submit="save_location" phx-change="validate_location" />
            </div>
          </div>
        <% end %>

        <div class="mt-8 space-y-6">
          <%= for location <- @locations do %>
            <div class="bg-white shadow sm:rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <h3 class="text-lg font-medium leading-6 text-gray-900">
                      <%= location.location_name %>
                      <%= if location.is_primary_location do %>
                        <span class="ml-2 inline-flex items-center rounded-md bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-700/10">
                          Primary
                        </span>
                      <% end %>
                    </h3>
                    <p class="mt-1 text-sm text-gray-500">
                      <%= humanize_atom(location.location_type) %> • <%= location.geographic_region %>
                    </p>
                    
                    <dl class="mt-3 grid grid-cols-1 gap-x-4 gap-y-3 sm:grid-cols-3">
                      <div>
                        <dt class="text-sm font-medium text-gray-500">Status</dt>
                        <dd class="mt-1 text-sm text-gray-900">
                          <%= humanize_atom(location.operational_status) %>
                        </dd>
                      </div>
                      <%= if location.employee_count do %>
                        <div>
                          <dt class="text-sm font-medium text-gray-500">Employees</dt>
                          <dd class="mt-1 text-sm text-gray-900"><%= location.employee_count %></dd>
                        </div>
                      <% end %>
                      <%= if location.postcode do %>
                        <div>
                          <dt class="text-sm font-medium text-gray-500">Postcode</dt>
                          <dd class="mt-1 text-sm text-gray-900"><%= location.postcode %></dd>
                        </div>
                      <% end %>
                    </dl>

                    <%= if location.industry_activities && length(location.industry_activities) > 0 do %>
                      <div class="mt-3">
                        <dt class="text-sm font-medium text-gray-500">Activities</dt>
                        <dd class="mt-1 flex flex-wrap gap-2">
                          <%= for activity <- location.industry_activities do %>
                            <span class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10">
                              <%= activity %>
                            </span>
                          <% end %>
                        </dd>
                      </div>
                    <% end %>
                  </div>
                  
                  <div class="ml-4 flex-shrink-0 flex space-x-2">
                    <.button phx-click="screen_location" phx-value-id={location.id} class="bg-green-600 hover:bg-green-700">
                      <.icon name="hero-document-magnifying-glass" class="mr-1" />
                      Screen
                    </.button>
                    <.button phx-click="edit_location" phx-value-id={location.id} class="bg-gray-600 hover:bg-gray-700">
                      Edit
                    </.button>
                    <%= unless location.is_primary_location || @is_single_location do %>
                      <.button phx-click="delete_location" phx-value-id={location.id} 
                               class="bg-red-600 hover:bg-red-700"
                               data-confirm="Are you sure you want to delete this location?">
                        Delete
                      </.button>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <%= if length(@locations) == 0 do %>
          <div class="mt-8 text-center">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path vector-effect="non-scaling-stroke" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 13h6m-3-3v6m-9 1V7a2 2 0 012-2h6l2 2h6a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z" />
            </svg>
            <h3 class="mt-2 text-sm font-semibold text-gray-900">No locations</h3>
            <p class="mt-1 text-sm text-gray-500">Get started by creating a location for your organization.</p>
            <div class="mt-6">
              <.button phx-click="add_location" class="bg-blue-600 hover:bg-blue-700">
                <.icon name="hero-plus-circle" class="mr-2" />
                Add First Location
              </.button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp location_form(assigns) do
    ~H"""
    <.simple_form for={@form} phx-submit={@phx_submit} phx-change={@phx_change}>
      <.input field={@form[:location_name]} type="text" label="Location Name" placeholder="e.g., London Office" />
      
      <.input field={@form[:location_type]} type="select" label="Location Type" 
              options={location_type_options()} />
      
      <.input field={@form[:geographic_region]} type="select" label="Geographic Region" 
              options={geographic_region_options()} />
      
      <.input field={@form[:postcode]} type="text" label="Postcode" />
      
      <.input field={@form[:employee_count]} type="number" label="Number of Employees" min="0" />
      
      <.input field={@form[:operational_status]} type="select" label="Operational Status" 
              options={operational_status_options()} />
      
      <:actions>
        <.button phx-click="cancel_form" type="button" class="bg-gray-600 hover:bg-gray-700">
          Cancel
        </.button>
        <.button type="submit" class="bg-blue-600 hover:bg-blue-700">
          Save Location
        </.button>
      </:actions>
    </.simple_form>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
    current_user = socket.assigns[:current_user]

    if current_user do
      case load_user_organization_with_locations(current_user.id) do
        {:ok, organization} ->
          interface_mode = SingleLocationAdapter.interface_mode(organization)
          
          {:ok,
           socket
           |> assign(:page_title, "Location Management")
           |> assign(:organization, organization)
           |> assign(:locations, organization.locations || [])
           |> assign(:editing_location, nil)
           |> assign(:show_add_form, false)
           |> assign(:location_form, to_form(%{}, as: "location"))
           |> assign(:is_single_location, interface_mode == :single_location)}

        {:error, :not_found} ->
          {:ok, 
           socket
           |> put_flash(:error, "Organization not found")
           |> redirect(to: ~p"/organizations/register")}
      end
    else
      {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def handle_event("add_location", _params, socket) do
    form = to_form(%{
      "location_type" => "branch_office",
      "operational_status" => "active",
      "geographic_region" => "england"
    }, as: "location")
    
    {:noreply, 
     socket
     |> assign(:show_add_form, true)
     |> assign(:location_form, form)}
  end

  @impl true
  def handle_event("cancel_form", _params, socket) do
    {:noreply, 
     socket
     |> assign(:show_add_form, false)
     |> assign(:editing_location, nil)}
  end

  @impl true
  def handle_event("validate_location", %{"location" => location_params}, socket) do
    form = to_form(location_params, as: "location")
    {:noreply, assign(socket, :location_form, form)}
  end

  @impl true
  def handle_event("save_location", %{"location" => location_params}, socket) do
    organization = socket.assigns.organization
    
    # Convert string keys to atoms and prepare location data
    location_attrs = %{
      location_name: location_params["location_name"],
      location_type: String.to_existing_atom(location_params["location_type"]),
      geographic_region: location_params["geographic_region"],
      postcode: location_params["postcode"],
      employee_count: parse_integer(location_params["employee_count"]),
      operational_status: String.to_existing_atom(location_params["operational_status"]),
      organization_id: organization.id,
      address: %{
        "region" => location_params["geographic_region"],
        "postcode" => location_params["postcode"]
      }
    }
    
    # If this is the first location, make it primary
    location_attrs = 
      if length(socket.assigns.locations) == 0 do
        Map.put(location_attrs, :is_primary_location, true)
      else
        location_attrs
      end
    
    case Ash.create(OrganizationLocation, location_attrs, domain: Organizations) do
      {:ok, _location} ->
        # Reload organization with locations
        {:ok, updated_org} = load_user_organization_with_locations(socket.assigns.current_user.id)
        
        {:noreply,
         socket
         |> put_flash(:info, "Location added successfully")
         |> assign(:organization, updated_org)
         |> assign(:locations, updated_org.locations || [])
         |> assign(:show_add_form, false)}
      
      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to add location: #{inspect(changeset)}") 
         |> assign(:location_form, to_form(location_params, as: "location"))}
    end
  end

  @impl true
  def handle_event("edit_location", %{"id" => location_id}, socket) do
    location = Enum.find(socket.assigns.locations, &(&1.id == location_id))
    
    if location do
      # TODO: Implement edit functionality
      {:noreply, put_flash(socket, :info, "Edit functionality coming soon")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_location", %{"id" => location_id}, socket) do
    location = Enum.find(socket.assigns.locations, &(&1.id == location_id))
    
    if location && !location.is_primary_location do
      case Ash.destroy(location, domain: Organizations) do
        :ok ->
          # Reload organization with locations
          {:ok, updated_org} = load_user_organization_with_locations(socket.assigns.current_user.id)
          
          {:noreply,
           socket
           |> put_flash(:info, "Location deleted successfully")
           |> assign(:organization, updated_org)
           |> assign(:locations, updated_org.locations || [])}
        
        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to delete location")}
      end
    else
      {:noreply, put_flash(socket, :error, "Cannot delete primary location")}
    end
  end

  @impl true
  def handle_event("screen_location", %{"id" => location_id}, socket) do
    # Redirect to location-specific screening
    location = Enum.find(socket.assigns.locations, &(&1.id == location_id))
    if location do
      {:noreply, redirect(socket, to: ~p"/applicability/location/#{location.id}")}
    else
      {:noreply, socket}
    end
  end

  defp load_user_organization_with_locations(user_id) do
    Organization
    |> Ash.Query.filter(created_by_user_id == ^user_id)
    |> Ash.Query.load([:locations])
    |> Ash.read_one(domain: Organizations)
  end

  defp location_type_options do
    [
      {"Headquarters", "headquarters"},
      {"Branch Office", "branch_office"},
      {"Warehouse", "warehouse"},
      {"Manufacturing Site", "manufacturing_site"},
      {"Retail Outlet", "retail_outlet"},
      {"Project Site", "project_site"},
      {"Temporary Location", "temporary_location"},
      {"Home Office", "home_office"},
      {"Other", "other"}
    ]
  end

  defp geographic_region_options do
    [
      {"England", "england"},
      {"Scotland", "scotland"},
      {"Wales", "wales"},
      {"Northern Ireland", "northern_ireland"}
    ]
  end

  defp operational_status_options do
    [
      {"Active", "active"},
      {"Inactive", "inactive"},
      {"Seasonal", "seasonal"},
      {"Under Construction", "under_construction"},
      {"Closing", "closing"}
    ]
  end

  defp humanize_atom(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil
  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end
  defp parse_integer(value) when is_integer(value), do: value
end