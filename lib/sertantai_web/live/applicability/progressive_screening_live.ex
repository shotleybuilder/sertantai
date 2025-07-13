defmodule SertantaiWeb.Applicability.ProgressiveScreeningLive do
  @moduledoc """
  Phase 2 Progressive Applicability Screening LiveView.
  
  Provides real-time progressive screening with adaptive complexity,
  interactive profile completion, and live result streaming.
  """
  use SertantaiWeb, :live_view

  alias Sertantai.Organizations.ApplicabilityMatcher
  alias Sertantai.Organizations.ProfileAnalyzer
  alias Sertantai.Query.{ProgressiveQueryBuilder, ResultStreamer}
  alias Phoenix.PubSub

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to applicability result updates
      PubSub.subscribe(Sertantai.PubSub, "applicability_results")
    end

    initial_organization = %{
      core_profile: %{
        "organization_name" => "",
        "organization_type" => "",
        "headquarters_region" => "",
        "industry_sector" => ""
      }
    }

    socket =
      socket
      |> assign(:organization, initial_organization)
      |> assign(:profile_analysis, nil)
      |> assign(:screening_results, nil)
      |> assign(:stream_status, :idle)
      |> assign(:current_step, 1)
      |> assign(:max_steps, 4)
      |> assign(:errors, %{})
      |> assign(:debounce_timer, nil)
      |> assign(:loading_state, nil)
      |> assign(:complexity_score, nil)
      |> assign(:recommendations, [])
      |> assign(:phase2_enabled, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_field", %{"field" => field, "value" => value}, socket) do
    # Update organization profile field
    updated_organization = put_in(socket.assigns.organization, [:core_profile, field], value)
    
    # Cancel existing debounce timer
    if socket.assigns.debounce_timer do
      Process.cancel_timer(socket.assigns.debounce_timer)
    end
    
    # Set new debounce timer for analysis
    timer = Process.send_after(self(), {:analyze_profile, updated_organization}, 800)
    
    socket =
      socket
      |> assign(:organization, updated_organization)
      |> assign(:debounce_timer, timer)
      |> assign(:loading_state, "Analyzing profile...")
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    current_step = socket.assigns.current_step
    max_steps = socket.assigns.max_steps
    
    new_step = min(current_step + 1, max_steps)
    
    # Enable Phase 2 fields when reaching step 3
    phase2_enabled = new_step >= 3
    
    socket =
      socket
      |> assign(:current_step, new_step)
      |> assign(:phase2_enabled, phase2_enabled)
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    current_step = socket.assigns.current_step
    new_step = max(current_step - 1, 1)
    
    # Disable Phase 2 fields when going back to earlier steps
    phase2_enabled = new_step >= 3
    
    socket =
      socket
      |> assign(:current_step, new_step)
      |> assign(:phase2_enabled, phase2_enabled)
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_progressive_screening", _params, socket) do
    organization = socket.assigns.organization
    
    # Start progressive screening stream
    case ApplicabilityMatcher.start_progressive_stream(organization, self()) do
      %{stream_id: stream_id} = stream_info ->
        socket =
          socket
          |> assign(:stream_status, :active)
          |> assign(:stream_id, stream_id)
          |> assign(:loading_state, "Starting progressive screening...")
        
        {:noreply, socket}
      
      _error ->
        socket =
          socket
          |> assign(:stream_status, :error)
          |> assign(:loading_state, nil)
          |> put_flash(:error, "Failed to start progressive screening")
        
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reset_form", _params, socket) do
    initial_organization = %{
      core_profile: %{
        "organization_name" => "",
        "organization_type" => "",
        "headquarters_region" => "",
        "industry_sector" => ""
      }
    }
    
    socket =
      socket
      |> assign(:organization, initial_organization)
      |> assign(:profile_analysis, nil)
      |> assign(:screening_results, nil)
      |> assign(:stream_status, :idle)
      |> assign(:current_step, 1)
      |> assign(:loading_state, nil)
      |> assign(:complexity_score, nil)
      |> assign(:recommendations, [])
      |> assign(:phase2_enabled, false)
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:analyze_profile, organization}, socket) do
    # Perform profile analysis
    analysis = ApplicabilityMatcher.analyze_organization_profile(organization)
    complexity_score = ApplicabilityMatcher.analyze_query_complexity(organization)
    recommendations = ApplicabilityMatcher.generate_profile_recommendations(organization)
    
    socket =
      socket
      |> assign(:profile_analysis, analysis)
      |> assign(:complexity_score, complexity_score)
      |> assign(:recommendations, recommendations)
      |> assign(:loading_state, nil)
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:applicability_stream_event, event_type, data}, socket) do
    case event_type do
      :stream_started ->
        socket =
          socket
          |> assign(:loading_state, "Progressive screening started...")
          |> assign(:stream_status, :running)
        
        {:noreply, socket}
      
      :phase_started ->
        phase_name = String.capitalize(to_string(data.phase))
        socket =
          socket
          |> assign(:loading_state, "#{phase_name} screening in progress...")
        
        {:noreply, socket}
      
      :phase_completed ->
        phase_name = String.capitalize(to_string(data.phase))
        
        socket =
          socket
          |> assign(:screening_results, data.results)
          |> assign(:loading_state, 
            if data.next_phase do
              next_phase = String.capitalize(to_string(data.next_phase))
              "#{phase_name} complete. Starting #{next_phase}..."
            else
              "#{phase_name} screening complete"
            end
          )
        
        {:noreply, socket}
      
      :stream_completed ->
        socket =
          socket
          |> assign(:stream_status, :completed)
          |> assign(:loading_state, nil)
          |> put_flash(:info, "Progressive screening completed successfully")
        
        {:noreply, socket}
      
      :stream_error ->
        socket =
          socket
          |> assign(:stream_status, :error)
          |> assign(:loading_state, nil)
          |> put_flash(:error, "Screening error: #{data.error}")
        
        {:noreply, socket}
      
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:profile_change_notification, impact_analysis}, socket) do
    socket =
      socket
      |> put_flash(:info, "Profile change detected: #{impact_analysis.recommendation}")
    
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  # Helper functions for template

  def step_title(1), do: "Basic Information"
  def step_title(2), do: "Industry & Location"
  def step_title(3), do: "Enhanced Profile"
  def step_title(4), do: "Review & Screen"

  def step_description(1), do: "Enter your organization's basic details"
  def step_description(2), do: "Specify industry sector and geographic information"
  def step_description(3), do: "Provide additional details for enhanced screening accuracy"
  def step_description(4), do: "Review your profile and start progressive screening"

  def step_valid?(socket, step) do
    profile = socket.assigns.organization.core_profile
    
    case step do
      1 -> 
        Map.get(profile, "organization_name", "") != "" &&
        Map.get(profile, "organization_type", "") != ""
      
      2 -> 
        step_valid?(socket, 1) &&
        Map.get(profile, "headquarters_region", "") != "" &&
        Map.get(profile, "industry_sector", "") != ""
      
      3 -> step_valid?(socket, 2)
      4 -> step_valid?(socket, 2)  # Minimum requirement for screening
      _ -> false
    end
  end

  def get_progress_percentage(socket) do
    if socket.assigns.complexity_score do
      round(socket.assigns.complexity_score.total_score * 100)
    else
      0
    end
  end

  def get_readiness_status(socket) do
    if socket.assigns.profile_analysis do
      socket.assigns.profile_analysis.screening_readiness.recommended_level
    else
      :insufficient_data
    end
  end

  def format_readiness_status(:basic), do: "Ready for Basic Screening"
  def format_readiness_status(:enhanced), do: "Ready for Enhanced Screening"
  def format_readiness_status(:comprehensive), do: "Ready for Comprehensive Screening"
  def format_readiness_status(:insufficient_data), do: "Insufficient Data"

  def get_readiness_color(:basic), do: "text-yellow-600"
  def get_readiness_color(:enhanced), do: "text-blue-600"
  def get_readiness_color(:comprehensive), do: "text-green-600"
  def get_readiness_color(:insufficient_data), do: "text-gray-500"

  def get_organization_types do
    ApplicabilityMatcher.get_organization_types()
  end

  def get_supported_regions do
    ApplicabilityMatcher.get_supported_regions()
  end

  def get_supported_industry_sectors do
    ApplicabilityMatcher.get_supported_industry_sectors()
  end

  def format_law_count(nil), do: "—"
  def format_law_count(count) when is_integer(count), do: Integer.to_string(count)
  def format_law_count(_), do: "—"

  def screening_method_badge("progressive_basic"), do: "Basic"
  def screening_method_badge("progressive_enhanced"), do: "Enhanced"
  def screening_method_badge("progressive_comprehensive"), do: "Comprehensive"
  def screening_method_badge(_), do: "Standard"

  def confidence_level_color("basic"), do: "bg-yellow-100 text-yellow-800"
  def confidence_level_color("enhanced"), do: "bg-blue-100 text-blue-800"
  def confidence_level_color("high"), do: "bg-green-100 text-green-800"
  def confidence_level_color(_), do: "bg-gray-100 text-gray-800"

  def get_analysis_status(socket) do
    cond do
      socket.assigns.loading_state -> :analyzing
      socket.assigns.profile_analysis && socket.assigns.complexity_score -> :complete
      socket.assigns.profile_analysis -> :insufficient
      true -> :ready
    end
  end

  # Render functions for template steps

  def render_step_1(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label for="organization_name" class="block text-sm font-medium text-gray-700 mb-2">
          Organization Name *
        </label>
        <input 
          type="text" 
          id="organization_name"
          phx-change="update_field"
          phx-value-field="organization_name"
          value={@organization.core_profile["organization_name"]}
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
          placeholder="Enter your organization name"
        />
      </div>

      <div>
        <label for="organization_type" class="block text-sm font-medium text-gray-700 mb-2">
          Organization Type *
        </label>
        <select 
          id="organization_type"
          phx-change="update_field"
          phx-value-field="organization_type"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
        >
          <option value="">Select organization type</option>
          <%= for {label, value} <- get_organization_types() do %>
            <option value={value} selected={@organization.core_profile["organization_type"] == value}>
              <%= label %>
            </option>
          <% end %>
        </select>
      </div>
    </div>
    """
  end

  def render_step_2(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label for="headquarters_region" class="block text-sm font-medium text-gray-700 mb-2">
          Headquarters Region *
        </label>
        <select 
          id="headquarters_region"
          phx-change="update_field"
          phx-value-field="headquarters_region"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
        >
          <option value="">Select headquarters region</option>
          <%= for {label, value} <- get_supported_regions() do %>
            <option value={value} selected={@organization.core_profile["headquarters_region"] == value}>
              <%= label %>
            </option>
          <% end %>
        </select>
      </div>

      <div>
        <label for="industry_sector" class="block text-sm font-medium text-gray-700 mb-2">
          Industry Sector *
        </label>
        <select 
          id="industry_sector"
          phx-change="update_field"
          phx-value-field="industry_sector"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
        >
          <option value="">Select industry sector</option>
          <%= for {label, value} <- get_supported_industry_sectors() do %>
            <option value={value} selected={@organization.core_profile["industry_sector"] == value}>
              <%= label %>
            </option>
          <% end %>
        </select>
      </div>
    </div>
    """
  end

  def render_step_3(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <label for="total_employees" class="block text-sm font-medium text-gray-700 mb-2">
            Total Employees
          </label>
          <input 
            type="number" 
            id="total_employees"
            phx-change="update_field"
            phx-value-field="total_employees"
            value={@organization.core_profile["total_employees"]}
            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            placeholder="e.g., 50"
          />
        </div>

        <div>
          <label for="annual_turnover" class="block text-sm font-medium text-gray-700 mb-2">
            Annual Turnover (£)
          </label>
          <input 
            type="number" 
            id="annual_turnover"
            phx-change="update_field"
            phx-value-field="annual_turnover"
            value={@organization.core_profile["annual_turnover"]}
            class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            placeholder="e.g., 1000000"
          />
        </div>
      </div>

      <div>
        <label for="registration_number" class="block text-sm font-medium text-gray-700 mb-2">
          Registration Number
        </label>
        <input 
          type="text" 
          id="registration_number"
          phx-change="update_field"
          phx-value-field="registration_number"
          value={@organization.core_profile["registration_number"]}
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
          placeholder="Company registration number"
        />
      </div>

      <div>
        <label for="primary_sic_code" class="block text-sm font-medium text-gray-700 mb-2">
          Primary SIC Code
        </label>
        <input 
          type="text" 
          id="primary_sic_code"
          phx-change="update_field"
          phx-value-field="primary_sic_code"
          value={@organization.core_profile["primary_sic_code"]}
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
          placeholder="e.g., 41201"
        />
      </div>

      <%= if @phase2_enabled do %>
        <div class="border-t pt-6">
          <h4 class="text-lg font-medium text-gray-900 mb-4">Enhanced Profile (Phase 2)</h4>
          
          <div>
            <label for="operational_regions" class="block text-sm font-medium text-gray-700 mb-2">
              Operational Regions
            </label>
            <input 
              type="text" 
              id="operational_regions"
              phx-change="update_field"
              phx-value-field="operational_regions"
              value={@organization.core_profile["operational_regions"]}
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
              placeholder="e.g., England, Wales (comma-separated)"
            />
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def render_step_4(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Profile Summary -->
      <div class="bg-gray-50 rounded-lg p-4">
        <h4 class="text-lg font-medium text-gray-900 mb-3">Profile Summary</h4>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
          <div>
            <span class="font-medium text-gray-700">Organization:</span>
            <span class="ml-2 text-gray-600"><%= @organization.core_profile["organization_name"] %></span>
          </div>
          <div>
            <span class="font-medium text-gray-700">Type:</span>
            <span class="ml-2 text-gray-600"><%= @organization.core_profile["organization_type"] %></span>
          </div>
          <div>
            <span class="font-medium text-gray-700">Region:</span>
            <span class="ml-2 text-gray-600"><%= @organization.core_profile["headquarters_region"] %></span>
          </div>
          <div>
            <span class="font-medium text-gray-700">Sector:</span>
            <span class="ml-2 text-gray-600"><%= @organization.core_profile["industry_sector"] %></span>
          </div>
        </div>
      </div>

      <!-- Readiness Assessment -->
      <%= if @profile_analysis do %>
        <div class="bg-blue-50 rounded-lg p-4">
          <h4 class="text-lg font-medium text-gray-900 mb-3">Screening Readiness</h4>
          <div class="flex items-center space-x-3">
            <span class={"inline-flex px-2 py-1 text-xs font-medium rounded-full #{get_readiness_color(get_readiness_status(@socket))}"}>
              <%= format_readiness_status(get_readiness_status(@socket)) %>
            </span>
            <span class="text-sm text-gray-600">
              Profile Completeness: <%= get_progress_percentage(@socket) %>%
            </span>
          </div>
        </div>
      <% end %>

      <!-- Recommendations -->
      <%= if length(@recommendations) > 0 do %>
        <div class="bg-yellow-50 rounded-lg p-4">
          <h4 class="text-lg font-medium text-gray-900 mb-3">Recommendations</h4>
          <ul class="space-y-2">
            <%= for recommendation <- @recommendations do %>
              <li class="flex items-start space-x-2 text-sm">
                <div class="w-1.5 h-1.5 bg-yellow-400 rounded-full mt-2 flex-shrink-0"></div>
                <span class="text-gray-700"><%= recommendation %></span>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
    """
  end

  def render_analysis_panel(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Complexity Score -->
      <%= if @complexity_score do %>
        <div>
          <h4 class="text-lg font-medium text-gray-900 mb-3">Query Complexity Analysis</h4>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="bg-gray-50 rounded-lg p-3">
              <div class="text-sm font-medium text-gray-700">Total Score</div>
              <div class="text-2xl font-bold text-blue-600">
                <%= :erlang.float_to_binary(@complexity_score.total_score, decimals: 2) %>
              </div>
            </div>
            <div class="bg-gray-50 rounded-lg p-3">
              <div class="text-sm font-medium text-gray-700">Recommended Level</div>
              <div class="text-lg font-semibold text-gray-900 capitalize">
                <%= @complexity_score.recommended_complexity %>
              </div>
            </div>
            <div class="bg-gray-50 rounded-lg p-3">
              <div class="text-sm font-medium text-gray-700">Data Quality</div>
              <div class="text-lg font-semibold text-gray-900">
                <%= :erlang.float_to_binary(@complexity_score.data_quality, decimals: 1) %>/1.0
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Screening Results -->
      <%= if @screening_results do %>
        <div>
          <h4 class="text-lg font-medium text-gray-900 mb-3">Screening Results</h4>
          <div class="bg-white border border-gray-200 rounded-lg p-4">
            <div class="flex items-center justify-between mb-4">
              <div>
                <div class="text-3xl font-bold text-green-600">
                  <%= format_law_count(@screening_results.applicable_law_count) %>
                </div>
                <div class="text-sm text-gray-600">Applicable Laws</div>
              </div>
              <div class="flex space-x-2">
                <span class={"inline-flex px-2 py-1 text-xs font-medium rounded-full #{confidence_level_color(@screening_results.confidence_level)}"}>
                  <%= String.capitalize(@screening_results.confidence_level) %>
                </span>
                <span class="inline-flex px-2 py-1 text-xs font-medium rounded-full bg-blue-100 text-blue-800">
                  <%= screening_method_badge(@screening_results.screening_method) %>
                </span>
              </div>
            </div>

            <%= if @screening_results.performance_metadata do %>
              <div class="text-xs text-gray-500 border-t pt-2">
                Execution time: <%= @screening_results.performance_metadata.execution_time_ms %>ms
                | Complexity: <%= @screening_results.performance_metadata.complexity_level %>
              </div>
            <% end %>

            <%= if length(@screening_results.sample_regulations || []) > 0 do %>
              <div class="mt-4">
                <h5 class="text-sm font-medium text-gray-700 mb-2">Sample Regulations</h5>
                <div class="space-y-2 max-h-40 overflow-y-auto">
                  <%= for regulation <- @screening_results.sample_regulations do %>
                    <div class="text-sm bg-gray-50 rounded p-2">
                      <div class="font-medium text-gray-900"><%= regulation.title_en || regulation.name %></div>
                      <%= if regulation.family do %>
                        <div class="text-xs text-gray-600 mt-1">Family: <%= regulation.family %></div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Stream Status -->
      <%= if @stream_status != :idle do %>
        <div class="text-center py-4">
          <div class={"inline-flex items-center px-3 py-1 rounded-full text-sm font-medium #{
            case @stream_status do
              :active -> "bg-blue-100 text-blue-800"
              :running -> "bg-yellow-100 text-yellow-800"
              :completed -> "bg-green-100 text-green-800"
              :error -> "bg-red-100 text-red-800"
              _ -> "bg-gray-100 text-gray-800"
            end
          }"}>
            <%= case @stream_status do %>
              <% :active -> %>
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600 mr-2"></div>
                Progressive Screening Active
              <% :running -> %>
                <div class="animate-pulse h-2 w-2 bg-yellow-600 rounded-full mr-2"></div>
                Screening in Progress
              <% :completed -> %>
                <div class="h-2 w-2 bg-green-600 rounded-full mr-2"></div>
                Screening Completed
              <% :error -> %>
                <div class="h-2 w-2 bg-red-600 rounded-full mr-2"></div>
                Screening Error
              <% _ -> %>
                Ready to Screen
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end