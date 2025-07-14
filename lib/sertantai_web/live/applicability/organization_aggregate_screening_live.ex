defmodule SertantaiWeb.Applicability.OrganizationAggregateScreeningLive do
  @moduledoc """
  LiveView for conducting organization-wide applicability screening.
  Aggregates laws from all locations and provides 'all up' view with deduplication.
  """
  use SertantaiWeb, :live_view
  
  alias Sertantai.Organizations
  require Ash.Query

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-5xl">
        <.header>
          Organization-Wide Screening
          <:subtitle>
            Comprehensive regulatory screening across all <%= @organization.organization_name %> locations
          </:subtitle>
          <:actions>
            <.link navigate={~p"/organizations/locations"} class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700">
              ← Manage Locations
            </.link>
          </:actions>
        </.header>

        <!-- Organization Overview -->
        <div class="mt-8 bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Organization Overview</h3>
            <dl class="grid grid-cols-1 gap-x-4 gap-y-3 sm:grid-cols-4">
              <div>
                <dt class="text-sm font-medium text-gray-500">Organization</dt>
                <dd class="mt-1 text-sm text-gray-900"><%= @organization.organization_name %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Total Locations</dt>
                <dd class="mt-1 text-sm text-gray-900"><%= @total_locations %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Active Locations</dt>
                <dd class="mt-1 text-sm text-gray-900"><%= @active_locations %></dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Organization Type</dt>
                <dd class="mt-1 text-sm text-gray-900">
                  <%= @organization.core_profile["organization_type"] |> humanize_atom() %>
                </dd>
              </div>
            </dl>
          </div>
        </div>

        <!-- Aggregate Screening Status -->
        <div class="mt-8 bg-white shadow sm:rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-lg font-medium leading-6 text-gray-900">
                  Aggregate Compliance Screening
                </h3>
                <p class="mt-1 text-sm text-gray-500">
                  Consolidated regulatory requirements across all organization locations
                </p>
              </div>
              <div class="text-right">
                <%= if @aggregate_law_count > 0 do %>
                  <div class="text-3xl font-bold text-purple-600"><%= @aggregate_law_count %></div>
                  <div class="text-sm text-gray-500">unique applicable laws</div>
                <% else %>
                  <div class="text-lg text-gray-400">Not screened yet</div>
                <% end %>
              </div>
            </div>

            <div class="mt-6 flex space-x-3">
              <%= if @screening_state == :ready do %>
                <.button phx-click="start_aggregate_screening" class="bg-purple-600 hover:bg-purple-700">
                  <.icon name="hero-building-office" class="mr-2" />
                  Start Organization Screening
                </.button>
                <.button phx-click="screen_individual_locations" class="bg-blue-600 hover:bg-blue-700">
                  <.icon name="hero-map-pin" class="mr-2" />
                  Screen Individual Locations
                </.button>
              <% end %>

              <%= if @screening_state == :in_progress do %>
                <div class="flex items-center space-x-2">
                  <svg class="animate-spin h-5 w-5 text-purple-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  <span class="text-sm text-gray-600">Aggregating regulations across all locations...</span>
                </div>
              <% end %>

              <%= if @screening_state == :completed do %>
                <.button phx-click="restart_screening" class="bg-gray-600 hover:bg-gray-700">
                  <.icon name="hero-arrow-path" class="mr-2" />
                  Restart Screening
                </.button>
                <.button phx-click="export_results" class="bg-green-600 hover:bg-green-700">
                  <.icon name="hero-document-arrow-down" class="mr-2" />
                  Export Results
                </.button>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Location Breakdown -->
        <%= if @locations && length(@locations) > 0 do %>
          <div class="mt-8 bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Location Breakdown</h3>
              <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                <%= for location <- @locations do %>
                  <div class="relative rounded-lg border border-gray-300 bg-white px-6 py-5 shadow-sm flex items-center space-x-3 hover:border-gray-400">
                    <div class="flex-shrink-0">
                      <div class="h-10 w-10 rounded-full bg-purple-100 flex items-center justify-center">
                        <%= if location.is_primary_location do %>
                          <.icon name="hero-star" class="h-5 w-5 text-purple-600" />
                        <% else %>
                          <.icon name="hero-map-pin" class="h-5 w-5 text-purple-600" />
                        <% end %>
                      </div>
                    </div>
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center justify-between">
                        <p class="text-sm font-medium text-gray-900">
                          <%= location.location_name %>
                          <%= if location.is_primary_location do %>
                            <span class="ml-1 text-xs text-purple-600">(Primary)</span>
                          <% end %>
                        </p>
                        <%= if @location_breakdown[location.id] do %>
                          <span class="text-sm font-semibold text-purple-600">
                            <%= @location_breakdown[location.id].law_count %>
                          </span>
                        <% end %>
                      </div>
                      <p class="text-sm text-gray-500"><%= humanize_atom(location.location_type) %></p>
                      <div class="flex items-center justify-between mt-1">
                        <span class="text-xs text-gray-400"><%= location.geographic_region %></span>
                        <.link navigate={~p"/applicability/location/#{location.id}"} 
                              class="text-xs text-purple-600 hover:text-purple-900">
                          Screen →
                        </.link>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Aggregate Results -->
        <%= if @screening_state == :completed && @results do %>
          <div class="mt-8 space-y-6">
            <!-- Summary Stats -->
            <div class="bg-white shadow sm:rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Aggregate Results</h3>
                
                <div class="grid grid-cols-1 gap-5 sm:grid-cols-4">
                  <div class="bg-purple-50 overflow-hidden shadow rounded-lg">
                    <div class="p-5">
                      <div class="flex items-center">
                        <div class="flex-shrink-0">
                          <.icon name="hero-scale" class="h-6 w-6 text-purple-600" />
                        </div>
                        <div class="ml-5 w-0 flex-1">
                          <dl>
                            <dt class="text-sm font-medium text-purple-500 truncate">Total Unique Laws</dt>
                            <dd class="text-lg font-medium text-purple-900"><%= @results.total_applicable_laws || 0 %></dd>
                          </dl>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div class="bg-blue-50 overflow-hidden shadow rounded-lg">
                    <div class="p-5">
                      <div class="flex items-center">
                        <div class="flex-shrink-0">
                          <.icon name="hero-building-office" class="h-6 w-6 text-blue-600" />
                        </div>
                        <div class="ml-5 w-0 flex-1">
                          <dl>
                            <dt class="text-sm font-medium text-blue-500 truncate">Org-Level Laws</dt>
                            <dd class="text-lg font-medium text-blue-900"><%= @results.organization_wide_laws || 0 %></dd>
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
                            <dt class="text-sm font-medium text-green-500 truncate">Deduplication</dt>
                            <dd class="text-lg font-medium text-green-900"><%= @results.deduplicated_count || 0 %></dd>
                          </dl>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Recommendations -->
            <%= if @results.recommendations && length(@results.recommendations) > 0 do %>
              <div class="bg-white shadow sm:rounded-lg">
                <div class="px-4 py-5 sm:p-6">
                  <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Priority Recommendations</h3>
                  <div class="space-y-4">
                    <%= for recommendation <- @results.recommendations do %>
                      <div class="flex items-start space-x-3">
                        <div class="flex-shrink-0">
                          <%= case recommendation.priority do %>
                            <% :high -> %>
                              <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-red-500 mt-0.5" />
                            <% :medium -> %>
                              <.icon name="hero-exclamation-circle" class="h-5 w-5 text-yellow-500 mt-0.5" />
                            <% _ -> %>
                              <.icon name="hero-information-circle" class="h-5 w-5 text-blue-500 mt-0.5" />
                          <% end %>
                        </div>
                        <div class="flex-1">
                          <p class="text-sm font-medium text-gray-900">
                            <%= String.capitalize(to_string(recommendation.priority)) %> Priority - <%= humanize_atom(recommendation.category) %>
                          </p>
                          <p class="text-sm text-gray-600 mt-1">
                            <%= recommendation.message %>
                          </p>
                          <%= if recommendation.locations do %>
                            <p class="text-xs text-gray-500 mt-1">
                              Affects: <%= Enum.join(recommendation.locations, ", ") %>
                            </p>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- Location Comparison -->
            <%= if @results.location_breakdown do %>
              <div class="bg-white shadow sm:rounded-lg">
                <div class="px-4 py-5 sm:p-6">
                  <h3 class="text-lg font-medium leading-6 text-gray-900 mb-4">Location Comparison</h3>
                  <div class="overflow-hidden">
                    <table class="min-w-full divide-y divide-gray-300">
                      <thead class="bg-gray-50">
                        <tr>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Location</th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Applicable Laws</th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">High Priority</th>
                          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                        </tr>
                      </thead>
                      <tbody class="bg-white divide-y divide-gray-200">
                        <%= for {location_id, breakdown} <- @results.location_breakdown do %>
                          <% location = Enum.find(@locations, &(&1.id == location_id)) %>
                          <tr>
                            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                              <%= location.location_name %>
                              <%= if location.is_primary_location do %>
                                <span class="ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-purple-100 text-purple-800">
                                  Primary
                                </span>
                              <% end %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              <%= humanize_atom(location.location_type) %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                              <%= breakdown.law_count %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                              <%= breakdown.high_priority_count %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                              <.link navigate={~p"/applicability/location/#{location.id}"} 
                                    class="text-purple-600 hover:text-purple-900">
                                View Details
                              </.link>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)
    current_user = socket.assigns[:current_user]

    if current_user do
      case load_user_organization_with_locations(current_user.id) do
        {:ok, organization} ->
          locations = organization.locations || []
          total_locations = length(locations)
          active_locations = count_active_locations(locations)
          aggregate_count = calculate_aggregate_law_count(organization)
          
          {:ok,
           socket
           |> assign(:page_title, "Organization-Wide Screening")
           |> assign(:organization, organization)
           |> assign(:locations, locations)
           |> assign(:total_locations, total_locations)
           |> assign(:active_locations, active_locations)
           |> assign(:aggregate_law_count, aggregate_count)
           |> assign(:screening_state, :ready)
           |> assign(:results, nil)
           |> assign(:location_breakdown, %{})}

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
  def handle_event("start_aggregate_screening", _params, socket) do
    organization = socket.assigns.organization
    
    # Start aggregate screening simulation
    send(self(), {:run_aggregate_screening, organization})
    
    {:noreply,
     socket
     |> assign(:screening_state, :in_progress)
     |> put_flash(:info, "Starting organization-wide screening...")}
  end

  @impl true
  def handle_event("screen_individual_locations", _params, socket) do
    {:noreply, redirect(socket, to: ~p"/organizations/locations")}
  end

  @impl true
  def handle_event("restart_screening", _params, socket) do
    {:noreply,
     socket
     |> assign(:screening_state, :ready)
     |> assign(:results, nil)
     |> assign(:location_breakdown, %{})}
  end

  @impl true
  def handle_event("export_results", _params, socket) do
    {:noreply, put_flash(socket, :info, "Export functionality coming soon")}
  end

  @impl true
  def handle_info({:run_aggregate_screening, organization}, socket) do
    # Simulate aggregate screening across all locations
    Process.sleep(3000) # Simulate processing time
    
    results = simulate_aggregate_screening_results(organization)
    location_breakdown = generate_location_breakdown(organization.locations)
    
    {:noreply,
     socket
     |> assign(:screening_state, :completed)
     |> assign(:results, results)
     |> assign(:location_breakdown, location_breakdown)
     |> assign(:aggregate_law_count, results.total_applicable_laws)
     |> put_flash(:info, "Organization-wide screening completed")}
  end

  defp load_user_organization_with_locations(user_id) do
    Organization
    |> Ash.Query.filter(created_by_user_id == ^user_id)
    |> Ash.Query.load([:locations])
    |> Ash.read_one(domain: Organizations)
  end

  defp count_active_locations(locations) do
    Enum.count(locations, &(&1.operational_status == :active))
  end

  defp calculate_aggregate_law_count(organization) do
    # Simple aggregation simulation
    case organization.locations do
      [] -> 0
      locations ->
        locations
        |> Enum.filter(&(&1.operational_status == :active))
        |> Enum.map(&estimate_location_law_count/1)
        |> Enum.sum()
        |> then(&trunc(&1 * 0.8)) # Simulate deduplication (20% overlap)
    end
  end

  defp estimate_location_law_count(location) do
    base_count = case location.location_type do
      :headquarters -> 45
      :manufacturing_site -> 65
      :retail_outlet -> 35
      :warehouse -> 25
      _ -> 30
    end
    
    employee_modifier = case location.employee_count do
      count when count == nil -> 1.0
      count when count < 10 -> 0.7
      count when count < 50 -> 1.0
      count when count < 250 -> 1.3
      _ -> 1.5
    end
    
    trunc(base_count * employee_modifier)
  end

  defp simulate_aggregate_screening_results(organization) do
    locations = organization.locations || []
    active_locations = Enum.filter(locations, &(&1.operational_status == :active))
    
    # Calculate individual location results
    location_results = Enum.map(active_locations, &estimate_location_law_count/1)
    total_without_deduplication = Enum.sum(location_results)
    
    # Simulate deduplication (laws that apply to multiple locations)
    deduplication_factor = case length(active_locations) do
      1 -> 1.0
      2 -> 0.85
      3 -> 0.75
      _ -> 0.7
    end
    
    total_unique_laws = trunc(total_without_deduplication * deduplication_factor)
    organization_wide_laws = 15 # Laws that apply at organizational level
    deduplicated_count = total_without_deduplication - total_unique_laws
    
    %{
      organization_id: organization.id,
      screening_type: :organization_aggregate,
      total_applicable_laws: total_unique_laws + organization_wide_laws,
      organization_wide_laws: organization_wide_laws,
      high_priority_count: trunc((total_unique_laws + organization_wide_laws) * 0.18),
      deduplicated_count: deduplicated_count,
      location_breakdown: generate_location_breakdown_data(active_locations),
      recommendations: generate_aggregate_recommendations(organization, active_locations)
    }
  end

  defp generate_location_breakdown(locations) do
    locations
    |> Enum.filter(&(&1.operational_status == :active))
    |> Enum.into(%{}, fn location ->
      law_count = estimate_location_law_count(location)
      {location.id, %{
        law_count: law_count,
        high_priority_count: max(1, trunc(law_count * 0.15))
      }}
    end)
  end

  defp generate_location_breakdown_data(locations) do
    Enum.into(locations, %{}, fn location ->
      law_count = estimate_location_law_count(location)
      {location.id, %{
        law_count: law_count,
        high_priority_count: max(1, trunc(law_count * 0.15)),
        location_name: location.location_name
      }}
    end)
  end

  defp generate_aggregate_recommendations(_organization, locations) do
    [
      %{
        priority: :high,
        category: :organizational_governance,
        message: "Implement organization-wide compliance management system to coordinate requirements across #{length(locations)} locations",
        locations: Enum.map(locations, &(&1.location_name))
      },
      %{
        priority: :medium,
        category: :data_protection,
        message: "Establish unified data protection policies that cover operations in #{get_unique_regions(locations)} regions",
        locations: get_unique_regions(locations)
      },
      %{
        priority: :medium,
        category: :employee_relations,
        message: "Review employment law compliance across different location types and employee counts",
        locations: get_variable_employee_locations(locations)
      },
      %{
        priority: :low,
        category: :documentation,
        message: "Standardize compliance documentation and reporting across all organizational locations",
        locations: Enum.map(locations, &(&1.location_name))
      }
    ]
  end

  defp get_unique_regions(locations) do
    locations
    |> Enum.map(&(&1.geographic_region))
    |> Enum.uniq()
    |> Enum.map(&humanize_atom/1)
  end

  defp get_variable_employee_locations(locations) do
    locations
    |> Enum.filter(&(&1.employee_count && &1.employee_count > 10))
    |> Enum.map(&(&1.location_name))
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