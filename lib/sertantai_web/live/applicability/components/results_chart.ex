defmodule SertantaiWeb.Applicability.Components.ResultsChart do
  @moduledoc """
  Interactive results visualization component for progressive screening results.
  Provides charts and visualizations of applicable laws and analysis data.
  """
  
  use SertantaiWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-gray-900">Screening Results Visualization</h3>
        <div class="flex space-x-2">
          <button 
            type="button"
            phx-click="change_view"
            phx-value-view="overview"
            phx-target={@myself}
            class={"px-3 py-1 text-sm rounded #{if @current_view == "overview", do: "bg-blue-500 text-white", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
          >
            Overview
          </button>
          <button 
            type="button"
            phx-click="change_view"
            phx-value-view="breakdown"
            phx-target={@myself}
            class={"px-3 py-1 text-sm rounded #{if @current_view == "breakdown", do: "bg-blue-500 text-white", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
          >
            Breakdown
          </button>
          <button 
            type="button"
            phx-click="change_view"
            phx-value-view="timeline"
            phx-target={@myself}
            class={"px-3 py-1 text-sm rounded #{if @current_view == "timeline", do: "bg-blue-500 text-white", else: "bg-gray-100 text-gray-700 hover:bg-gray-200"}"}
          >
            Timeline
          </button>
        </div>
      </div>

      <%= case @current_view do %>
        <% "overview" -> %>
          <%= render_overview(assigns) %>
        <% "breakdown" -> %>
          <%= render_breakdown(assigns) %>
        <% "timeline" -> %>
          <%= render_timeline(assigns) %>
        <% _ -> %>
          <%= render_overview(assigns) %>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    socket =
      socket
      |> assign(:current_view, "overview")

    {:ok, socket}
  end

  def handle_event("change_view", %{"view" => view}, socket) do
    socket = assign(socket, :current_view, view)
    {:noreply, socket}
  end

  defp render_overview(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Key Metrics Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div class="bg-blue-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-blue-600">
            <%= format_count(@results.applicable_law_count) %>
          </div>
          <div class="text-sm text-blue-600 font-medium">Total Laws</div>
          <div class="text-xs text-gray-600 mt-1">Making function only</div>
        </div>

        <div class="bg-green-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-green-600">
            <%= get_confidence_percentage(@results.confidence_level) %>%
          </div>
          <div class="text-sm text-green-600 font-medium">Confidence</div>
          <div class="text-xs text-gray-600 mt-1">
            <%= String.capitalize(@results.confidence_level) %> screening
          </div>
        </div>

        <div class="bg-purple-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-purple-600">
            <%= get_execution_time(@results) %>ms
          </div>
          <div class="text-sm text-purple-600 font-medium">Query Time</div>
          <div class="text-xs text-gray-600 mt-1">
            <%= get_complexity_level(@results) %> complexity
          </div>
        </div>

        <div class="bg-orange-50 rounded-lg p-4">
          <div class="text-2xl font-bold text-orange-600">
            <%= length(@results.sample_regulations || []) %>
          </div>
          <div class="text-sm text-orange-600 font-medium">Samples</div>
          <div class="text-xs text-gray-600 mt-1">Representative laws</div>
        </div>
      </div>

      <!-- Progress Bar Visualization -->
      <div class="bg-gray-50 rounded-lg p-4">
        <h4 class="text-sm font-medium text-gray-700 mb-3">Profile Completeness Impact</h4>
        <div class="space-y-3">
          <div class="flex items-center justify-between">
            <span class="text-sm text-gray-600">Phase 1 Fields</span>
            <div class="flex items-center space-x-2">
              <div class="w-32 bg-gray-200 rounded-full h-2">
                <div class="bg-blue-500 h-2 rounded-full" style={"width: #{get_phase1_completeness(@complexity_score)}%"}></div>
              </div>
              <span class="text-xs text-gray-500 w-12 text-right"><%= get_phase1_completeness(@complexity_score) %>%</span>
            </div>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm text-gray-600">Phase 2 Fields</span>
            <div class="flex items-center space-x-2">
              <div class="w-32 bg-gray-200 rounded-full h-2">
                <div class="bg-green-500 h-2 rounded-full" style={"width: #{get_phase2_completeness(@complexity_score)}%"}></div>
              </div>
              <span class="text-xs text-gray-500 w-12 text-right"><%= get_phase2_completeness(@complexity_score) %>%</span>
            </div>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm text-gray-600">Data Quality</span>
            <div class="flex items-center space-x-2">
              <div class="w-32 bg-gray-200 rounded-full h-2">
                <div class="bg-purple-500 h-2 rounded-full" style={"width: #{get_data_quality(@complexity_score)}%"}></div>
              </div>
              <span class="text-xs text-gray-500 w-12 text-right"><%= get_data_quality(@complexity_score) %>%</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Sample Regulations Quick View -->
      <%= if length(@results.sample_regulations || []) > 0 do %>
        <div class="bg-gray-50 rounded-lg p-4">
          <h4 class="text-sm font-medium text-gray-700 mb-3">Top Applicable Regulations</h4>
          <div class="space-y-2">
            <%= for {regulation, index} <- Enum.with_index(Enum.take(@results.sample_regulations, 3)) do %>
              <div class="flex items-start space-x-3 p-2 bg-white rounded border">
                <div class="flex-shrink-0 w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-xs font-medium">
                  <%= index + 1 %>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-sm font-medium text-gray-900 truncate">
                    <%= regulation.title_en || regulation.name %>
                  </div>
                  <%= if regulation.family do %>
                    <div class="text-xs text-gray-500 mt-1">
                      <%= regulation.family %> | Year: <%= regulation.year || "Unknown" %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_breakdown(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Family Distribution -->
      <div class="bg-gray-50 rounded-lg p-4">
        <h4 class="text-sm font-medium text-gray-700 mb-3">Legal Family Distribution</h4>
        <%= if @results.sample_regulations do %>
          <div class="space-y-2">
            <%= for {family, count} <- get_family_distribution(@results.sample_regulations) do %>
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-600"><%= family %></span>
                <div class="flex items-center space-x-2">
                  <div class="w-24 bg-gray-200 rounded-full h-2">
                    <div class="bg-blue-500 h-2 rounded-full" style={"width: #{get_percentage(count, length(@results.sample_regulations))}%"}></div>
                  </div>
                  <span class="text-xs text-gray-500 w-8 text-right"><%= count %></span>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-sm text-gray-500 text-center py-4">
            No regulation data available for breakdown
          </div>
        <% end %>
      </div>

      <!-- Performance Metrics -->
      <div class="bg-gray-50 rounded-lg p-4">
        <h4 class="text-sm font-medium text-gray-700 mb-3">Performance Analysis</h4>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <div class="text-lg font-semibold text-gray-900">Query Performance</div>
            <div class="text-sm text-gray-600 mt-1">
              Execution: <%= get_execution_time(@results) %>ms
            </div>
            <div class="text-sm text-gray-600">
              Complexity: <%= get_complexity_level(@results) %>
            </div>
            <div class="text-sm text-gray-600">
              Method: <%= get_screening_method(@results.screening_method) %>
            </div>
          </div>
          <div>
            <div class="text-lg font-semibold text-gray-900">Data Coverage</div>
            <div class="text-sm text-gray-600 mt-1">
              Total Score: <%= get_total_score(@complexity_score) %>
            </div>
            <div class="text-sm text-gray-600">
              Recommended: <%= get_recommended_level(@complexity_score) %>
            </div>
            <div class="text-sm text-gray-600">
              Quality: <%= get_data_quality(@complexity_score) %>%
            </div>
          </div>
        </div>
      </div>

      <!-- Optimization Suggestions -->
      <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
        <h4 class="text-sm font-medium text-gray-700 mb-3">Optimization Suggestions</h4>
        <ul class="space-y-2 text-sm text-gray-600">
          <%= get_optimization_suggestions(@complexity_score, @results) |> Enum.map(fn suggestion -> %>
            <li class="flex items-start space-x-2">
              <div class="w-1.5 h-1.5 bg-yellow-400 rounded-full mt-2 flex-shrink-0"></div>
              <span><%= suggestion %></span>
            </li>
          <% end) %>
        </ul>
      </div>
    </div>
    """
  end

  defp render_timeline(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Screening Timeline -->
      <div class="bg-gray-50 rounded-lg p-4">
        <h4 class="text-sm font-medium text-gray-700 mb-3">Screening Timeline</h4>
        
        <%= if @results.performance_metadata do %>
          <div class="relative">
            <!-- Timeline line -->
            <div class="absolute left-4 top-6 bottom-6 w-0.5 bg-gray-300"></div>
            
            <!-- Timeline events -->
            <div class="space-y-4">
              <div class="relative flex items-start space-x-4">
                <div class="flex-shrink-0 w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
                  <div class="w-2 h-2 bg-white rounded-full"></div>
                </div>
                <div class="flex-1">
                  <div class="text-sm font-medium text-gray-900">Query Initiated</div>
                  <div class="text-xs text-gray-500">Complexity: <%= @results.performance_metadata.complexity_level %></div>
                </div>
                <div class="text-xs text-gray-500">0ms</div>
              </div>

              <div class="relative flex items-start space-x-4">
                <div class="flex-shrink-0 w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
                  <div class="w-2 h-2 bg-white rounded-full"></div>
                </div>
                <div class="flex-1">
                  <div class="text-sm font-medium text-gray-900">Function Filtering Applied</div>
                  <div class="text-xs text-gray-500">Filtered to 'Making' function laws only</div>
                </div>
                <div class="text-xs text-gray-500">~20%</div>
              </div>

              <div class="relative flex items-start space-x-4">
                <div class="flex-shrink-0 w-8 h-8 bg-purple-500 rounded-full flex items-center justify-center">
                  <div class="w-2 h-2 bg-white rounded-full"></div>
                </div>
                <div class="flex-1">
                  <div class="text-sm font-medium text-gray-900">Profile Matching</div>
                  <div class="text-xs text-gray-500">Industry and geographic filtering</div>
                </div>
                <div class="text-xs text-gray-500">~70%</div>
              </div>

              <div class="relative flex items-start space-x-4">
                <div class="flex-shrink-0 w-8 h-8 bg-gray-400 rounded-full flex items-center justify-center">
                  <div class="w-2 h-2 bg-white rounded-full"></div>
                </div>
                <div class="flex-1">
                  <div class="text-sm font-medium text-gray-900">Results Retrieved</div>
                  <div class="text-xs text-gray-500"><%= format_count(@results.applicable_law_count) %> laws identified</div>
                </div>
                <div class="text-xs text-gray-500"><%= @results.performance_metadata.execution_time_ms %>ms</div>
              </div>
            </div>
          </div>
        <% else %>
          <div class="text-sm text-gray-500 text-center py-4">
            No performance data available for timeline visualization
          </div>
        <% end %>
      </div>

      <!-- Historical Comparison -->
      <div class="bg-gray-50 rounded-lg p-4">
        <h4 class="text-sm font-medium text-gray-700 mb-3">Performance Comparison</h4>
        <div class="text-sm text-gray-600">
          <div class="mb-2">
            <span class="font-medium">Current Query:</span> <%= get_execution_time(@results) %>ms
          </div>
          <div class="mb-2">
            <span class="font-medium">Expected Range:</span> 
            <%= get_expected_range(@results.performance_metadata.complexity_level) %>
          </div>
          <div class="mb-2">
            <span class="font-medium">Performance Status:</span>
            <span class={"font-medium #{get_performance_color(@results)}"}>
              <%= get_performance_status(@results) %>
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions for visualization data

  defp format_count(nil), do: "0"
  defp format_count(count) when is_integer(count), do: Integer.to_string(count)
  defp format_count(_), do: "—"

  defp get_confidence_percentage("basic"), do: 60
  defp get_confidence_percentage("enhanced"), do: 80
  defp get_confidence_percentage("high"), do: 95
  defp get_confidence_percentage(_), do: 50

  defp get_execution_time(%{performance_metadata: %{execution_time_ms: time}}), do: time
  defp get_execution_time(_), do: "—"

  defp get_complexity_level(%{performance_metadata: %{complexity_level: level}}), do: String.capitalize(to_string(level))
  defp get_complexity_level(_), do: "Unknown"

  defp get_phase1_completeness(%{phase1_completeness: score}), do: round(score * 100)
  defp get_phase1_completeness(_), do: 0

  defp get_phase2_completeness(%{phase2_completeness: score}), do: round(score * 100)
  defp get_phase2_completeness(_), do: 0

  defp get_data_quality(%{data_quality: score}), do: round(score * 100)
  defp get_data_quality(_), do: 0

  defp get_family_distribution(regulations) do
    regulations
    |> Enum.map(& &1.family)
    |> Enum.filter(& &1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_family, count} -> count end, :desc)
  end

  defp get_percentage(count, total) when total > 0, do: round(count / total * 100)
  defp get_percentage(_, _), do: 0

  defp get_screening_method("progressive_" <> method), do: String.capitalize(method)
  defp get_screening_method(method), do: method

  defp get_total_score(%{total_score: score}), do: :erlang.float_to_binary(score, decimals: 2)
  defp get_total_score(_), do: "0.00"

  defp get_recommended_level(%{recommended_complexity: level}), do: String.capitalize(to_string(level))
  defp get_recommended_level(_), do: "Unknown"

  defp get_optimization_suggestions(complexity_score, results) do
    suggestions = []
    
    # Profile completeness suggestions
    suggestions = if get_phase2_completeness(complexity_score) < 50 do
      ["Consider adding Phase 2 profile fields for enhanced accuracy" | suggestions]
    else
      suggestions
    end
    
    # Performance suggestions  
    suggestions = if get_execution_time(results) != "—" && get_execution_time(results) > 200 do
      ["Query performance could be optimized with additional indexing" | suggestions]
    else
      suggestions
    end
    
    # Data quality suggestions
    suggestions = if get_data_quality(complexity_score) < 70 do
      ["Improve data quality for more reliable screening results" | suggestions]
    else
      suggestions
    end
    
    # Default suggestion if none apply
    if length(suggestions) == 0 do
      ["Profile is well-optimized for current screening complexity"]
    else
      suggestions
    end
  end

  defp get_expected_range(:basic), do: "20-100ms"
  defp get_expected_range(:enhanced), do: "50-200ms"
  defp get_expected_range(:comprehensive), do: "100-500ms"
  defp get_expected_range(_), do: "Unknown"

  defp get_performance_status(results) do
    time = get_execution_time(results)
    if time != "—" && is_integer(time) do
      cond do
        time < 100 -> "Excellent"
        time < 300 -> "Good"
        time < 500 -> "Fair"
        true -> "Slow"
      end
    else
      "Unknown"
    end
  end

  defp get_performance_color(results) do
    case get_performance_status(results) do
      "Excellent" -> "text-green-600"
      "Good" -> "text-blue-600"
      "Fair" -> "text-yellow-600"
      "Slow" -> "text-red-600"
      _ -> "text-gray-600"
    end
  end
end