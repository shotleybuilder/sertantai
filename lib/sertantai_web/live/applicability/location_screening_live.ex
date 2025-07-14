defmodule SertantaiWeb.Applicability.LocationScreeningLive do
  @moduledoc """
  LiveView for conducting applicability screening on a specific organization location.
  Provides location-specific regulation screening with tailored results.
  """
  use SertantaiWeb, :live_view
  
  alias Sertantai.Organizations
  alias Sertantai.Organizations.{OrganizationLocation, SingleLocationAdapter}
    require Ash.Query

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-4xl">
        <.header>
          <%= @location.location_name %> Screening
          <:subtitle>
            Applicability screening for <%= @location.location_name %> - <%= humanize_atom(@location.location_type) %>
          </:subtitle>
          <:actions>
            <.link navigate={~p"/organizations/locations"} class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700">
              ← Back to Locations
            </.link>
          </:actions>
        </.header>

        <!-- Location Summary -->
        <div class="mt-8 bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Location Details</h3>
            <dl class="grid grid-cols-1 gap-x-4 gap-y-3 sm:grid-cols-3">
              <div>
                <dt class="text-sm font-medium text-gray-500">Type</dt>
                <dd class="mt-1 text-sm text-gray-900"><%= humanize_atom(@location.location_type) %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Region</dt>
                <dd class="mt-1 text-sm text-gray-900"><%= humanize_atom(@location.geographic_region) %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Status</dt>
                <dd class="mt-1 text-sm text-gray-900"><%= humanize_atom(@location.operational_status) %></dd>
              </div>
              <%= if @location.employee_count do %>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Employees</dt>
                  <dd class="mt-1 text-sm text-gray-900"><%= @location.employee_count %></dd>
                </div>
              <% end %>
              <%= if @location.postcode do %>
                <div>
                  <dt class="text-sm font-medium text-gray-500">Postcode</dt>
                  <dd class="mt-1 text-sm text-gray-900"><%= @location.postcode %></dd>
                </div>
              <% end %>
            </dl>
            
            <%= if @location.industry_activities && length(@location.industry_activities) > 0 do %>
              <div class="mt-4">
                <dt class="text-sm font-medium text-gray-500">Activities</dt>
                <dd class="mt-2 flex flex-wrap gap-2">
                  <%= for activity <- @location.industry_activities do %>
                    <span class="inline-flex items-center rounded-md bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-700/10">
                      <%= activity %>
                    </span>
                  <% end %>
                </dd>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Screening Status -->
        <div class="mt-8 bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-lg font-medium leading-6 text-gray-900">
                  Regulation Screening
                </h3>
                <p class="mt-1 text-sm text-gray-500">
                  Find regulations that apply to this specific location
                </p>
              </div>
              <div class="text-right">
                <%= if @law_count > 0 do %>
                  <div class="text-2xl font-bold text-blue-600"><%= @law_count %></div>
                  <div class="text-sm text-gray-500">potentially applicable laws</div>
                <% else %>
                  <div class="text-lg text-gray-400">Not screened yet</div>
                <% end %>
              </div>
            </div>

            <div class="mt-6 flex space-x-3">
              <%= if @screening_state == :ready do %>
                <.button phx-click="start_progressive_screening" class="bg-blue-600 hover:bg-blue-700">
                  <.icon name="hero-document-magnifying-glass" class="mr-2" />
                  Start Progressive Screening
                </.button>
                <.button phx-click="start_ai_screening" class="bg-green-600 hover:bg-green-700">
                  <.icon name="hero-chat-bubble-left-ellipsis" class="mr-2" />
                  AI Conversation Screening
                </.button>
              <% end %>

              <%= if @screening_state == :in_progress do %>
                <div class="flex items-center space-x-2">
                  <svg class="animate-spin h-5 w-5 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  <span class="text-sm text-gray-600">Screening in progress...</span>
                </div>
              <% end %>

              <%= if @screening_state == :completed do %>
                <.button phx-click="restart_screening" class="bg-gray-600 hover:bg-gray-700">
                  <.icon name="hero-arrow-path" class="mr-2" />
                  Restart Screening
                </.button>
                <.button phx-click="view_organization_aggregate" class="bg-purple-600 hover:bg-purple-700">
                  <.icon name="hero-building-office" class="mr-2" />
                  View Organization Summary
                </.button>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Screening Results -->
        <%= if @screening_state == :completed && @results do %>
          <div class="mt-8 bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Screening Results</h3>
              
              <div class="grid grid-cols-1 gap-5 sm:grid-cols-3">
                <div class="bg-blue-50 overflow-hidden shadow rounded-lg">
                  <div class="p-5">
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                        <.icon name="hero-scale" class="h-6 w-6 text-blue-600" />
                      </div>
                      <div class="ml-5 w-0 flex-1">
                        <dl>
                          <dt class="text-sm font-medium text-blue-500 truncate">Total Laws</dt>
                          <dd class="text-lg font-medium text-blue-900"><%= @results.total_applicable_laws || 0 %></dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="bg-yellow-50 overflow-hidden shadow rounded-lg">
                  <div class="p-5">
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                        <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-yellow-600" />
                      </div>
                      <div class="ml-5 w-0 flex-1">
                        <dl>
                          <dt class="text-sm font-medium text-yellow-500 truncate">High Priority</dt>
                          <dd class="text-lg font-medium text-yellow-900"><%= @results.high_priority_count || 0 %></dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="bg-green-50 overflow-hidden shadow rounded-lg">
                  <div class="p-5">
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                        <.icon name="hero-check-circle" class="h-6 w-6 text-green-600" />
                      </div>
                      <div class="ml-5 w-0 flex-1">
                        <dl>
                          <dt class="text-sm font-medium text-green-500 truncate">Screening Status</dt>
                          <dd class="text-lg font-medium text-green-900">Complete</dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <%= if @results.recommendations && length(@results.recommendations) > 0 do %>
                <div class="mt-6">
                  <h4 class="text-md font-medium text-gray-900 mb-3">Recommendations</h4>
                  <ul class="space-y-2">
                    <%= for recommendation <- @results.recommendations do %>
                      <li class="flex items-start space-x-3">
                        <div class="flex-shrink-0">
                          <.icon name="hero-light-bulb" class="h-5 w-5 text-yellow-500 mt-0.5" />
                        </div>
                        <div class="text-sm text-gray-700">
                          <%= recommendation.message || recommendation %>
                        </div>
                      </li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Multi-Location Context -->
        <%= if @is_multi_location do %>
          <div class="mt-8 bg-yellow-50 border-l-4 border-yellow-400 p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <.icon name="hero-information-circle" class="h-5 w-5 text-yellow-400" />
              </div>
              <div class="ml-3">
                <p class="text-sm text-yellow-700">
                  <strong>Multi-Location Organization:</strong> 
                  This screening covers regulations specific to the <%= @location.location_name %> location. 
                  For a complete compliance picture, view the 
                  <.link phx-click="view_organization_aggregate" class="underline font-medium">
                    organization-wide aggregate screening
                  </.link>
                  which combines and deduplicates laws from all your locations.
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"location_id" => location_id}, session, socket) do
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
    current_user = socket.assigns[:current_user]

    if current_user do
      case load_location_with_organization(location_id, current_user.id) do
        {:ok, location} ->
          # Calculate quick law count estimate
          law_count = estimate_location_law_count(location)
          
          {:ok,
           socket
           |> assign(:page_title, "Location Screening - #{location.location_name}")
           |> assign(:location, location)
           |> assign(:organization, location.organization)
           |> assign(:law_count, law_count)
           |> assign(:screening_state, :ready)
           |> assign(:results, nil)
           |> assign(:is_multi_location, is_multi_location?(location.organization))}

        {:error, :not_found} ->
          {:ok, 
           socket
           |> put_flash(:error, "Location not found or access denied")
           |> redirect(to: ~p"/organizations/locations")}
      end
    else
      {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def handle_event("start_progressive_screening", _params, socket) do
    location = socket.assigns.location
    
    # Start progressive screening simulation
    send(self(), {:run_progressive_screening, location})
    
    {:noreply,
     socket
     |> assign(:screening_state, :in_progress)
     |> put_flash(:info, "Starting progressive screening for #{location.location_name}...")}
  end

  @impl true
  def handle_event("start_ai_screening", _params, socket) do
    location = socket.assigns.location
    
    # Redirect to progressive screening with location context (AI-enhanced screening)
    {:noreply, redirect(socket, to: ~p"/applicability/location/#{location.id}/progressive")}
  end

  @impl true
  def handle_event("restart_screening", _params, socket) do
    {:noreply,
     socket
     |> assign(:screening_state, :ready)
     |> assign(:results, nil)}
  end

  @impl true
  def handle_event("view_organization_aggregate", _params, socket) do
    {:noreply, redirect(socket, to: ~p"/applicability/organization/aggregate")}
  end

  @impl true
  def handle_info({:run_progressive_screening, location}, socket) do
    # Simulate progressive screening for this location
    Process.sleep(2000) # Simulate processing time
    
    results = simulate_location_screening_results(location)
    
    {:noreply,
     socket
     |> assign(:screening_state, :completed)
     |> assign(:results, results)
     |> assign(:law_count, results.total_applicable_laws)
     |> put_flash(:info, "Screening completed for #{location.location_name}")}
  end

  defp load_location_with_organization(location_id, user_id) do
    case Ash.get(OrganizationLocation, location_id, domain: Organizations, load: [:organization]) do
      {:ok, location} ->
        # Verify the user owns this organization
        if location.organization.created_by_user_id == user_id do
          {:ok, location}
        else
          {:error, :not_found}
        end
      
      {:error, _} ->
        {:error, :not_found}
    end
  end

  defp is_multi_location?(organization) do
    case SingleLocationAdapter.interface_mode(organization) do
      :multi_location -> true
      _ -> false
    end
  end

  defp estimate_location_law_count(location) do
    # Simple estimation based on location characteristics
    base_count = case location.location_type do
      :headquarters -> 45
      :manufacturing_site -> 65
      :retail_outlet -> 35
      :warehouse -> 25
      _ -> 30
    end
    
    # Adjust for region
    region_modifier = case location.geographic_region do
      "england" -> 1.0
      "scotland" -> 1.1
      "wales" -> 0.9
      "northern_ireland" -> 0.8
      _ -> 1.0
    end
    
    # Adjust for employee count
    employee_modifier = case location.employee_count do
      count when count == nil -> 1.0
      count when count < 10 -> 0.7
      count when count < 50 -> 1.0
      count when count < 250 -> 1.3
      _ -> 1.5
    end
    
    trunc(base_count * region_modifier * employee_modifier)
  end

  defp simulate_location_screening_results(location) do
    total_laws = estimate_location_law_count(location)
    high_priority = max(1, trunc(total_laws * 0.15))
    
    %{
      location_id: location.id,
      location_name: location.location_name,
      screening_type: :location_specific,
      total_applicable_laws: total_laws,
      high_priority_count: high_priority,
      screening_results: %{
        geographic_laws: trunc(total_laws * 0.3),
        activity_laws: trunc(total_laws * 0.4),
        size_laws: trunc(total_laws * 0.2),
        environmental_laws: trunc(total_laws * 0.1)
      },
      recommendations: [
        %{
          priority: :high,
          category: :regulatory_compliance,
          message: "Review #{location.geographic_region |> String.capitalize()} specific employment regulations for #{location.location_type |> humanize_atom()} operations"
        },
        %{
          priority: :medium,
          category: :operational_requirements,
          message: "Ensure location-specific health and safety compliance for #{location.employee_count || "current"} employees"
        },
        %{
          priority: :low,
          category: :documentation,
          message: "Update location documentation to reflect current operational scope"
        }
      ]
    }
  end

  defp humanize_atom(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize_atom(string) when is_binary(string) do
    string
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end